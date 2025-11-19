# frozen_string_literal: true

module ActionController
  # Base class for declarative parameter permission definitions.
  #
  # ApplicationParams provides a DSL for defining which attributes are allowed
  # or denied for mass assignment in controllers. This enables a centralized,
  # declarative approach to parameter filtering that's more maintainable than
  # inline permit() calls.
  #
  # @example Basic usage
  #   class UserParams < ApplicationParams
  #     allow :name
  #     allow :email
  #     deny :is_admin
  #   end
  #
  # @example With action-specific permissions
  #   class PostParams < ApplicationParams
  #     allow :title
  #     allow :body
  #     allow :published, only: :create
  #     allow :view_count, except: :create
  #   end
  #
  # @example With metadata declaration
  #   class AccountParams < ApplicationParams
  #     allow :name
  #     metadata :ip_address, :role
  #   end
  class ApplicationParams
    class << self
      # Returns the list of allowed attributes.
      #
      # @return [Array<Symbol>] array of allowed attribute names
      def allowed_attributes
        @allowed_attributes ||= []
      end

      # Returns the list of denied attributes.
      #
      # @return [Array<Symbol>] array of denied attribute names
      def denied_attributes
        @denied_attributes ||= []
      end

      # Returns the flags hash.
      #
      # @return [Hash<Symbol, Object>] hash of flag names to values
      def flags
        @flags ||= {}
      end

      # Returns the set of allowed metadata keys.
      #
      # @return [Set<Symbol>] set of allowed metadata key names
      # @note :current_user is always implicitly allowed
      def allowed_metadata
        @allowed_metadata ||= Set.new
      end

      # DSL method to allow an attribute
      # @param attribute [Symbol, String, Hash] the attribute name to allow, or a hash for arrays
      # @param options [Hash] additional options
      #   - :only - only allow this attribute for these actions
      #   - :except - allow this attribute except for these actions
      #   - :array - if true, permit an array of scalar values
      # Examples:
      #   allow :name                           # permits scalar name
      #   allow :tags, array: true              # permits array of scalars
      #   allow :tags, only: :create            # only for create action
      def allow(attribute, options = {})
        attribute = attribute.to_sym
        allowed_attributes << attribute unless allowed_attributes.include?(attribute)

        # Store any additional options for this attribute
        if options.any?
          @attribute_options ||= {}
          # Normalize :only and :except to arrays for consistency
          normalized_options = options.dup
          [:only, :except].each do |key|
            if normalized_options[key] && !normalized_options[key].is_a?(Array)
              normalized_options[key] = [normalized_options[key]]
            end
          end
          @attribute_options[attribute] = normalized_options
        end
      end

      # DSL method to deny an attribute
      # @param attribute [Symbol, String] the attribute name to deny
      def deny(attribute)
        attribute = attribute.to_sym
        denied_attributes << attribute unless denied_attributes.include?(attribute)
      end

      # DSL method to set a flag
      # @param name [Symbol, String] the flag name
      # @param value [Boolean, Object] the flag value
      def flag(name, value = true)
        flags[name.to_sym] = value
      end

      # DSL method to declare allowed metadata keys
      # @param key [Symbol, String] the metadata key to allow
      # Note: :current_user is always allowed and doesn't need to be declared
      def metadata(*keys)
        keys.each do |key|
          allowed_metadata << key.to_sym
        end
      end

      # Check if an attribute is allowed.
      #
      # An attribute is allowed if it's in the allowed list and not in the denied list.
      # Uses memoization for better performance on repeated checks.
      #
      # @param attribute [Symbol, String] the attribute name
      # @return [Boolean] true if allowed, false otherwise
      def allowed?(attribute)
        attribute = attribute.to_sym
        return false if denied_attributes.include?(attribute)

        allowed_attributes.include?(attribute)
      end

      # Check if an attribute is denied.
      #
      # @param attribute [Symbol, String] the attribute name
      # @return [Boolean] true if denied, false otherwise
      def denied?(attribute)
        denied_attributes.include?(attribute.to_sym)
      end

      # Check if a flag is set
      # @param name [Symbol, String] the flag name
      # @return [Boolean, Object] the flag value
      def flag?(name)
        flags[name.to_sym]
      end

      # Check if a metadata key is allowed
      # @param key [Symbol, String] the metadata key
      # @return [Boolean] true if allowed, false otherwise
      # Note: :current_user is always allowed
      def metadata_allowed?(key)
        key = key.to_sym
        key == :current_user || allowed_metadata.include?(key)
      end

      # Get options for an attribute
      # @param attribute [Symbol, String] the attribute name
      # @return [Hash] the options hash
      def attribute_options(attribute)
        @attribute_options ||= {}
        @attribute_options[attribute.to_sym] || {}
      end

      # Generate a permit array suitable for strong_parameters.
      #
      # Returns an array of permitted attributes, optionally filtered by action.
      # Results are cached per action for better performance.
      #
      # @param action [Symbol, String, nil] optional action name to filter by
      # @return [Array<Symbol, Hash>] array of permitted attributes
      #   Returns symbols for scalar attributes, and {attr: []} for array attributes
      # @example
      #   permitted_attributes # => [:name, :email]
      #   permitted_attributes(action: :create) # => [:name, :email, :published]
      def permitted_attributes(action: nil)
        # Use cache for performance on repeated calls
        @permitted_cache ||= {}
        cache_key = action || :__no_action__

        return @permitted_cache[cache_key] if @permitted_cache.key?(cache_key)

        attrs = allowed_attributes.dup

        # Remove denied attributes
        attrs.reject! { |attr| denied_attributes.include?(attr) }

        # Filter by action-specific flags if provided
        if action
          action = action.to_sym
          attrs.select! do |attr|
            opts = attribute_options(attr)
            if opts[:only]
              Array(opts[:only]).include?(action)
            elsif opts[:except]
              !Array(opts[:except]).include?(action)
            else
              true
            end
          end
        end

        # Convert to proper permit format
        # For array attributes, return {attr: []}, otherwise just the symbol
        result = attrs.map do |attr|
          opts = attribute_options(attr)
          if opts[:array]
            {attr => []}
          else
            attr
          end
        end.freeze

        @permitted_cache[cache_key] = result
      end

      # Inherit attributes from parent class.
      #
      # When a subclass is created, it inherits all configuration from the parent
      # including allowed/denied attributes, flags, metadata, and options. This
      # enables building specialized params classes on top of base ones.
      #
      # @param subclass [Class] the inheriting subclass
      # @return [void]
      def inherited(subclass)
        super
        # Copy parent's configuration to subclass
        subclass.instance_variable_set(:@allowed_attributes, allowed_attributes.dup)
        subclass.instance_variable_set(:@denied_attributes, denied_attributes.dup)
        subclass.instance_variable_set(:@flags, flags.dup)
        subclass.instance_variable_set(:@allowed_metadata, allowed_metadata.dup)
        if instance_variable_defined?(:@attribute_options)
          subclass.instance_variable_set(:@attribute_options, @attribute_options.dup)
        end
        # Don't copy the cache - let subclass build its own
      end
    end
  end
end
