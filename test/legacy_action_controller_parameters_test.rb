# frozen_string_literal: true

require "test_helper"

# Load the legacy implementation in isolation
module Legacy
  module ActionController
    # Exception raised when a required parameter is missing or empty.
    #
    # @example
    #   params.require(:user)
    #   # => ActionController::ParameterMissing: param is missing or the value is empty: user
    unless defined?(ParameterMissing)
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
      end
    end

    # Exception raised when unpermitted parameters are detected and configured to raise.
    #
    # @example
    #   params.permit(:name)
    #   # With params containing :admin => true
    #   # => ActionController::UnpermittedParameters: found unpermitted parameters: admin
    unless defined?(UnpermittedParameters)
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
    end

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
      alias_method :permitted?, :permitted

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
        super
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
          Array.wrap(value).each do |v|
            v.permit! if v.respond_to?(:permit!)
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
        value = self[key]
        if value.nil? || (value.is_a?(String) && value.empty?)
          raise Legacy::ActionController::ParameterMissing.new(key)
        end
        # Track the required key so transform_params can infer the params class
        if value.is_a?(Parameters)
          value.required_key = key
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
        convert_hashes_to_parameters(key, super)
      rescue KeyError
        raise Legacy::ActionController::ParameterMissing.new(key)
      rescue IndexError
        raise Legacy::ActionController::ParameterMissing.new(key)
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
        if value.is_a?(Hash)
          self.class.new(value)
        elsif value.is_a?(Array)
          value.map { |e| convert_value(e) }
        else
          value
        end
      end

      private

      def convert_hashes_to_parameters(key, value)
        converted = convert_value(value)
        self[key] = converted if converted != value
        converted
      end

      def convert_value(value, options = {})
        if value.is_a?(Hash)
          self.class.new(value)
        elsif value.is_a?(Array)
          value.map { |e| convert_value(e, options) }
        else
          value
        end
      end

      def convert_value_to_parameters(value)
        convert_value(value)
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
          value.each { |k, v| hash[k] = yield(v, k) }
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
            ActiveSupport::Notifications.instrument(name, keys: unpermitted_keys)
          when :raise
            raise Legacy::ActionController::UnpermittedParameters.new(unpermitted_keys)
          end
        end
      end

      def unpermitted_keys(params)
        keys - params.keys - NEVER_UNPERMITTED_PARAMS
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
end

# Mock ParamsRegistry for testing
class MockParamsRegistry
  def self.lookup(key)
    # Return a mock params class for testing
    Class.new do
      def self.permitted_attributes(action: nil)
        [:name, :email]
      end

      def self.metadata_allowed?(key)
        key == :current_user
      end

      def self.name
        "MockParams"
      end
    end
  end
end

# Test the legacy ActionController::Parameters implementation
class LegacyActionControllerParametersTest < Minitest::Test
  def setup
    # Use the legacy Parameters class for these tests
    @parameters_class = Legacy::ActionController::Parameters
    @parameters_class.action_on_unpermitted_parameters = false
  end

  def teardown
    @parameters_class.action_on_unpermitted_parameters = false
  end

  def assert_filtered_out(params, key)
    assert !params.has_key?(key), "key #{key.inspect} has not been filtered out"
  end

  #
  # --- Initialization --------------------------------------------------------
  #

  def test_initialize_with_nil
    params = @parameters_class.new
    assert_equal({}, params.to_h)
    refute params.permitted?
    assert_nil params.required_key
  end

  def test_initialize_with_hash
    hash = {name: "John", age: 30}
    params = @parameters_class.new(hash)
    assert_equal hash.stringify_keys, params.to_h
    refute params.permitted?
    assert_nil params.required_key
  end

  def test_initialize_with_indifferent_access
    hash = ActiveSupport::HashWithIndifferentAccess.new(name: "John")
    params = @parameters_class.new(hash)
    assert_equal "John", params[:name]
    assert_equal "John", params["name"]
  end

  #
  # --- Basic access methods --------------------------------------------------
  #

  def test_access_with_symbol_key
    params = @parameters_class.new("name" => "John")
    assert_equal "John", params[:name]
  end

  def test_access_with_string_key
    params = @parameters_class.new(name: "John")
    assert_equal "John", params["name"]
  end

  def test_access_converts_hashes_to_parameters
    params = @parameters_class.new(user: {name: "John"})
    user_params = params[:user]
    assert_instance_of @parameters_class, user_params
    assert_equal "John", user_params[:name]
  end

  def test_access_converts_nested_arrays_of_hashes
    params = @parameters_class.new(users: [{name: "John"}, {name: "Jane"}])
    users = params[:users]
    assert_instance_of Array, users
    assert_instance_of @parameters_class, users[0]
    assert_instance_of @parameters_class, users[1]
    assert_equal "John", users[0][:name]
    assert_equal "Jane", users[1][:name]
  end

  #
  # --- Fetch method ----------------------------------------------------------
  #

  def test_fetch_existing_key
    params = @parameters_class.new(name: "John")
    assert_equal "John", params.fetch(:name)
  end

  def test_fetch_with_default
    params = @parameters_class.new(name: "John")
    assert_equal "default", params.fetch(:missing, "default")
  end

  def test_fetch_raises_parameter_missing_for_missing_key
    params = @parameters_class.new(name: "John")
    error = assert_raises(Legacy::ActionController::ParameterMissing) do
      params.fetch(:missing)
    end
    assert_equal :missing, error.param
  end

  def test_fetch_raises_parameter_missing_for_key_error
    params = @parameters_class.new
    # Simulate a KeyError by mocking the super call
    def params.super_fetch(key, *args)
      raise KeyError, "key not found: #{key}"
    end

    error = assert_raises(Legacy::ActionController::ParameterMissing) do
      params.fetch(:missing)
    end
    assert_equal :missing, error.param
  end

  #
  # --- Require method --------------------------------------------------------
  #

  def test_require_existing_key
    params = @parameters_class.new(user: {name: "John"})
    user_params = params.require(:user)
    assert_instance_of @parameters_class, user_params
    assert_equal :user, user_params.required_key
    assert_equal "John", user_params[:name]
  end

  def test_require_missing_key
    params = @parameters_class.new(name: "John")
    error = assert_raises(Legacy::ActionController::ParameterMissing) do
      params.require(:user)
    end
    assert_equal :user, error.param
  end

  def test_require_empty_value
    params = @parameters_class.new(user: {})
    user_params = params.require(:user)
    assert_instance_of @parameters_class, user_params
    assert_equal :user, user_params.required_key
  end

  def test_require_nil_value
    params = @parameters_class.new(user: nil)
    error = assert_raises(Legacy::ActionController::ParameterMissing) do
      params.require(:user)
    end
    assert_equal :user, error.param
  end

  def test_require_false_value
    params = @parameters_class.new(active: false)
    result = params.require(:active)
    assert_equal false, result
  end

  def test_required_alias
    params = @parameters_class.new(user: {name: "John"})
    user_params = params.required(:user)
    assert_instance_of @parameters_class, user_params
    assert_equal :user, user_params.required_key
  end

  #
  # --- Permit method ---------------------------------------------------------
  #

  def test_permit_empty
    params = @parameters_class.new(name: "John", age: 30)
    permitted = params.permit
    assert_instance_of @parameters_class, permitted
    assert permitted.permitted?
    assert_empty permitted
  end

  def test_permit_single_key
    params = @parameters_class.new(name: "John", age: 30)
    permitted = params.permit(:name)
    assert_equal "John", permitted[:name]
    assert_filtered_out permitted, :age
    assert permitted.permitted?
  end

  def test_permit_multiple_keys
    params = @parameters_class.new(name: "John", age: 30, email: "john@example.com")
    permitted = params.permit(:name, :age)
    assert_equal "John", permitted[:name]
    assert_equal 30, permitted[:age]
    assert_filtered_out permitted, :email
    assert permitted.permitted?
  end

  def test_permit_array_of_keys
    params = @parameters_class.new(name: "John", age: 30)
    permitted = params.permit([:name, :age])
    assert_equal "John", permitted[:name]
    assert_equal 30, permitted[:age]
    assert permitted.permitted?
  end

  def test_permit_nested_hash
    params = @parameters_class.new(user: {name: "John", age: 30}, admin: true)
    permitted = params.permit(user: [:name])
    assert_equal "John", permitted[:user][:name]
    assert_filtered_out permitted[:user], :age
    assert_filtered_out permitted, :admin
    assert permitted.permitted?
  end

  def test_permit_empty_array
    params = @parameters_class.new(tags: ["ruby", "rails"], name: "John")
    permitted = params.permit(:tags => [])
    assert_equal ["ruby", "rails"], permitted[:tags]
    assert_filtered_out permitted, :name
    assert permitted.permitted?
  end

  def test_permit_empty_array_with_invalid_elements
    params = @parameters_class.new(tags: ["ruby", {invalid: "hash"}], name: "John")
    permitted = params.permit(:tags => [])
    assert_filtered_out permitted, :tags
    assert_filtered_out permitted, :name
    assert permitted.permitted?
  end

  #
  # --- Permit! method --------------------------------------------------------
  #

  def test_permit_bang_marks_permitted
    params = @parameters_class.new(name: "John", age: 30)
    params.permit!
    assert params.permitted?
  end

  def test_permit_bang_converts_nested_hashes
    params = @parameters_class.new(user: {name: "John", profile: {bio: "Developer"}})
    params.permit!
    assert params.permitted?
    assert params[:user].permitted?
    assert params[:user][:profile].permitted?
  end

  def test_permit_bang_converts_nested_arrays
    params = @parameters_class.new(users: [{name: "John"}, {name: "Jane"}])
    params.permit!
    assert params.permitted?
    assert params[:users][0].permitted?
    assert params[:users][1].permitted?
  end

  #
  # --- Permitted? method -----------------------------------------------------
  #

  def test_permitted_predicate
    params = @parameters_class.new(name: "John")
    refute params.permitted?
    params.permit!
    assert params.permitted?
  end

  def test_permitted_alias
    params = @parameters_class.new(name: "John")
    refute params.permitted?
    params.permit!
    assert params.permitted?
  end

  #
  # --- Slice method ----------------------------------------------------------
  #

  def test_slice_single_key
    params = @parameters_class.new(name: "John", age: 30, email: "john@example.com")
    sliced = params.slice(:name)
    assert_equal "John", sliced[:name]
    assert_filtered_out sliced, :age
    assert_filtered_out sliced, :email
    assert_equal params.permitted?, sliced.permitted?
    assert_equal params.required_key, sliced.required_key
  end

  def test_slice_multiple_keys
    params = @parameters_class.new(name: "John", age: 30, email: "john@example.com")
    sliced = params.slice(:name, :age)
    assert_equal "John", sliced[:name]
    assert_equal 30, sliced[:age]
    assert_filtered_out sliced, :email
    assert_equal params.permitted?, sliced.permitted?
    assert_equal params.required_key, sliced.required_key
  end

  def test_slice_preserves_required_key
    params = @parameters_class.new(user: {name: "John", age: 30})
    user_params = params.require(:user)
    sliced = user_params.slice(:name)
    assert_equal :user, sliced.required_key
  end

  #
  # --- Except method ---------------------------------------------------------
  #

  def test_except_single_key
    params = @parameters_class.new(name: "John", age: 30, email: "john@example.com")
    excepted = params.except(:age)
    assert_equal "John", excepted[:name]
    assert_equal "john@example.com", excepted[:email]
    assert_filtered_out excepted, :age
  end

  def test_except_multiple_keys
    params = @parameters_class.new(name: "John", age: 30, email: "john@example.com")
    excepted = params.except(:age, :email)
    assert_equal "John", excepted[:name]
    assert_filtered_out excepted, :age
    assert_filtered_out excepted, :email
  end

  def test_except_preserves_state
    params = @parameters_class.new(name: "John", age: 30)
    params.permit!
    excepted = params.except(:age)
    assert excepted.permitted?
  end

  #
  # --- Dup method ------------------------------------------------------------
  #

  def test_dup_preserves_state
    params = @parameters_class.new(name: "John", age: 30)
    params.permit!
    params.required_key = :user

    duplicated = params.dup
    assert_equal params.to_h, duplicated.to_h
    assert duplicated.permitted?
    assert_equal :user, duplicated.required_key
  end

  def test_dup_preserves_default
    params = @parameters_class.new
    params.default = "default_value"
    duplicated = params.dup
    assert_equal "default_value", duplicated.default
  end

  #
  # --- Transform_params method -----------------------------------------------
  #

  def test_transform_params_with_inference
    # Use MockParamsRegistry
    original_registry = Legacy::ActionController::Parameters.const_get(:ParamsRegistry) rescue nil
    Legacy::ActionController::Parameters.const_set(:ParamsRegistry, MockParamsRegistry)

    params = @parameters_class.new(user: {name: "John", age: 30})
    user_params = params.require(:user)
    permitted = user_params.transform_params

    assert permitted.permitted?
    assert_equal "John", permitted[:name]
    assert_equal "John", permitted[:email] # Mock returns [:name, :email]

    # Age should not be included since it's not in permitted_attributes
    assert_filtered_out permitted, :age

    Legacy::ActionController::Parameters.const_set(:ParamsRegistry, original_registry) if original_registry
  end

  def test_transform_params_with_explicit_class
    mock_params_class = Minitest::Mock.new
    mock_params_class.expect(:permitted_attributes, [:name], [action: nil])

    params = @parameters_class.new(user: {name: "John", age: 30})
    user_params = params.require(:user)
    permitted = user_params.transform_params(mock_params_class)

    assert permitted.permitted?
    assert_equal "John", permitted[:name]
    assert_filtered_out permitted, :age

    mock_params_class.verify
  end

  def test_transform_params_with_nil_class
    params = @parameters_class.new(user: {name: "John"})
    user_params = params.require(:user)
    permitted = user_params.transform_params(nil)

    assert permitted.permitted?
    assert_empty permitted
  end

  def test_transform_params_without_required_key
    params = @parameters_class.new(name: "John")
    permitted = params.transform_params

    assert permitted.permitted?
    assert_empty permitted
  end

  def test_transform_params_with_action
    mock_params_class = Minitest::Mock.new

    mock_params_class.expect(:permitted_attributes, [:name, :email], [action: :create])
    mock_params_class.expect(:permitted_attributes, [:name], [action: :update])

    params = @parameters_class.new(user: {name: "John", email: "john@example.com"})
    user_params = params.require(:user)

    permitted_create = user_params.transform_params(mock_params_class, action: :create)
    assert_equal "John", permitted_create[:name]
    assert_equal "john@example.com", permitted_create[:email]

    permitted_update = user_params.transform_params(mock_params_class, action: :update)
    assert_equal "John", permitted_update[:name]
    assert_filtered_out permitted_update, :email

    mock_params_class.verify
  end

  def test_transform_params_with_additional_attrs
    mock_params_class = Minitest::Mock.new

    mock_params_class.expect(:permitted_attributes, [:name], [action: nil])

    params = @parameters_class.new(user: {name: "John", token: "abc123"})
    user_params = params.require(:user)
    permitted = user_params.transform_params(mock_params_class, additional_attrs: [:token])

    assert_equal "John", permitted[:name]
    assert_equal "abc123", permitted[:token]

    mock_params_class.verify
  end

  def test_transform_params_with_invalid_metadata
    mock_params_class = Minitest::Mock.new

    mock_params_class.expect(:permitted_attributes, [:name], [action: nil])
    mock_params_class.expect(:metadata_allowed?, false, [:invalid_metadata])
    mock_params_class.expect(:name, "TestParams")

    params = @parameters_class.new(user: {name: "John"})
    user_params = params.require(:user)

    error = assert_raises(ArgumentError) do
      user_params.transform_params(mock_params_class, invalid_metadata: "value")
    end

    assert_includes error.message, "Metadata key(s) :invalid_metadata not allowed"

    mock_params_class.verify
  end

  #
  # --- Permit_by_model method ------------------------------------------------
  #

  def test_permit_by_model
    original_registry = Legacy::ActionController::Parameters.const_get(:ParamsRegistry) rescue nil
    Legacy::ActionController::Parameters.const_set(:ParamsRegistry, MockParamsRegistry)

    params = @parameters_class.new(user: {name: "John", age: 30})
    user_params = params.require(:user)
    permitted = user_params.permit_by_model(:user)

    assert permitted.permitted?
    assert_equal "John", permitted[:name]
    assert_equal "John", permitted[:email] # Mock returns [:name, :email]
    assert_filtered_out permitted, :age

    Legacy::ActionController::Parameters.const_set(:ParamsRegistry, original_registry) if original_registry
  end

  #
  # --- Permitted scalar types ------------------------------------------------
  #

  def test_permitted_scalar_types
    permitted_values = [
      "string",
      :symbol,
      nil,
      123,
      123.45,
      true,
      false,
      Date.today,
      Time.now,
      DateTime.now,
      StringIO.new,
      $stdout,
      ActionDispatch::Http::UploadedFile.new(tempfile: __FILE__),
      Rack::Test::UploadedFile.new(__FILE__)
    ]

    params = @parameters_class.new

    permitted_values.each do |value|
      assert params.send(:permitted_scalar?, value), "#{value.inspect} should be permitted"
    end
  end

  def test_non_permitted_scalar_types
    non_permitted_values = [
      Object.new,
      {},
      [],
      1..10,
      /regex/
    ]

    params = @parameters_class.new

    non_permitted_values.each do |value|
      refute params.send(:permitted_scalar?, value), "#{value.inspect} should not be permitted"
    end
  end

  #
  # --- Array of permitted scalars ---------------------------------------------
  #

  def test_array_of_permitted_scalars_valid
    params = @parameters_class.new
    assert params.send(:array_of_permitted_scalars?, ["string", 123, true])
  end

  def test_array_of_permitted_scalars_invalid
    params = @parameters_class.new
    refute params.send(:array_of_permitted_scalars?, ["string", {}, 123])
    refute params.send(:array_of_permitted_scalars?, "not_an_array")
  end

  #
  # --- Filtering helpers -----------------------------------------------------
  #

  def test_permitted_scalar_filter
    params = @parameters_class.new
    result = @parameters_class.new

    # Test with permitted scalar
    params[:name] = "John"
    params.send(:permitted_scalar_filter, result, :name)
    assert_equal "John", result[:name]

    # Test with non-permitted scalar
    params[:invalid] = Object.new
    params.send(:permitted_scalar_filter, result, :invalid)
    assert_filtered_out result, :invalid
  end

  def test_array_of_permitted_scalars_filter
    params = @parameters_class.new
    result = @parameters_class.new

    # Test with valid array
    params[:tags] = ["ruby", "rails"]
    params.send(:array_of_permitted_scalars_filter, result, :tags)
    assert_equal ["ruby", "rails"], result[:tags]

    # Test with invalid array
    params[:invalid] = ["string", {}]
    params.send(:array_of_permitted_scalars_filter, result, :invalid)
    assert_filtered_out result, :invalid
  end

  #
  # --- Hash filtering --------------------------------------------------------
  #

  def test_hash_filter_simple
    params = @parameters_class.new
    result = @parameters_class.new

    params[:user] = @parameters_class.new(name: "John", age: 30)
    params.send(:hash_filter, result, {user: [:name]})

    assert_equal "John", result[:user][:name]
    assert_filtered_out result[:user], :age
  end

  def test_hash_filter_nested
    params = @parameters_class.new
    result = @parameters_class.new

    params[:user] = @parameters_class.new(
      name: "John",
      profile: @parameters_class.new(bio: "Developer", age: 30)
    )
    params.send(:hash_filter, result, {user: {profile: [:bio]}})

    assert_equal "Developer", result[:user][:profile][:bio]
    assert_filtered_out result[:user][:profile], :age
  end

  def test_hash_filter_with_array
    params = @parameters_class.new
    result = @parameters_class.new

    params[:user] = @parameters_class.new(
      name: "John",
      tags: ["ruby", "rails"]
    )
    params.send(:hash_filter, result, {user: [:name, {tags: []}]})

    assert_equal "John", result[:user][:name]
    assert_equal ["ruby", "rails"], result[:user][:tags]
  end

  #
  # --- Each element ----------------------------------------------------------
  #

  def test_each_element_with_array
    params = @parameters_class.new
    elements = ["item1", "item2"]
    result = params.send(:each_element, elements) do |element|
      element.upcase
    end
    assert_equal ["ITEM1", "ITEM2"], result
  end

  def test_each_element_with_fields_for_style
    params = @parameters_class.new
    hash = {"0" => {name: "John"}, "1" => {name: "Jane"}}
    result = params.send(:each_element, hash) do |element, index|
      element[:name] = element[:name].upcase
      element
    end
    assert_equal "JOHN", result["0"][:name]
    assert_equal "JANE", result["1"][:name]
  end

  def test_each_element_with_single_value
    params = @parameters_class.new
    value = {name: "John"}
    result = params.send(:each_element, value) do |element|
      element[:name] = element[:name].upcase
      element
    end
    assert_equal "JOHN", result[:name]
  end

  #
  # --- Fields for style detection --------------------------------------------
  #

  def test_fields_for_style_detection
    params = @parameters_class.new

    # Valid fields_for style
    valid = {"0" => {name: "John"}, "1" => {name: "Jane"}}
    assert params.send(:fields_for_style?, valid)

    # Invalid - contains non-numeric keys
    invalid1 = {"name" => {name: "John"}}
    refute params.send(:fields_for_style?, invalid1)

    # Invalid - contains non-hash values
    invalid2 = {"0" => "string"}
    refute params.send(:fields_for_style?, invalid2)

    # Invalid - not a hash
    refute params.send(:fields_for_style?, [])
  end

  #
  # --- Unpermitted parameters handling ---------------------------------------
  #

  def test_unpermitted_parameters_logging
    @parameters_class.action_on_unpermitted_parameters = :log

    params = @parameters_class.new(name: "John", admin: true)
    permitted = params.permit(:name)

    assert_equal "John", permitted[:name]
    assert_filtered_out permitted, :admin
  end

  def test_unpermitted_parameters_raising
    @parameters_class.action_on_unpermitted_parameters = :raise

    params = @parameters_class.new(name: "John", admin: true)

    error = assert_raises(Legacy::ActionController::UnpermittedParameters) do
      params.permit(:name)
    end

    assert_equal ["admin"], error.params
  end

  def test_unpermitted_keys_calculation
    params = @parameters_class.new(name: "John", age: 30, admin: true)
    permitted_params = @parameters_class.new(name: "John")

    unpermitted = params.send(:unpermitted_keys, permitted_params)
    assert_equal ["age", "admin"], unpermitted.sort
  end

  def test_unpermitted_keys_excludes_never_unpermitted
    params = @parameters_class.new(name: "John", controller: "users", action: "create")
    permitted_params = @parameters_class.new

    unpermitted = params.send(:unpermitted_keys, permitted_params)
    assert_equal ["name"], unpermitted
  end

  #
  # --- Convert value ---------------------------------------------------------
  #

  def test_convert_value_with_hash
    params = @parameters_class.new
    hash = {name: "John"}
    converted = params.send(:convert_value, hash)
    assert_instance_of @parameters_class, converted
    assert_equal "John", converted[:name]
  end

  def test_convert_value_with_array
    params = @parameters_class.new
    array = [{name: "John"}, "string"]
    converted = params.send(:convert_value, array)
    assert_instance_of Array, converted
    assert_instance_of @parameters_class, converted[0]
    assert_equal "string", converted[1]
  end

  def test_convert_value_with_scalar
    params = @parameters_class.new
    assert_equal "string", params.send(:convert_value, "string")
    assert_equal 123, params.send(:convert_value, 123)
  end

  #
  # --- Convert hashes to parameters ------------------------------------------
  #

  def test_convert_hashes_to_parameters_assigns_if_converted
    params = @parameters_class.new
    hash = {name: "John"}
    converted = params.send(:convert_hashes_to_parameters, :user, hash)
    assert_equal hash, converted
    assert_instance_of @parameters_class, params[:user]
  end

  def test_convert_hashes_to_parameters_does_not_assign_if_same
    params = @parameters_class.new
    existing_params = @parameters_class.new(name: "John")
    params[:user] = existing_params
    converted = params.send(:convert_hashes_to_parameters, :user, existing_params)
    assert_equal existing_params, converted
    assert_equal existing_params.object_id, params[:user].object_id
  end

  #
  # --- Convert value to parameters -------------------------------------------
  #

  def test_convert_value_to_parameters_with_array
    params = @parameters_class.new
    array = [{name: "John"}, "string"]
    converted = params.send(:convert_value_to_parameters, array)
    assert_instance_of Array, converted
    assert_instance_of @parameters_class, converted[0]
    assert_equal "string", converted[1]
  end

  def test_convert_value_to_parameters_with_existing_parameters
    params = @parameters_class.new
    existing = @parameters_class.new(name: "John")
    converted = params.send(:convert_value_to_parameters, existing)
    assert_equal existing, converted
  end

  def test_convert_value_to_parameters_with_hash
    params = @parameters_class.new
    hash = {name: "John"}
    converted = params.send(:convert_value_to_parameters, hash)
    assert_instance_of @parameters_class, converted
    assert_equal "John", converted[:name]
  end

  def test_convert_value_to_parameters_with_non_hash
    params = @parameters_class.new
    assert_equal "string", params.send(:convert_value_to_parameters, "string")
    assert_equal 123, params.send(:convert_value_to_parameters, 123)
  end

  #
  # --- Exception classes -----------------------------------------------------
  #

  def test_parameter_missing_exception
    error = Legacy::ActionController::ParameterMissing.new(:user)
    assert_equal :user, error.param
    assert_equal "param is missing or the value is empty: user", error.message
  end

  def test_unpermitted_parameters_exception
    error = Legacy::ActionController::UnpermittedParameters.new(["admin", "secret"])
    assert_equal ["admin", "secret"], error.params
    assert_equal "found unpermitted parameters: admin, secret", error.message
  end

  #
  # --- StrongParameters module -----------------------------------------------
  #

  def test_strong_parameters_module_inclusion
    controller_class = Class.new do
      include Legacy::ActionController::StrongParameters

      def request
        Struct.new(:parameters).new({name: "John"})
      end
    end

    controller = controller_class.new
    params = controller.params

    assert_instance_of @parameters_class, params
    assert_equal "John", params[:name]
  end

  #
  # --- Edge cases -----------------------------------------------------------
  #

  def test_permit_with_multi_parameter_attributes
    params = @parameters_class.new(
      "date(1i)" => "2023",
      "date(2i)" => "12",
      "date(3i)" => "25"
    )
    permitted = params.permit(:date)
    assert_equal "2023", permitted["date(1i)"]
    assert_equal "12", permitted["date(2i)"]
    assert_equal "25", permitted["date(3i)"]
  end

  def test_slice_with_nonexistent_keys
    params = @parameters_class.new(name: "John")
    sliced = params.slice(:name, :nonexistent)
    assert_equal "John", sliced[:name]
    refute sliced.has_key?(:nonexistent)
  end

  def test_except_with_nonexistent_keys
    params = @parameters_class.new(name: "John")
    excepted = params.except(:nonexistent)
    assert_equal "John", excepted[:name]
  end

  def test_require_with_parameters_instance
    params = @parameters_class.new(user: @parameters_class.new(name: "John"))
    user_params = params.require(:user)
    assert_equal :user, user_params.required_key
  end

  def test_permit_with_empty_filter_array
    params = @parameters_class.new(name: "John", age: 30)
    permitted = params.permit([])
    assert_empty permitted
    assert permitted.permitted?
  end

  def test_transform_params_with_empty_options
    mock_params_class = Minitest::Mock.new

    def mock_params_class.permitted_attributes(action: nil)
      [:name]
    end

    def mock_params_class.metadata_allowed?(key)
      false
    end

    params = @parameters_class.new(user: {name: "John"})
    user_params = params.require(:user)
    permitted = user_params.transform_params(mock_params_class, {})

    assert_equal "John", permitted[:name]
  end

  def test_validate_metadata_keys_with_allowed_keys
    mock_params_class = Minitest::Mock.new

    def mock_params_class.metadata_allowed?(key)
      key == :current_user
    end

    params = @parameters_class.new(user: {name: "John"})
    user_params = params.require(:user)

    # Should not raise
    user_params.send(:validate_metadata_keys!, mock_params_class, [:current_user])
  end

  def test_validate_metadata_keys_with_disallowed_keys
    mock_params_class = Minitest::Mock.new

    def mock_params_class.metadata_allowed?(key)
      false
    end

    def mock_params_class.name
      "TestParams"
    end

    params = @parameters_class.new(user: {name: "John"})
    user_params = params.require(:user)

    error = assert_raises(ArgumentError) do
      user_params.send(:validate_metadata_keys!, mock_params_class, [:invalid])
    end

    assert_includes error.message, "Metadata key(s) :invalid not allowed"
  end
end