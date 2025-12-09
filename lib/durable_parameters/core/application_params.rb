# frozen_string_literal: true

require "active_support/descendants_tracker"

module DurableParameters
  module Core
    # Base class for declarative parameter permission definitions.
    #
    # ApplicationParams provides a DSL for defining which attributes are allowed
    # or denied for mass assignment. This enables a centralized, declarative
    # approach to parameter filtering that's more maintainable than inline
    # permit() calls.
    #
    # @example Basic usage
    #   class UserParams < DurableParameters::Core::ApplicationParams
    #     allow :name
    #     allow :email
    #     deny :is_admin
    #   end
    #
    # @example With action-specific permissions
    #   class PostParams < DurableParameters::Core::ApplicationParams
    #     allow :title
    #     allow :body
    #     allow :published, only: :create
    #     allow :view_count, except: :create
    #   end
    #
    # @example With metadata declaration
    #   class AccountParams < DurableParameters::Core::ApplicationParams
    #     allow :name
    #     metadata :ip_address, :role
    #   end
    #
    # @example With transformations
    #   class UserParams < DurableParameters::Core::ApplicationParams
    #     allow :email
    #     allow :role
    #     metadata :current_user
    #
    #     transform :email do |value, metadata|
    #       value&.downcase&.strip
    #     end
    #
    #     transform :role do |value, metadata|
    #       metadata[:current_user]&.admin? ? value : 'user'
    #     end
    #   end
    class ApplicationParams
      extend ActiveSupport::DescendantsTracker

      class << self
        # Returns the list of allowed attributes for this class only (not including parents).
        #
        # @return [Array<Symbol>] array of allowed attribute names
        def own_allowed_attributes
          @allowed_attributes ||= []
        end

        # Returns the list of allowed attributes, including those from parent classes.
        #
        # @return [Array<Symbol>] array of allowed attribute names
        def allowed_attributes
          if superclass.respond_to?(:allowed_attributes)
            (superclass.allowed_attributes + own_allowed_attributes).uniq
          else
            own_allowed_attributes.dup
          end
        end

        # Returns the list of denied attributes for this class only (not including parents).
        #
        # @return [Array<Symbol>] array of denied attribute names
        def own_denied_attributes
          @denied_attributes ||= []
        end

        # Returns the list of denied attributes, including those from parent classes.
        #
        # @return [Array<Symbol>] array of denied attribute names
        def denied_attributes
          if superclass.respond_to?(:denied_attributes)
            (superclass.denied_attributes + own_denied_attributes).uniq
          else
            own_denied_attributes.dup
          end
        end

        # Returns the flags hash for this class only (not including parents).
        #
        # @return [Hash<Symbol, Object>] hash of flag names to values
        def own_flags
          @flags ||= {}
        end

        # Returns the flags hash, including those from parent classes.
        #
        # @return [Hash<Symbol, Object>] hash of flag names to values
        def flags
          if superclass.respond_to?(:flags)
            superclass.flags.merge(own_flags)
          else
            own_flags.dup
          end
        end

        # Returns the set of allowed metadata keys for this class only (not including parents).
        #
        # @return [Set<Symbol>] set of allowed metadata key names
        # @note :current_user is always implicitly allowed
        def own_allowed_metadata
          @allowed_metadata ||= Set.new
        end

        # Returns the set of allowed metadata keys, including those from parent classes.
        #
        # @return [Set<Symbol>] set of allowed metadata key names
        # @note :current_user is always implicitly allowed
        def allowed_metadata
          if superclass.respond_to?(:allowed_metadata)
            superclass.allowed_metadata + own_allowed_metadata
          else
            own_allowed_metadata.dup
          end
        end

        # Returns the hash of transformations for this class only (not including parents).
        #
        # @return [Hash<Symbol, Proc>] hash of attribute names to transformation procs
        def own_transformations
          @transformations ||= {}
        end

        # Returns the hash of transformations, including those from parent classes.
        # Child class transformations override parent transformations for the same attribute.
        #
        # @return [Hash<Symbol, Proc>] hash of attribute names to transformation procs
        def transformations
          if superclass.respond_to?(:transformations)
            superclass.transformations.merge(own_transformations)
          else
            own_transformations.dup
          end
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
          return unless attribute.respond_to?(:to_sym)
          attribute = attribute.to_sym
          own_allowed_attributes << attribute unless own_allowed_attributes.include?(attribute)

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

          # Clear cache since permitted attributes may have changed
          # Must be done after modifying attributes/options
          @permitted_cache = {}
        end

        # DSL method to deny an attribute
        # @param attribute [Symbol, String] the attribute name to deny
        def deny(attribute)
          return unless attribute.respond_to?(:to_sym)
          attribute = attribute.to_sym
          own_denied_attributes << attribute unless own_denied_attributes.include?(attribute)
          # Clear cache since permitted attributes may have changed
          @permitted_cache = {}
        end

        # DSL method to set a flag
        # @param name [Symbol, String] the flag name
        # @param value [Boolean, Object] the flag value
        def flag(name, value = true)
          return unless name.respond_to?(:to_sym)
          own_flags[name.to_sym] = value
        end

        # DSL method to declare allowed metadata keys
        # @param key [Symbol, String] the metadata key to allow
        # Note: :current_user is always allowed and doesn't need to be declared
        def metadata(*keys)
          keys.each do |key|
            own_allowed_metadata << key.to_sym if key.respond_to?(:to_sym)
          end
        end

        # DSL method to define a transformation for an attribute
        # @param attribute [Symbol, String] the attribute name to transform
        # @param block [Proc] the transformation block
        #   The block receives two parameters:
        #   - value: the current value of the attribute
        #   - metadata: hash of metadata (current_user, action, etc.)
        #   The block should return the transformed value
        # @example Transform email to lowercase
        #   transform :email do |value, metadata|
        #     value&.downcase&.strip
        #   end
        # @example Conditional transformation based on metadata
        #   transform :role do |value, metadata|
        #     metadata[:current_user]&.admin? ? value : 'user'
        #   end
        def transform(attribute, &block)
          raise ArgumentError, "Block required for transform" unless block_given?
          return unless attribute.respond_to?(:to_sym)
          own_transformations[attribute.to_sym] = block
        end

        # Check if an attribute is allowed.
        #
        # An attribute is allowed if it's in the allowed list and not in the denied list.
        # Uses memoization for better performance on repeated checks.
        #
        # @param attribute [Symbol, String] the attribute name
        # @return [Boolean] true if allowed, false otherwise
        def allowed?(attribute)
          return false unless attribute.respond_to?(:to_sym)
          attribute = attribute.to_sym
          return false if denied_attributes.include?(attribute)

          allowed_attributes.include?(attribute)
        end

        # Check if an attribute is denied.
        #
        # @param attribute [Symbol, String] the attribute name
        # @return [Boolean] true if denied, false otherwise
        def denied?(attribute)
          return false unless attribute.respond_to?(:to_sym)
          denied_attributes.include?(attribute.to_sym)
        end

        # Check if a flag is set
        # @param name [Symbol, String] the flag name
        # @return [Boolean, Object] the flag value
        def flag?(name)
          return nil unless name.respond_to?(:to_sym)
          flags[name.to_sym]
        end

        # Check if a metadata key is allowed
        # @param key [Symbol, String] the metadata key
        # @return [Boolean] true if allowed, false otherwise
        # Note: :current_user is always allowed
        def allowed_metadata_key?(key)
          return false unless key.respond_to?(:to_sym)
          key = key.to_sym
          key == :current_user || allowed_metadata.include?(key)
        end

        # @deprecated Use {#allowed_metadata_key?} instead
        alias_method :metadata_allowed?, :allowed_metadata_key?

        # Get options for an attribute, checking parent classes as well
        # @param attribute [Symbol, String] the attribute name
        # @return [Hash] the options hash
        def attribute_options(attribute)
          @attribute_options ||= {}
          return {} unless attribute.respond_to?(:to_sym)
          attr_sym = attribute.to_sym

          # Start with parent options, then merge with own options (own options take precedence)
          if superclass.respond_to?(:attribute_options)
            superclass.attribute_options(attr_sym).merge(@attribute_options[attr_sym] || {})
          else
            @attribute_options[attr_sym] || {}
          end
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

          # Filter by action-specific flags
          # When action is nil (passed explicitly) or not provided, include all attributes
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
          # else: when no action provided, include everything (don't filter)

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

        # Apply transformations to a hash of parameters
        #
        # @param params [Hash, Parameters] the parameters to transform
        # @param metadata [Hash] metadata hash containing current_user, action, etc.
        # @return [Hash] the transformed parameters
        def apply_transformations(params, metadata = {})
          return params if transformations.empty?

          # Handle non-hash params
          return params if params.nil? || !(params.is_a?(Hash) || params.respond_to?(:to_unsafe_h) || (params.respond_to?(:to_h) && !params.is_a?(Array)))

          # Convert to regular hash - handle both plain hashes and Parameters objects
          hash = if params.respond_to?(:to_unsafe_h)
            # Rails ActionController::Parameters
            params.to_unsafe_h
          elsif params.respond_to?(:to_h)
            # Core Parameters or plain Hash
            params.to_h
          else
            params
          end

          # Make a dup so we don't modify the original
          hash = hash.dup

          # Apply each transformation
          transformations.each do |attribute, transformer|
            key_str = attribute.to_s
            key_sym = attribute.to_sym

            # Check for string key first
            if hash.key?(key_str)
              original_value = hash[key_str]
              duped_value = begin
                Marshal.load(Marshal.dump(original_value))
              rescue TypeError
                original_value.dup rescue original_value
              end
              hash[key_str] = transformer.call(duped_value, metadata)
            end

            # Check for symbol key (even if string key exists, transform both if present)
            if hash.key?(key_sym)
              original_value = hash[key_sym]
              duped_value = begin
                Marshal.load(Marshal.dump(original_value))
              rescue TypeError
                original_value.dup rescue original_value
              end
              hash[key_sym] = transformer.call(duped_value, metadata)
            end
          end

          hash
        end

        # Inherit attributes from parent class.
        #
        # When a subclass is created, it inherits all configuration from the parent
        # including allowed/denied attributes, flags, metadata, transformations, and options.
        # This enables building specialized params classes on top of base ones.
        #
        # @param subclass [Class] the inheriting subclass
        # @return [void]
        def inherited(subclass)
          super
          # Initialize subclass with empty configuration
          # The allowed_attributes, denied_attributes, etc. methods will
          # automatically inherit from parent through the class hierarchy
          subclass.instance_variable_set(:@allowed_attributes, [])
          subclass.instance_variable_set(:@denied_attributes, [])
          subclass.instance_variable_set(:@flags, {})
          subclass.instance_variable_set(:@allowed_metadata, Set.new)
          subclass.instance_variable_set(:@transformations, {})
          subclass.instance_variable_set(:@attribute_options, {})
          # Don't copy the cache - let subclass build its own
        end

        # Reset the cache for this class (primarily for testing).
        #
        # Clears only the cached permitted attributes to ensure test isolation
        # while preserving the class configuration (allowed/denied attributes, etc.).
        #
        # @return [void]
        def reset_cache!
          @permitted_cache = {}
        end
      end
    end
  end
end
