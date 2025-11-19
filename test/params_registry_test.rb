require "test_helper"

class ParamsRegistryTest < Minitest::Test
  def setup
    ActionController::ParamsRegistry.clear!

    @user_params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "UserParams"
      end

      allow :first_name
      allow :last_name
      allow :email
    end

    @account_params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "AccountParams"
      end

      allow :name
      allow :description
    end
  end

  def teardown
    ActionController::ParamsRegistry.clear!
  end

  def test_register_stores_params_class
    ActionController::ParamsRegistry.register("User", @user_params_class)
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup("User")
  end

  def test_register_normalizes_model_name
    ActionController::ParamsRegistry.register("User", @user_params_class)

    # Should work with different capitalizations and formats
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup(:user)
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup("user")
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup("User")
  end

  def test_lookup_returns_nil_for_unregistered_model
    assert_nil ActionController::ParamsRegistry.lookup("NonexistentModel")
  end

  def test_registered_returns_true_for_registered_model
    ActionController::ParamsRegistry.register("User", @user_params_class)
    assert ActionController::ParamsRegistry.registered?("User")
    assert ActionController::ParamsRegistry.registered?(:user)
  end

  def test_registered_returns_false_for_unregistered_model
    assert !ActionController::ParamsRegistry.registered?("NonexistentModel")
  end

  def test_permitted_attributes_for_returns_attributes
    ActionController::ParamsRegistry.register("User", @user_params_class)

    attrs = ActionController::ParamsRegistry.permitted_attributes_for("User")
    assert_equal [:first_name, :last_name, :email], attrs
  end

  def test_permitted_attributes_for_returns_empty_for_unregistered
    attrs = ActionController::ParamsRegistry.permitted_attributes_for("NonexistentModel")
    assert_equal [], attrs
  end

  def test_permitted_attributes_for_with_action
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :field1, only: :create
      allow :field2
    end

    ActionController::ParamsRegistry.register("Test", test_class)

    # With action: :create, should include both fields
    attrs = ActionController::ParamsRegistry.permitted_attributes_for("Test", action: :create)
    assert_includes attrs, :field1
    assert_includes attrs, :field2

    # With action: :update, should only include field2
    attrs = ActionController::ParamsRegistry.permitted_attributes_for("Test", action: :update)
    refute_includes attrs, :field1
    assert_includes attrs, :field2
  end

  def test_clear_removes_all_registrations
    ActionController::ParamsRegistry.register("User", @user_params_class)
    ActionController::ParamsRegistry.register("Account", @account_params_class)

    assert ActionController::ParamsRegistry.registered?("User")
    assert ActionController::ParamsRegistry.registered?("Account")

    ActionController::ParamsRegistry.clear!

    assert !ActionController::ParamsRegistry.registered?("User")
    assert !ActionController::ParamsRegistry.registered?("Account")
  end

  def test_registered_models_returns_all_models
    ActionController::ParamsRegistry.register("User", @user_params_class)
    ActionController::ParamsRegistry.register("Account", @account_params_class)

    models = ActionController::ParamsRegistry.registered_models
    assert_equal 2, models.length
    assert_includes models, "user"
    assert_includes models, "account"
  end
end
