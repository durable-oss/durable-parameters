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

  def test_registered_models_returns_all_model_names
    ActionController::ParamsRegistry.register("User", @user_params_class)
    ActionController::ParamsRegistry.register("Account", @account_params_class)

    models = ActionController::ParamsRegistry.registered_models
    assert_includes models, "user"
    assert_includes models, "account"
    assert_equal 2, models.length
  end

  def test_registered_models_returns_empty_array_when_empty
    assert_equal [], ActionController::ParamsRegistry.registered_models
  end

  def test_normalize_key_with_camel_case
    ActionController::ParamsRegistry.register("BlogPost", @user_params_class)
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup(:blog_post)
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup("blog_post")
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup("BlogPost")
  end

  def test_normalize_key_with_multiple_capitals
    ActionController::ParamsRegistry.register("HTTPSConnection", @user_params_class)
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup(:h_t_t_p_s_connection)
  end

  def test_normalize_key_with_single_letter
    ActionController::ParamsRegistry.register("A", @user_params_class)
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup(:a)
  end

  def test_normalize_key_with_all_lowercase
    ActionController::ParamsRegistry.register("user", @user_params_class)
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup(:user)
  end

  def test_normalize_key_with_underscores
    ActionController::ParamsRegistry.register("user_profile", @user_params_class)
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup(:user_profile)
  end

  def test_normalize_key_with_numbers
    ActionController::ParamsRegistry.register("User2FA", @user_params_class)
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup(:user2_f_a)
  end

  def test_register_overwrites_existing_registration
    first_class = Class.new(ActionController::ApplicationParams)
    second_class = Class.new(ActionController::ApplicationParams)

    ActionController::ParamsRegistry.register("User", first_class)
    assert_equal first_class, ActionController::ParamsRegistry.lookup(:user)

    ActionController::ParamsRegistry.register("User", second_class)
    assert_equal second_class, ActionController::ParamsRegistry.lookup(:user)
  end

  def test_registered_with_various_input_types
    ActionController::ParamsRegistry.register("User", @user_params_class)

    assert ActionController::ParamsRegistry.registered?("User")
    assert ActionController::ParamsRegistry.registered?("user")
    assert ActionController::ParamsRegistry.registered?(:User)
    assert ActionController::ParamsRegistry.registered?(:user)
  end

  def test_lookup_with_nil_returns_nil
    assert_nil ActionController::ParamsRegistry.lookup(nil)
  end

  def test_registered_with_nil_returns_false
    refute ActionController::ParamsRegistry.registered?(nil)
  end

  def test_register_returns_params_class
    result = ActionController::ParamsRegistry.register("User", @user_params_class)
    assert_equal @user_params_class, result
  end

  def test_clear_returns_empty_hash
    ActionController::ParamsRegistry.register("User", @user_params_class)
    result = ActionController::ParamsRegistry.clear!
    assert_empty result
  end

  def test_registered_models_returns_strings
    ActionController::ParamsRegistry.register(:user, @user_params_class)
    models = ActionController::ParamsRegistry.registered_models
    assert models.all? { |m| m.is_a?(String) }
  end

  def test_multiple_registrations_independently_stored
    user_class = Class.new(ActionController::ApplicationParams) do
      allow :name
    end
    account_class = Class.new(ActionController::ApplicationParams) do
      allow :email
    end

    ActionController::ParamsRegistry.register("User", user_class)
    ActionController::ParamsRegistry.register("Account", account_class)

    assert_equal [:name], ActionController::ParamsRegistry.permitted_attributes_for("User")
    assert_equal [:email], ActionController::ParamsRegistry.permitted_attributes_for("Account")
  end

  def test_normalize_key_preserves_underscores
    # Test that existing underscores are preserved
    ActionController::ParamsRegistry.register("user_profile_settings", @user_params_class)
    assert ActionController::ParamsRegistry.registered?("user_profile_settings")
    assert ActionController::ParamsRegistry.registered?(:user_profile_settings)
  end

  def test_normalize_key_with_acronyms
    ActionController::ParamsRegistry.register("XMLHTTPRequest", @user_params_class)
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup(:x_m_l_h_t_t_p_request)
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
