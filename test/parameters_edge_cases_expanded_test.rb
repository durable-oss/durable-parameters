# frozen_string_literal: true

require "test_helper"

# Additional edge case tests for comprehensive coverage
class ParametersEdgeCasesExpandedTest < Minitest::Test
  def setup
    StrongParameters::Core::Parameters.action_on_unpermitted_parameters = nil
  end

  def teardown
    StrongParameters::Core::Parameters.action_on_unpermitted_parameters = nil
  end

  # Test permit_by_model (legacy method)
  def test_permit_by_model_with_registered_class
    params_class = Class.new(StrongParameters::Core::ApplicationParams) do
      allow :name
      allow :email
    end
    StrongParameters::Core::ParamsRegistry.register(:user, params_class)

    params = StrongParameters::Core::Parameters.new(user: {name: "John", email: "john@example.com", admin: true})
    user_params = params.require(:user)
    permitted = user_params.permit_by_model(:user)

    assert_equal "John", permitted[:name]
    assert_equal "john@example.com", permitted[:email]
    assert_nil permitted[:admin]
    assert permitted.permitted?
  ensure
    StrongParameters::Core::ParamsRegistry.clear!
  end

  def test_permit_by_model_with_action
    params_class = Class.new(StrongParameters::Core::ApplicationParams) do
      allow :name
      allow :email, only: :create
    end
    StrongParameters::Core::ParamsRegistry.register(:user, params_class)

    params = StrongParameters::Core::Parameters.new(user: {name: "John", email: "john@example.com"})
    user_params = params.require(:user)

    # With create action
    permitted_create = user_params.permit_by_model(:user, action: :create)
    assert_equal "John", permitted_create[:name]
    assert_equal "john@example.com", permitted_create[:email]

    # With update action
    permitted_update = user_params.permit_by_model(:user, action: :update)
    assert_equal "John", permitted_update[:name]
    assert_nil permitted_update[:email]
  ensure
    StrongParameters::Core::ParamsRegistry.clear!
  end

  def test_permit_by_model_with_additional_attrs
    params_class = Class.new(StrongParameters::Core::ApplicationParams) do
      allow :name
    end
    StrongParameters::Core::ParamsRegistry.register(:user, params_class)

    params = StrongParameters::Core::Parameters.new(user: {name: "John", token: "abc123"})
    user_params = params.require(:user)
    permitted = user_params.permit_by_model(:user, additional_attrs: [:token])

    assert_equal "John", permitted[:name]
    assert_equal "abc123", permitted[:token]
  ensure
    StrongParameters::Core::ParamsRegistry.clear!
  end

  # Test convert_value protected method variations
  def test_convert_value_with_parameters_instance
    params = StrongParameters::Core::Parameters.new(name: "John")
    inner_params = StrongParameters::Core::Parameters.new(bio: "Developer")
    converted = params.send(:convert_value, inner_params)
    assert_equal inner_params, converted
    assert converted.is_a?(StrongParameters::Core::Parameters)
  end

  def test_convert_value_with_empty_array
    params = StrongParameters::Core::Parameters.new
    converted = params.send(:convert_value, [])
    assert_equal [], converted
  end

  def test_convert_value_with_mixed_array
    params = StrongParameters::Core::Parameters.new
    array = [{name: "John"}, "string", 123, nil]
    converted = params.send(:convert_value, array)
    assert converted[0].is_a?(StrongParameters::Core::Parameters)
    assert_equal "string", converted[1]
    assert_equal 123, converted[2]
    assert_nil converted[3]
  end

  # Test permitted? alias
  def test_permitted_alias
    params = StrongParameters::Core::Parameters.new(name: "John")
    refute params.permitted?
    params.permit!
    assert params.permitted?
  end

  # Test permitted scalar types edge cases
  def test_permitted_scalar_with_range
    params = StrongParameters::Core::Parameters.new
    refute params.send(:permitted_scalar?, 1..10)
  end

  def test_permitted_scalar_with_rational
    params = StrongParameters::Core::Parameters.new
    assert params.send(:permitted_scalar?, Rational(1, 2))
  end

  def test_permitted_scalar_with_complex
    params = StrongParameters::Core::Parameters.new
    assert params.send(:permitted_scalar?, Complex(1, 2))
  end

  # Test multi-parameter attributes with different suffixes
  def test_permit_multi_parameter_with_f_suffix
    params = StrongParameters::Core::Parameters.new(
      "price(1f)" => "123.45",
      "price(2f)" => "0.99"
    )
    permitted = params.permit(:price)
    assert_equal "123.45", permitted["price(1f)"]
    assert_equal "0.99", permitted["price(2f)"]
  end

  def test_permit_multi_parameter_with_i_suffix
    params = StrongParameters::Core::Parameters.new(
      "date(1i)" => "2023",
      "date(2i)" => "12",
      "date(3i)" => "25"
    )
    permitted = params.permit(:date)
    assert_equal "2023", permitted["date(1i)"]
    assert_equal "12", permitted["date(2i)"]
    assert_equal "25", permitted["date(3i)"]
  end

  # Test empty and edge case values
  def test_empty_string_key
    params = StrongParameters::Core::Parameters.new("" => "value")
    assert_equal "value", params[""]
  end

  def test_whitespace_key
    params = StrongParameters::Core::Parameters.new("  " => "value")
    assert_equal "value", params["  "]
  end

  # Test fetch with KeyError handling
  def test_fetch_raises_parameter_missing_on_key_error
    params = StrongParameters::Core::Parameters.new(name: "John")
    error = assert_raises(StrongParameters::Core::ParameterMissing) do
      params.fetch(:nonexistent)
    end
    assert_equal "nonexistent", error.param
  end

  # Test array_of_permitted_scalars? edge cases
  def test_array_of_permitted_scalars_with_empty_array
    params = StrongParameters::Core::Parameters.new
    assert params.send(:array_of_permitted_scalars?, [])
  end

  def test_array_of_permitted_scalars_with_single_element
    params = StrongParameters::Core::Parameters.new
    assert params.send(:array_of_permitted_scalars?, ["string"])
    assert params.send(:array_of_permitted_scalars?, [123])
  end

  def test_array_of_permitted_scalars_with_nested_array
    params = StrongParameters::Core::Parameters.new
    refute params.send(:array_of_permitted_scalars?, [["nested"]])
  end

  # Test slice and except with edge cases
  def test_slice_with_all_keys
    params = StrongParameters::Core::Parameters.new(name: "John", age: 30, email: "john@example.com")
    sliced = params.slice(*params.keys)
    assert_equal params.to_h, sliced.to_h
  end

  def test_except_with_nonexistent_keys
    params = StrongParameters::Core::Parameters.new(name: "John", age: 30)
    excepted = params.except(:nonexistent, :also_nonexistent)
    assert_equal params.to_h, excepted.to_h
  end

  # Test to_h with special values
  def test_to_h_with_infinity
    params = StrongParameters::Core::Parameters.new(value: Float::INFINITY)
    hash = params.to_h
    assert_equal Float::INFINITY, hash["value"]
  end

  def test_to_h_with_nan
    params = StrongParameters::Core::Parameters.new(value: Float::NAN)
    hash = params.to_h
    assert hash["value"].nan?
  end

  # Test Parameters initialization with special characters in keys
  def test_initialization_with_special_character_keys
    params = StrongParameters::Core::Parameters.new(
      "key-with-dash" => "value1",
      "key.with.dot" => "value2",
      "key[with][brackets]" => "value3"
    )
    assert_equal "value1", params["key-with-dash"]
    assert_equal "value2", params["key.with.dot"]
    assert_equal "value3", params["key[with][brackets]"]
  end

  # Test permit with controller and action keys (never unpermitted)
  def test_permit_ignores_controller_and_action_in_unpermitted_check
    StrongParameters::Core::Parameters.action_on_unpermitted_parameters = :raise

    params = StrongParameters::Core::Parameters.new(
      name: "John",
      controller: "users",
      action: "create"
    )

    # Should not raise because controller/action are never considered unpermitted
    permitted = params.permit(:name)
    assert_equal "John", permitted[:name]
  ensure
    StrongParameters::Core::Parameters.action_on_unpermitted_parameters = nil
  end

  # Test required_key tracking through nested operations
  def test_required_key_persists_through_operations
    params = StrongParameters::Core::Parameters.new(
      user: {name: "John", email: "john@example.com"}
    )
    user_params = params.require(:user)
    sliced = user_params.slice(:name)
    assert_equal :user, sliced.required_key

    duped = user_params.dup
    assert_equal :user, duped.required_key

    excepted = user_params.except(:email)
    assert_equal :user, excepted.required_key
  end

  # Test unpermitted_keys calculation
  def test_unpermitted_keys_with_empty_params
    params = StrongParameters::Core::Parameters.new
    permitted_params = StrongParameters::Core::Parameters.new
    unpermitted = params.send(:unpermitted_keys, permitted_params)
    assert_equal [], unpermitted
  end

  def test_unpermitted_keys_with_all_permitted
    params = StrongParameters::Core::Parameters.new(name: "John", age: 30)
    permitted_params = StrongParameters::Core::Parameters.new(name: "John", age: 30)
    unpermitted = params.send(:unpermitted_keys, permitted_params)
    assert_equal [], unpermitted
  end

  # Test Parameters as subclass of Hash
  def test_parameters_is_hash_subclass
    params = StrongParameters::Core::Parameters.new(name: "John")
    assert params.is_a?(Hash)
  end

  def test_parameters_responds_to_hash_methods
    params = StrongParameters::Core::Parameters.new(name: "John", age: 30)
    assert_respond_to params, :each
    assert_respond_to params, :map
    assert_respond_to params, :select
    assert_respond_to params, :reject
  end

  # Test each_pair with blocks
  def test_each_pair_iterates_over_parameters
    params = StrongParameters::Core::Parameters.new(name: "John", age: 30)
    result = {}
    params.each_pair do |key, value|
      result[key] = value
    end
    assert_equal({"name" => "John", "age" => 30}, result)
  end

  # Test permit! with already permitted params
  def test_permit_bang_on_already_permitted
    params = StrongParameters::Core::Parameters.new(name: "John")
    params.permit!
    assert params.permitted?

    # Call permit! again
    params.permit!
    assert params.permitted?
  end

  # Test values method
  def test_values_returns_all_values
    params = StrongParameters::Core::Parameters.new(name: "John", age: 30, active: true)
    values = params.values
    assert_equal 3, values.length
    assert_includes values, "John"
    assert_includes values, 30
    assert_includes values, true
  end

  # Test keys method
  def test_keys_returns_all_keys
    params = StrongParameters::Core::Parameters.new(name: "John", age: 30)
    keys = params.keys
    assert_equal 2, keys.length
    assert_includes keys, "name"
    assert_includes keys, "age"
  end

  # Test empty? and size
  def test_empty_and_size
    empty_params = StrongParameters::Core::Parameters.new
    assert empty_params.empty?
    assert_equal 0, empty_params.size

    params = StrongParameters::Core::Parameters.new(name: "John")
    refute params.empty?
    assert_equal 1, params.size
  end

  # Test dig method (if available in Ruby version)
  def test_dig_with_nested_parameters
    params = StrongParameters::Core::Parameters.new(
      user: {
        profile: {
          name: "John"
        }
      }
    )
    if params.respond_to?(:dig)
      # Need to access nested params to convert hashes to Parameters first
      _ = params[:user][:profile]
      assert_equal "John", params.dig("user", "profile", "name")
      assert_nil params.dig("user", "nonexistent", "name")
    end
  end

  # Test transform_params with empty hash result
  def test_transform_params_with_transformation_returning_empty_hash
    params_class = Class.new(StrongParameters::Core::ApplicationParams) do
      allow :name

      def self.apply_transformations(params, options)
        {}
      end
    end

    params = StrongParameters::Core::Parameters.new(user: {name: "John"})
    user_params = params.require(:user)
    permitted = user_params.transform_params(params_class)

    assert_equal({}, permitted.to_h)
    assert permitted.permitted?
  end

  # Test convert_hashes_to_parameters behavior
  def test_convert_hashes_to_parameters_with_nested_structures
    params = StrongParameters::Core::Parameters.new
    nested = {
      level1: {
        level2: {
          level3: "value"
        }
      }
    }
    converted = params.send(:convert_hashes_to_parameters, :test, nested)
    assert converted[:level1].is_a?(StrongParameters::Core::Parameters)
    assert converted[:level1][:level2].is_a?(StrongParameters::Core::Parameters)
    assert_equal "value", converted[:level1][:level2][:level3]
  end
end
