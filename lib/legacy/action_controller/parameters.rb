# frozen_string_literal: true

require 'date'
require 'bigdecimal'
require 'stringio'

require 'active_support/concern'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/array/wrap'
require 'action_controller'
require 'action_dispatch/http/upload'

module ActionController
  # Exception raised when a required parameter is missing or empty.
  #
  # @example
  #   params.require(:user)
  #   # => ActionController::ParameterMissing: param is missing or the value is empty: user
  class ParameterMissing < IndexError
    # @return [Symbol, String] the name of the missing parameter
    attr_reader :param

    # Initialize a new ParameterMissing exception
    #
    # @param param [Symbol, String] the name of the missing parameter
    def initialize(param)
      @param = param
      super("param is missing or the value is empty: #{param}")
    end
  end unless defined?(ParameterMissing)

  # Exception raised when unpermitted parameters are detected and configured to raise.
  #
  # @example
  #   params.permit(:name)
  #   # With params containing :admin => true
  #   # => ActionController::UnpermittedParameters: found unpermitted parameters: admin
  class UnpermittedParameters < IndexError
    # @return [Array<String>] the names of the unpermitted parameters
    attr_reader :params

    # Initialize a new UnpermittedParameters exception
    #
    # @param params [Array<String>] the names of the unpermitted parameters
    def initialize(params)
      @params = params
      super("found unpermitted parameters: #{params.join(', ')}")
    end
  end unless defined?(UnpermittedParameters)

  # Strong Parameters implementation for Action Controller.
  #
  # This class provides a whitelist-based approach to mass assignment protection,
  # requiring explicit permission for parameters before they can be used in
  # Active Model mass assignments.
  #
  # @example Basic usage
  #   params = ActionController::Parameters.new(user: { name: 'John', admin: true })
  #   params.require(:user).permit(:name)
  #   # => <ActionController::Parameters {"name"=>"John"} permitted: true>
  class Parameters < ActiveSupport::HashWithIndifferentAccess
    # @return [Boolean] whether this Parameters object is permitted
    attr_accessor :permitted
    alias permitted? permitted

    # @return [Symbol, String, nil] the key used in the last require() call
    attr_accessor :required_key

    cattr_accessor :action_on_unpermitted_parameters, instance_accessor: false

    # Parameters that are never considered unpermitted.
    # These are added by Rails and are of no concern for security.
    NEVER_UNPERMITTED_PARAMS = %w[controller action].freeze

    # Initialize a new Parameters object.
    #
    # @param attributes [Hash, nil] the initial attributes
    def initialize(attributes = nil)
      super(attributes)
      @permitted = false
      @required_key = nil
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
        Array.wrap(value).each do |_|
          _.permit! if _.respond_to?(:permit!)
        end
      end

      @permitted = true
      self
    end

    # Ensure that a parameter is present and not empty.
    #
    # If the parameter is missing or empty, raises ParameterMissing exception.
    # If the parameter is present and is a Parameters object, tracks the key
    # for later use by transform_params.
    #
    # @param key [Symbol, String] the parameter key to require
    # @return [Object] the parameter value
    # @raise [ParameterMissing] if the parameter is missing or empty
    # @example
    #   params.require(:user)
    #   params.require(:user).permit(:name, :email)
    def require(key)
      value = self[key].presence || raise(ActionController::ParameterMissing.new(key))
      # Track the required key so transform_params can infer the params class
      if value.is_a?(Parameters)
        value.required_key = key
      end
      value
    end

    alias required require

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
    # params classes defined in app/params/. It automatically looks up the
    # appropriate params class based on the required_key if not explicitly provided.
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
    # @example With additional attributes
    #   params.require(:user).transform_params(additional_attrs: [:temp_token])
    #
    # @example With metadata
    #   params.require(:account).transform_params(
    #     current_user: current_user,
    #     ip_address: request.ip,
    #     role: current_user.role
    #   )
    #   # Note: :ip_address and :role must be declared in AccountParams using `metadata :ip_address, :role`
    #
    # @note Any metadata keys other than :current_user must be explicitly declared
    #   in the params class using the `metadata` DSL method.
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

      # Get permitted attributes and apply them
      permitted_attrs = params_class.permitted_attributes(action: action)
      permitted_attrs += additional_attrs
      permit(*permitted_attrs)
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
      convert_hashes_to_parameters(key, super)
    end

    # Fetch a parameter value by key, raising ParameterMissing if not found.
    #
    # @param key [Symbol, String] the parameter key
    # @param args additional arguments passed to Hash#fetch
    # @return [Object] the parameter value
    # @raise [ParameterMissing] if the key is not found
    def fetch(key, *args)
      convert_hashes_to_parameters(key, super, false)
    rescue KeyError, IndexError
      raise ActionController::ParameterMissing.new(key)
    end

    # Create a new Parameters object containing only the specified keys.
    #
    # @param keys [Array<Symbol, String>] the keys to include
    # @return [Parameters] a new Parameters object with only the specified keys
    # @example
    #   params.slice(:name, :email)
    def slice(*keys)
      # Manually slice the hash since ActiveSupport 3.0 might not have slice
      sliced = {}
      keys.each do |key|
        sliced[key] = self[key] if has_key?(key)
      end

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
        duplicate.default = default
        duplicate.instance_variable_set(:@permitted, @permitted)
        duplicate.instance_variable_set(:@required_key, @required_key)
      end
    end

    protected
      def convert_value(value)
        if value.class == Hash
          self.class.new_from_hash_copying_default(value)
        elsif value.is_a?(Array)
          value.dup.replace(value.map { |e| convert_value(e) })
        else
          value
        end
      end

    private

      def convert_hashes_to_parameters(key, value, assign_if_converted=true)
        converted = convert_value_to_parameters(value)
        self[key] = converted if assign_if_converted && !converted.equal?(value)
        converted
      end

      def convert_value_to_parameters(value)
        if value.is_a?(Array)
          value.map { |_| convert_value_to_parameters(_) }
        elsif value.is_a?(Parameters) || !value.is_a?(Hash)
          value
        else
          self.class.new(value)
        end
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
      # Note: DateTime inherits from Date, so it's implicitly included via Date.
      #
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
        IO,
        ActionDispatch::Http::UploadedFile,
        Rack::Test::UploadedFile
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
        if has_key?(key) && permitted_scalar?(self[key])
          params[key] = self[key]
        end

        keys.grep(/\A#{Regexp.escape(key.to_s)}\(\d+[if]?\)\z/).each do |key|
          if permitted_scalar?(self[key])
            params[key] = self[key]
          end
        end
      end

      def array_of_permitted_scalars_filter(params, key, hash = self)
        if hash.has_key?(key) && array_of_permitted_scalars?(hash[key])
          params[key] = hash[key]
        end
      end

      def hash_filter(params, filter)
        filter = filter.with_indifferent_access

        # Slicing filters out non-declared keys.
        slice(*filter.keys).each do |key, value|
          next unless value

          if filter[key] == []
            # Declaration {:comment_ids => []}.
            array_of_permitted_scalars_filter(params, key)
          else
            # Declaration {:user => :name} or {:user => [:name, :age, {:adress => ...}]}.
            params[key] = each_element(value) do |element, index|
              if element.is_a?(Hash)
                element = self.class.new(element) unless element.respond_to?(:permit)
                element.permit(*Array.wrap(filter[key]))
              elsif filter[key].is_a?(Hash) && filter[key][index] == []
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
          value.each { |k,v| hash[k] = yield(v, k) }
          hash
        else
          yield value
        end
      end

      def fields_for_style?(object)
        object.is_a?(Hash) && object.all? { |k, v| k =~ /\A-?\d+\z/ && v.is_a?(Hash) }
      end

      def unpermitted_parameters!(params)  
        return unless self.class.action_on_unpermitted_parameters
        
        unpermitted_keys = unpermitted_keys(params)

        if unpermitted_keys.any?  
          case self.class.action_on_unpermitted_parameters  
          when :log
            name = "unpermitted_parameters.action_controller"
            ActiveSupport::Notifications.instrument(name, :keys => unpermitted_keys)
          when :raise  
            raise ActionController::UnpermittedParameters.new(unpermitted_keys)  
          end  
        end  
      end  
  
      def unpermitted_keys(params)
        self.keys - params.keys - NEVER_UNPERMITTED_PARAMS
      end

      # Validate that all provided metadata keys are allowed by the params class.
      #
      # @param params_class [Class] the params class to validate against
      # @param metadata_keys [Array<Symbol>] the metadata keys to validate
      # @raise [ArgumentError] if any metadata keys are not declared
      # @return [void]
      def validate_metadata_keys!(params_class, metadata_keys)
        return if metadata_keys.empty?

        disallowed_keys = metadata_keys.reject { |key| params_class.metadata_allowed?(key) }

        return unless disallowed_keys.any?

        # Build a helpful error message
        keys_list = disallowed_keys.map(&:inspect).join(', ')
        class_name = params_class.name

        raise ArgumentError, <<~ERROR.strip
          Metadata key(s) #{keys_list} not allowed for #{class_name}.

          To fix this, declare them in your params class:

            class #{class_name} < ApplicationParams
              metadata #{disallowed_keys.map(&:inspect).join(', ')}
            end

          Note: :current_user is always implicitly allowed and doesn't need to be declared.
        ERROR
      end
  end

  # Controller integration module for Strong Parameters.
  #
  # This module provides the params method to controllers and handles
  # ParameterMissing exceptions with a 400 Bad Request response.
  #
  # @example
  #   class ApplicationController < ActionController::Base
  #     include ActionController::StrongParameters
  #   end
  module StrongParameters
    extend ActiveSupport::Concern

    included do
      rescue_from(ActionController::ParameterMissing) do |parameter_missing_exception|
        render text: "Required parameter missing: #{parameter_missing_exception.param}",
               status: :bad_request
      end
    end

    # Access request parameters as a Parameters object.
    #
    # @return [Parameters] the request parameters wrapped in a Parameters object
    def params
      @_params ||= Parameters.new(request.parameters)
    end

    # Set the parameters for this request.
    #
    # @param val [Hash, Parameters] the parameters to set
    # @return [Parameters] the parameters
    def params=(val)
      @_params = val.is_a?(Hash) ? Parameters.new(val) : val
    end
  end
end

ActiveSupport.on_load(:action_controller) { include ActionController::StrongParameters }
