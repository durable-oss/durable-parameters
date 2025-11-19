require "test_helper"

class TransformParamsEdgeCasesTest < Minitest::Test
  def setup
    ActionController::ParamsRegistry.clear!

    @user_params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "UserParams"
      end

      allow :name
      allow :email
      allow :status, only: [:create, :update]
      allow :role, except: :destroy
      metadata :ip_address
    end

    ActionController::ParamsRegistry.register("User", @user_params_class)
  end

  def teardown
    ActionController::ParamsRegistry.clear!
  end

  # Test without require
  def test_transform_params_without_require_returns_empty
    params = ActionController::Parameters.new(
      name: "John",
      email: "john@example.com"
    )

    # Without require, no required_key is set
    permitted = params.transform_params

    assert permitted.permitted?
    assert_nil permitted[:name]
    assert_nil permitted[:email]
  end

  # Test with require but no registration
  def test_transform_params_with_unregistered_model_returns_empty
    params = ActionController::Parameters.new(
      unregistered: {
        name: "Test",
        value: 123
      }
    )

    permitted = params.require(:unregistered).transform_params

    assert permitted.permitted?
    assert_nil permitted[:name]
    assert_nil permitted[:value]
  end

  # Test explicit nil params class
  def test_transform_params_with_explicit_nil_class_returns_empty
    params = ActionController::Parameters.new(
      user: {
        name: "Test",
        email: "test@example.com"
      }
    )

    permitted = params.require(:user).transform_params(nil)

    assert permitted.permitted?
    assert_nil permitted[:name]
    assert_nil permitted[:email]
  end

  # Test empty parameters
  def test_transform_params_with_empty_hash
    params = ActionController::Parameters.new(
      user: {}
    )

    # Don't use require for empty hash - it would raise ParameterMissing
    # Instead, access directly and set the required_key manually
    user_params = params[:user]
    user_params.required_key = :user

    permitted = user_params.transform_params

    assert permitted.permitted?
    assert_equal({}, permitted.to_h)
  end

  # Test with nil values
  def test_transform_params_preserves_nil_values
    params = ActionController::Parameters.new(
      user: {
        name: nil,
        email: "test@example.com"
      }
    )

    permitted = params.require(:user).transform_params

    assert_nil permitted[:name]
    assert_equal "test@example.com", permitted[:email]
  end

  # Test with empty string values
  def test_transform_params_preserves_empty_strings
    params = ActionController::Parameters.new(
      user: {
        name: "",
        email: "test@example.com"
      }
    )

    permitted = params.require(:user).transform_params

    assert_equal "", permitted[:name]
    assert_equal "test@example.com", permitted[:email]
  end

  # Test with numeric values
  def test_transform_params_with_numeric_values
    test_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "ProductParams"
      end
      allow :price
      allow :quantity
    end

    ActionController::ParamsRegistry.register("Product", test_class)

    params = ActionController::Parameters.new(
      product: {
        price: 19.99,
        quantity: 5
      }
    )

    permitted = params.require(:product).transform_params

    assert_equal 19.99, permitted[:price]
    assert_equal 5, permitted[:quantity]
  end

  # Test with boolean values
  def test_transform_params_with_boolean_values
    test_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "SettingsParams"
      end
      allow :enabled
      allow :public
    end

    ActionController::ParamsRegistry.register("Settings", test_class)

    params = ActionController::Parameters.new(
      settings: {
        enabled: true,
        public: false
      }
    )

    permitted = params.require(:settings).transform_params

    assert_equal true, permitted[:enabled]
    assert_equal false, permitted[:public]
  end

  # Test with special characters in values
  def test_transform_params_with_special_characters
    params = ActionController::Parameters.new(
      user: {
        name: "O'Brien",
        email: "test+spam@example.com"
      }
    )

    permitted = params.require(:user).transform_params

    assert_equal "O'Brien", permitted[:name]
    assert_equal "test+spam@example.com", permitted[:email]
  end

  # Test with unicode characters
  def test_transform_params_with_unicode_characters
    params = ActionController::Parameters.new(
      user: {
        name: "日本語",
        email: "test@example.com"
      }
    )

    permitted = params.require(:user).transform_params

    assert_equal "日本語", permitted[:name]
    assert_equal "test@example.com", permitted[:email]
  end

  # Test action filter with string action
  def test_transform_params_with_string_action
    params = ActionController::Parameters.new(
      user: {
        name: "Test",
        status: "active"
      }
    )

    permitted = params.require(:user).transform_params(action: "create")

    assert_equal "Test", permitted[:name]
    assert_equal "active", permitted[:status]
  end

  # Test action filter with non-existent action
  def test_transform_params_with_non_matching_action
    params = ActionController::Parameters.new(
      user: {
        name: "Test",
        status: "active",
        role: "admin"
      }
    )

    permitted = params.require(:user).transform_params(action: :show)

    assert_equal "Test", permitted[:name]
    assert_nil permitted[:status]  # only allowed for create/update
    assert_equal "admin", permitted[:role]  # allowed except for destroy
  end

  # Test additional_attrs with empty array
  def test_transform_params_with_empty_additional_attrs
    params = ActionController::Parameters.new(
      user: {
        name: "Test",
        email: "test@example.com"
      }
    )

    permitted = params.require(:user).transform_params(additional_attrs: [])

    assert_equal "Test", permitted[:name]
    assert_equal "test@example.com", permitted[:email]
  end

  # Test additional_attrs with non-existent attributes
  def test_transform_params_additional_attrs_non_existent
    params = ActionController::Parameters.new(
      user: {
        name: "Test",
        email: "test@example.com"
      }
    )

    permitted = params.require(:user).transform_params(additional_attrs: [:non_existent])

    assert_equal "Test", permitted[:name]
    assert_equal "test@example.com", permitted[:email]
    assert_nil permitted[:non_existent]
  end

  # Test additional_attrs with string keys
  def test_transform_params_additional_attrs_with_strings
    params = ActionController::Parameters.new(
      user: {
        name: "Test",
        email: "test@example.com",
        age: 30
      }
    )

    permitted = params.require(:user).transform_params(additional_attrs: ["age"])

    assert_equal "Test", permitted[:name]
    assert_equal "test@example.com", permitted[:email]
    assert_equal 30, permitted[:age]
  end

  # Test combining action and additional_attrs
  def test_transform_params_with_action_and_additional_attrs
    params = ActionController::Parameters.new(
      user: {
        name: "Test",
        email: "test@example.com",
        status: "active",
        age: 30
      }
    )

    permitted = params.require(:user).transform_params(
      action: :create,
      additional_attrs: [:age]
    )

    assert_equal "Test", permitted[:name]
    assert_equal "test@example.com", permitted[:email]
    assert_equal "active", permitted[:status]
    assert_equal 30, permitted[:age]
  end

  # Test combining all options
  def test_transform_params_with_all_options
    params = ActionController::Parameters.new(
      user: {
        name: "Test",
        email: "test@example.com",
        status: "active",
        age: 30
      }
    )

    permitted = params.require(:user).transform_params(
      action: :create,
      additional_attrs: [:age],
      current_user: Object.new,
      ip_address: "127.0.0.1"
    )

    assert_equal "Test", permitted[:name]
    assert_equal "test@example.com", permitted[:email]
    assert_equal "active", permitted[:status]
    assert_equal 30, permitted[:age]
  end

  # Test required_key is preserved through chaining
  def test_required_key_preserved_after_require
    params = ActionController::Parameters.new(
      user: {
        name: "Test"
      }
    )

    user_params = params.require(:user)
    assert_equal :user, user_params.required_key
  end

  # Test explicit params class overrides registry lookup
  def test_explicit_params_class_overrides_registry
    other_params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "OtherParams"
      end
      allow :different_field
    end

    params = ActionController::Parameters.new(
      user: {
        name: "Test",
        email: "test@example.com",
        different_field: "value"
      }
    )

    # Even though 'user' is registered, explicit class should be used
    permitted = params.require(:user).transform_params(other_params_class)

    assert_nil permitted[:name]
    assert_nil permitted[:email]
    assert_equal "value", permitted[:different_field]
  end

  # Test with array values
  def test_transform_params_does_not_permit_arrays_without_explicit_declaration
    params = ActionController::Parameters.new(
      user: {
        name: "Test",
        tags: ["tag1", "tag2"]
      }
    )

    permitted = params.require(:user).transform_params

    assert_equal "Test", permitted[:name]
    assert_nil permitted[:tags]  # Arrays not permitted by default
  end

  # Test with hash values
  def test_transform_params_does_not_permit_nested_hashes_without_explicit_declaration
    params = ActionController::Parameters.new(
      user: {
        name: "Test",
        address: {
          street: "123 Main St",
          city: "NYC"
        }
      }
    )

    permitted = params.require(:user).transform_params

    assert_equal "Test", permitted[:name]
    assert_nil permitted[:address]  # Nested hashes not permitted by default
  end

  # Test metadata validation with explicit params class
  def test_metadata_validation_with_explicit_params_class
    other_params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "OtherParams"
      end
      allow :field
      # No metadata declared
    end

    params = ActionController::Parameters.new(
      user: {field: "value"}
    )

    # Should validate against explicit class, not registry
    error = assert_raises(ArgumentError) do
      params.require(:user).transform_params(
        other_params_class,
        ip_address: "127.0.0.1"
      )
    end

    assert_includes error.message, "OtherParams"
    assert_includes error.message, "ip_address"
  end

  # Test case sensitivity
  def test_transform_params_attribute_names_case_sensitive
    test_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "CaseParams"
      end
      allow :Name  # capital N
    end

    ActionController::ParamsRegistry.register("Case", test_class)

    params = ActionController::Parameters.new(
      case: {
        name: "lowercase",  # lowercase n
        Name: "capitalized"
      }
    )

    permitted = params.require(:case).transform_params

    # Should only permit the exact case match
    assert_equal "capitalized", permitted[:Name]
    assert_nil permitted[:name]
  end

  # Test with Date/Time objects
  def test_transform_params_with_date_time_objects
    test_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "EventParams"
      end
      allow :scheduled_at
      allow :date
    end

    ActionController::ParamsRegistry.register("Event", test_class)

    now = Time.now
    today = Date.today

    params = ActionController::Parameters.new(
      event: {
        scheduled_at: now,
        date: today
      }
    )

    permitted = params.require(:event).transform_params

    assert_equal now, permitted[:scheduled_at]
    assert_equal today, permitted[:date]
  end

  # Test duplicate additional_attrs
  def test_transform_params_with_duplicate_additional_attrs
    params = ActionController::Parameters.new(
      user: {
        name: "Test",
        age: 30
      }
    )

    # name is already allowed, age is additional
    permitted = params.require(:user).transform_params(
      additional_attrs: [:name, :age, :name]
    )

    assert_equal "Test", permitted[:name]
    assert_equal 30, permitted[:age]
  end

  # Test that transform_params returns a new Parameters instance
  def test_transform_params_returns_new_instance
    params = ActionController::Parameters.new(
      user: {
        name: "Test",
        email: "test@example.com"
      }
    )

    user_params = params.require(:user)
    permitted = user_params.transform_params

    refute_equal user_params.object_id, permitted.object_id
  end

  # Test that original params are not modified
  def test_transform_params_does_not_modify_original
    params = ActionController::Parameters.new(
      user: {
        name: "Test",
        email: "test@example.com",
        admin: true
      }
    )

    user_params = params.require(:user)
    permitted = user_params.transform_params

    # Original should still have all keys
    assert user_params.key?(:admin)
    # Permitted should not
    assert !permitted.key?(:admin)
  end
end
