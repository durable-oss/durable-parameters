# frozen_string_literal: true

require "date"
require "bigdecimal"
require "stringio"

module StrongParameters
  module Core
    # Exception raised when a required parameter is missing or empty.
    #
    # This exception provides helpful context about what went wrong and suggests
    # how to fix it, making debugging easier for developers.
    #
    # @example Basic usage
    #   params = Parameters.new({})
    #   params.require(:user)
    #   # => ParameterMissing: param is missing or the value is empty: user
    #   #
    #   #    Expected to find parameter 'user' in the request, but it was missing.
    #   #
    #   #    Make sure your request includes this parameter. For example:
    #   #      POST /users with { "user": { ... } }
    class ParameterMissing < IndexError
      # @return [Symbol, String] the name of the missing parameter
      attr_reader :param

      # Initialize a new ParameterMissing exception
      #
      # @param param [Symbol, String] the name of the missing parameter
      # @param context [Hash] optional context for better error messages
      # @option context [Array<String>] :available_keys keys that were present
      def initialize(param, context = {})
        @param = param
        message = build_message(param, context)
        super(message)
      end

      private

      def build_message(param, context)
        msg = "param is missing or the value is empty: #{param}"

        if context[:available_keys]&.any?
          msg += "\n\n"
          msg += "Available keys: #{context[:available_keys].join(", ")}"
          msg += "\n"

          # Suggest similar keys if available
          similar = find_similar_keys(param.to_s, context[:available_keys])
          if similar.any?
            msg += "\nDid you mean? #{similar.join(", ")}"
          end
        end

        msg
      end

      def find_similar_keys(param, available_keys)
        return [] unless available_keys

        param_str = param.to_s.downcase
        available_keys.select do |key|
          key_str = key.to_s.downcase
          # Simple similarity check: starts with same letter or contains param
          key_str[0] == param_str[0] || key_str.include?(param_str) || param_str.include?(key_str)
        end.take(3)
      end
    end

    # Exception raised when unpermitted parameters are detected and configured to raise.
    #
    # @example
    #   params.permit(:name)
    #   # With params containing :admin => true
    #   # => StrongParameters::Core::UnpermittedParameters: found unpermitted parameters: admin
    class UnpermittedParameters < IndexError
      # @return [Array<String>] the names of the unpermitted parameters
      attr_reader :params

      # Initialize a new UnpermittedParameters exception
      #
      # @param params [Array<String>] the names of the unpermitted parameters
      def initialize(params)
        @params = params
        super("found unpermitted parameters: #{params.join(", ")}")
      end
    end

    # Core Parameters implementation - framework-agnostic strong parameters.
    #
    # This class provides a whitelist-based approach to mass assignment protection,
    # requiring explicit permission for parameters before they can be used.
    #
    # @example Basic usage
    #   params = StrongParameters::Core::Parameters.new(user: { name: 'John', admin: true })
    #   params.require(:user).permit(:name)
    #   # => <StrongParameters::Core::Parameters {"name"=>"John"} permitted: true>
    class Parameters < Hash
      # @return [Boolean] whether this Parameters object is permitted
      attr_accessor :permitted
      alias_method :permitted?, :permitted

      # @return [Symbol, String, nil] the key used in the last require() call
      attr_accessor :required_key

      class << self
        # @return [Symbol, nil] action to take on unpermitted parameters (:log, :raise, or nil/false)
        attr_accessor :action_on_unpermitted_parameters

        # @return [Proc, nil] notification handler for unpermitted parameters
        attr_accessor :unpermitted_notification_handler
      end

      # Parameters that are never considered unpermitted.
      # These are added by frameworks and are of no concern for security.
      NEVER_UNPERMITTED_PARAMS = %w[controller action].freeze

      # Initialize a new Parameters object.
      #
      # @param attributes [Hash, nil] the initial attributes
      def initialize(attributes = nil)
        super()
        @permitted = false
        @required_key = nil
        update(deep_normalize_keys(attributes)) if attributes
      end

      # Mark this Parameters object and all nested Parameters as permitted.
      #
      # Use with extreme caution as this allows all current and future attributes
      # to be mass-assigned. Should only be used when you fully trust the source
      # of the parameters.
      #
      # @return [Parameters] self
      # @example
      #   params.require(:log_entry).permit!
      def permit!
        each_pair do |key, value|
          value = convert_hashes_to_parameters(key, value)
          wrap_array(value).each do |item|
            item.permit! if item.respond_to?(:permit!)
          end
        end

        @permitted = true
        self
      end

      # Ensure that a parameter is present and not empty.
      #
      # If the parameter is missing or empty, raises ParameterMissing exception
      # with helpful context about available keys and suggestions.
      # If the parameter is present and is a Parameters object, tracks the key
      # for later use by transform_params.
      #
      # @param key [Symbol, String] the parameter key to require
      # @return [Object] the parameter value
      # @raise [ParameterMissing] if the parameter is missing or empty
      #
      # @example Basic usage
      #   params.require(:user)  # => returns params[:user] or raises ParameterMissing
      #
      # @example Chaining with permit
      #   params.require(:user).permit(:name, :email)
      #
      # @example Error with helpful context
      #   params = Parameters.new(usr: {name: 'John'})
      #   params.require(:user)
      #   # => ParameterMissing: param is missing or the value is empty: user
      #   #
      #   #    Available keys: usr
      #   #    Did you mean? usr
      def require(key)
        key = normalize_key(key)
        value = self[key]
        value = nil if value.respond_to?(:empty?) && value.empty?

        if value.nil?
          # Provide helpful context in error message
          context = {available_keys: keys}
          raise ParameterMissing.new(key, context)
        end

        # Track the required key so transform_params can infer the params class
        if value.is_a?(Parameters) && value.required_key.nil?
          value.required_key = @required_key || key.to_sym
        end
        value
      end

      alias_method :required, :require

      # Create a new Parameters object with only the specified keys permitted.
      #
      # Filters can be symbols/strings for scalar values, or hashes for nested
      # parameters. Only explicitly permitted parameters will be included in
      # the returned object.
      #
      # @param filters [Array<Symbol, String, Hash>] the keys to permit
      # @return [Parameters] a new Parameters object containing only permitted keys
      # @example Permit scalar values
      #   params.permit(:name, :age)
      # @example Permit nested parameters
      #   params.permit(:name, emails: [], friends: [:name, { family: [:name] }])
      def permit(*filters)
        params = self.class.new

        filters.flatten.each do |filter|
          case filter
          when Symbol, String
            permitted_scalar_filter(params, filter)
          when Hash
            hash_filter(params, filter)
          end
        end

        unpermitted_parameters!(params) if self.class.action_on_unpermitted_parameters

        params.permit!
      end

      # Transform and permit parameters using a declarative params class.
      #
      # This method provides a declarative approach to parameter filtering using
      # params classes. It automatically looks up the appropriate params class
      # based on the required_key if not explicitly provided.
      #
      # Transformations defined in the params class are applied before filtering.
      # This allows you to normalize, validate, or modify parameter values based
      # on metadata like the current user or action.
      #
      # @param params_class [Class, Symbol, nil] optional params class or :__infer__ (default)
      #   - Class: Use this specific params class (e.g., UserParams)
      #   - :__infer__: Infer from required_key (e.g., :user -> UserParams)
      #   - nil: Skip lookup and return empty permitted params
      # @param options [Hash] metadata and configuration options
      # @option options [Symbol, String] :action Action name for action-specific filtering
      # @option options [Array<Symbol>] :additional_attrs Additional attributes to permit
      # @option options [Object] :current_user Current user (always allowed, no declaration needed)
      # @return [Parameters] permitted parameters with only allowed attributes
      # @raise [ArgumentError] if undeclared metadata keys are passed
      #
      # @example Basic usage with inference
      #   params.require(:user).transform_params
      #   # Looks up UserParams automatically
      #
      # @example Explicit params class
      #   params.require(:user).transform_params(AdminUserParams)
      #
      # @example With action-specific filtering
      #   params.require(:post).transform_params(action: :create)
      #
      # @example With metadata for transformations
      #   params.require(:user).transform_params(current_user: current_user)
      #   # Transformations can access current_user
      #
      # @example With additional attributes
      #   params.require(:user).transform_params(additional_attrs: [:temp_token])
      def transform_params(params_class = :__infer__, **options)
        # Extract known options (these don't need to be declared as metadata)
        action = options[:action]
        additional_attrs = options[:additional_attrs] || []

        # Infer params class from required_key if not explicitly provided
        if params_class == :__infer__
          if @required_key
            params_class = ParamsRegistry.lookup(@required_key)
          else
            # If no required_key and no explicit params_class, return empty permitted params
            return self.class.new.permit!
          end
        end

        # Handle case where params_class is nil (explicitly passed or not registered)
        if params_class.nil?
          return self.class.new.permit!
        end

        # Validate metadata keys (excluding known options)
        metadata_keys = options.keys - [:action, :additional_attrs]
        validate_metadata_keys!(params_class, metadata_keys)

        # Apply transformations first (before filtering)
        # Pass all options as metadata to the transformations
        transformed_hash = params_class.apply_transformations(self, options)

        # Create a new Parameters object from the transformed hash
        transformed_params = self.class.new(transformed_hash)

        # Get permitted attributes and apply them
        permitted_attrs = params_class.permitted_attributes(action: action) || []
        permitted_attrs += additional_attrs
        transformed_params.permit(*permitted_attrs)
      end

      # Legacy alias for backwards compatibility.
      #
      # @deprecated Use {#transform_params} instead
      # @param model_name [Symbol, String] the model name to look up
      # @param action [Symbol, String, nil] optional action name
      # @param additional_attrs [Array<Symbol>] additional attributes to permit
      # @return [Parameters] permitted parameters
      def permit_by_model(model_name, action: nil, additional_attrs: [])
        params_class = ParamsRegistry.lookup(model_name)
        transform_params(params_class, action: action, additional_attrs: additional_attrs)
      end

      # Access a parameter value by key, converting hashes to Parameters objects.
      #
      # @param key [Symbol, String] the parameter key
      # @return [Object] the parameter value
      def [](key)
        convert_hashes_to_parameters(normalize_key(key), super(normalize_key(key)))
      end

      # Set a parameter value by key.
      #
      # @param key [Symbol, String] the parameter key
      # @param value [Object] the parameter value
      def []=(key, value)
        super(normalize_key(key), value)
      end

      # Fetch a parameter value by key, raising ParameterMissing if not found.
      #
      # @param key [Symbol, String] the parameter key
      # @param args additional arguments passed to Hash#fetch
      # @return [Object] the parameter value
      # @raise [ParameterMissing] if the key is not found
      def fetch(key, *args)
        key = normalize_key(key)
        convert_hashes_to_parameters(key, super, false)
      rescue KeyError
        raise ParameterMissing.new(key)
      rescue IndexError
        raise ParameterMissing.new(key)
      end

      # Check if a key exists in the parameters.
      #
      # @param key [Symbol, String] the parameter key
      # @return [Boolean] true if the key exists
      def has_key?(key)
        super(normalize_key(key))
      end

      alias_method :key?, :has_key?
      alias_method :include?, :has_key?

      # Delete a key from the parameters.
      #
      # @param key [Symbol, String] the parameter key
      # @return [Object] the deleted value
      def delete(key)
        super(normalize_key(key))
      end

      # Create a new Parameters object containing only the specified keys.
      #
      # @param keys [Array<Symbol, String>] the keys to include
      # @return [Parameters] a new Parameters object with only the specified keys
      # @example
      #   params.slice(:name, :email)
      def slice(*keys)
        normalized_keys = keys.map { |k| normalize_key(k) }
        sliced = slice(*normalized_keys)

        self.class.new(sliced).tap do |new_instance|
          new_instance.instance_variable_set(:@permitted, @permitted)
          new_instance.instance_variable_set(:@required_key, @required_key)
        end
      end

      # Create a new Parameters object excluding the specified keys.
      #
      # @param keys [Array<Symbol, String>] the keys to exclude
      # @return [Parameters] a new Parameters object without the specified keys
      # @example
      #   params.except(:password, :password_confirmation)
      def except(*keys)
        # Return a new Parameters instance excluding the specified keys
        excepted = dup
        keys.each { |key| excepted.delete(key) }
        excepted
      end

      # Create a duplicate of this Parameters object.
      #
      # @return [Parameters] a new Parameters object with the same data and state
      def dup
        self.class.new(self).tap do |duplicate|
          duplicate.instance_variable_set(:@permitted, @permitted)
          duplicate.instance_variable_set(:@required_key, @required_key)
        end
      end

      # Convert to a regular Hash.
      #
      # @return [Hash] a regular hash with string keys
      def to_h
        each_with_object({}) do |(key, value), hash|
          hash[key.to_s] = value.is_a?(Parameters) ? value.to_h : value
        end
      end

      # Convert to an unsafe hash (without permission checking).
      #
      # @return [Hash] a regular hash
      def to_unsafe_h
        to_h
      end

      alias_method :to_hash, :to_h

      protected

      def convert_value(value)
        if value.is_a?(Hash) && !value.is_a?(Parameters)
          self.class.new(value)
        elsif value.is_a?(Array)
          value.map { |e| convert_value(e) }
        else
          value
        end
      end

      private

      def normalize_key(key)
        key.to_s
      end

      def deep_normalize_keys(hash)
        return hash unless hash.is_a?(Hash)

        hash.each_with_object({}) do |(key, value), result|
          normalized_key = normalize_key(key)
          result[normalized_key] = if value.is_a?(Hash)
            deep_normalize_keys(value)
          elsif value.is_a?(Array)
            value.map { |item| item.is_a?(Hash) ? deep_normalize_keys(item) : item }
          else
            value
          end
        end
      end

      def convert_hashes_to_parameters(key, value, assign_if_converted = true)
        converted = convert_value_to_parameters(value)
        self[key] = converted if assign_if_converted && !converted.equal?(value)
        converted
      end

      def convert_value_to_parameters(value)
        if value.is_a?(Array)
          value.map { |item| convert_value_to_parameters(item) }
        elsif value.is_a?(Parameters) || !value.is_a?(Hash)
          value
        else
          self.class.new(value)
        end
      end

      def wrap_array(value)
        value.is_a?(Array) ? value : [value]
      end

      #
      # --- Filtering ----------------------------------------------------------
      #

      # Whitelist of permitted scalar types for parameter filtering.
      #
      # These types are considered safe for mass assignment and include types
      # commonly used in XML and JSON requests. String is first to optimize
      # the common case through short-circuit evaluation.
      #
      # **Permitted Types:**
      # - String, Symbol - text values
      # - NilClass - null values
      # - Numeric (Integer, Float, BigDecimal, etc.) - numeric values
      # - TrueClass, FalseClass - boolean values
      # - Date, Time, DateTime - temporal values
      # - StringIO, IO - file-like objects
      #
      # @note DateTime inherits from Date, so it's implicitly included.
      # @note If you modify this list, please update the README documentation.
      PERMITTED_SCALAR_TYPES = [
        String,
        Symbol,
        NilClass,
        Numeric,
        TrueClass,
        FalseClass,
        Date,
        Time,
        # DateTimes are Dates, we document the type but avoid the redundant check.
        StringIO,
        IO
      ].freeze

      # Check if a value is a permitted scalar type.
      #
      # @param value [Object] the value to check
      # @return [Boolean] true if value is a permitted scalar type
      def permitted_scalar?(value)
        PERMITTED_SCALAR_TYPES.any? { |type| value.is_a?(type) }
      end

      # Check if a value is an array containing only permitted scalars.
      #
      # @param value [Object] the value to check
      # @return [Boolean, nil] true if array of permitted scalars, nil otherwise
      def array_of_permitted_scalars?(value)
        return unless value.is_a?(Array)

        value.all? { |element| permitted_scalar?(element) }
      end

      def permitted_scalar_filter(params, key)
        key = normalize_key(key)
        if has_key?(key) && permitted_scalar?(self[key])
          params[key] = self[key]
        end

        keys.grep(/\A#{Regexp.escape(key)}\(\d+[if]?\)\z/).each do |matched_key|
          if permitted_scalar?(self[matched_key])
            params[matched_key] = self[matched_key]
          end
        end
      end

      def array_of_permitted_scalars_filter(params, key, hash = self)
        key = normalize_key(key)
        if hash.has_key?(key) && array_of_permitted_scalars?(hash[key])
          params[key] = hash[key]
        end
      end

      def hash_filter(params, filter)
        # Normalize filter keys
        normalized_filter = filter.each_with_object({}) do |(k, v), result|
          result[normalize_key(k)] = v
        end

        # Slicing filters out non-declared keys.
        slice(*normalized_filter.keys).each do |key, value|
          next unless value

          if normalized_filter[key] == []
            # Declaration {:comment_ids => []}.
            array_of_permitted_scalars_filter(params, key)
          else
            # Declaration {:user => :name} or {:user => [:name, :age, {:address => ...}]}.
            params[key] = each_element(value) do |element, index|
              if element.is_a?(Hash)
                element = self.class.new(element) unless element.respond_to?(:permit)
                element.permit(*wrap_array(normalized_filter[key]))
              elsif normalized_filter[key].is_a?(Hash) && normalized_filter[key][index] == []
                array_of_permitted_scalars_filter(params, index, value)
              end
            end
          end
        end
      end

      def each_element(value)
        if value.is_a?(Array)
          value.map { |el| yield el }.compact
          # fields_for on an array of records uses numeric hash keys.
        elsif fields_for_style?(value)
          hash = value.class.new
          value.each { |k, v| hash[k] = yield(v, k) }
          hash
        else
          yield value
        end
      end

      def fields_for_style?(object)
        object.is_a?(Hash) && !object.empty? && object.all? { |k, v| k =~ /\A-?\d+\z/ && v.is_a?(Hash) }
      end

      def unpermitted_parameters!(params)
        return unless self.class.action_on_unpermitted_parameters

        unpermitted_keys = unpermitted_keys(params)

        if unpermitted_keys.any?
          case self.class.action_on_unpermitted_parameters
          when :log
            notify_unpermitted(unpermitted_keys)
          when :raise
            raise UnpermittedParameters.new(unpermitted_keys)
          end
        end
      end

      def unpermitted_keys(params)
        keys - params.keys - NEVER_UNPERMITTED_PARAMS
      end

      def notify_unpermitted(keys)
        if self.class.unpermitted_notification_handler
          begin
            self.class.unpermitted_notification_handler.call(keys)
          rescue
            # Log the error but don't prevent parameter processing
            # In a real application, you might want to log this
          end
        end
      end

      # Validate that all provided metadata keys are allowed by the params class.
      #
      # @param params_class [Class] the params class to validate against
      # @param metadata_keys [Array<Symbol>] the metadata keys to validate
      # @raise [ArgumentError] if any metadata keys are not declared
      # @return [void]
      def validate_metadata_keys!(params_class, metadata_keys)
        return if metadata_keys.empty?

        disallowed_keys = metadata_keys.reject { |key| key == :current_user || params_class.metadata_allowed?(key) }

        return unless disallowed_keys.any?

        # Build a helpful error message
        keys_list = disallowed_keys.map(&:inspect).join(", ")
        class_name = params_class.name

        raise ArgumentError, <<~ERROR.strip
          Metadata key(s) #{keys_list} not allowed for #{class_name}.

          To fix this, declare them in your params class:

            class #{class_name} < ApplicationParams
              metadata #{disallowed_keys.map(&:inspect).join(", ")}
            end

          Note: :current_user is always implicitly allowed and doesn't need to be declared.
        ERROR
      end
    end
  end
end
