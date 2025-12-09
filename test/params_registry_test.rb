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
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup(:https_connection)
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
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup(:user2_fa)
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
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup(:xmlhttp_request)
  end

  def test_registered_models_returns_all_models
    ActionController::ParamsRegistry.register("User", @user_params_class)
    ActionController::ParamsRegistry.register("Account", @account_params_class)

    models = ActionController::ParamsRegistry.registered_models
    assert_equal 2, models.length
    assert_includes models, "user"
    assert_includes models, "account"
  end

  def test_register_with_invalid_model_name
    # Should handle nil gracefully
    result = ActionController::ParamsRegistry.register(nil, @user_params_class)
    assert_equal @user_params_class, result  # register returns the params_class
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup(nil)
  end

  def test_lookup_with_invalid_model_name
    # Should handle nil gracefully
    assert_nil ActionController::ParamsRegistry.lookup(nil)
  end

  def test_registered_with_invalid_model_name
    # Should handle nil gracefully
    refute ActionController::ParamsRegistry.registered?(nil)
  end

  def test_permitted_attributes_for_with_invalid_model_name
    # Should handle nil gracefully
    assert_equal [], ActionController::ParamsRegistry.permitted_attributes_for(nil)
  end

  def test_normalize_key_with_empty_string
    ActionController::ParamsRegistry.register("", @user_params_class)
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup("")
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup(:"")
  end

  def test_normalize_key_with_special_characters
    ActionController::ParamsRegistry.register("User-Profile", @user_params_class)
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup(:user_profile)
  end

  def test_normalize_key_with_unicode
    ActionController::ParamsRegistry.register("Usér", @user_params_class)
    assert_equal @user_params_class, ActionController::ParamsRegistry.lookup(:usér)
  end

  def test_registry_is_singleton
    registry1 = ActionController::ParamsRegistry.send(:registry)
    registry2 = ActionController::ParamsRegistry.send(:registry)
    assert_same registry1, registry2
  end

  def test_clear_returns_empty_hash
    ActionController::ParamsRegistry.register("User", @user_params_class)
    result = ActionController::ParamsRegistry.clear!
    assert_empty result
    assert_same ActionController::ParamsRegistry.send(:registry), result
  end

  def test_permitted_attributes_for_with_broken_params_class
    broken_class = Class.new do
      def self.permitted_attributes(action: nil)
        raise "Broken"
      end
    end

    ActionController::ParamsRegistry.register("Broken", broken_class)
    assert_raises(RuntimeError) do
      ActionController::ParamsRegistry.permitted_attributes_for("Broken")
    end
  end

  def test_permitted_attributes_for_with_nil_params_class
    ActionController::ParamsRegistry.register("NilClass", nil)
    assert_equal [], ActionController::ParamsRegistry.permitted_attributes_for("NilClass")
  end

  def test_registered_models_returns_sorted_strings
    ActionController::ParamsRegistry.register("Zebra", @user_params_class)
    ActionController::ParamsRegistry.register("Apple", @account_params_class)

    models = ActionController::ParamsRegistry.registered_models
    assert_equal ["apple", "zebra"], models.sort
  end

  def test_register_with_frozen_strings
    frozen_name = "FrozenUser".freeze
    ActionController::ParamsRegistry.register(frozen_name, @user_params_class)
    assert ActionController::ParamsRegistry.registered?(frozen_name)
  end

  def test_normalize_key_with_frozen_symbol
    frozen_symbol = :frozen_user
    ActionController::ParamsRegistry.register(frozen_symbol, @user_params_class)
    assert ActionController::ParamsRegistry.registered?(frozen_symbol)
  end

  def test_large_registry_performance
    # Test with many registrations
    100.times do |i|
      params_class = Class.new(ActionController::ApplicationParams) do
        define_singleton_method(:name) { "Model#{i}Params" }
        allow :field
      end
      ActionController::ParamsRegistry.register("Model#{i}", params_class)
    end

    assert_equal 100, ActionController::ParamsRegistry.registered_models.length

    # Lookup should still work
    assert ActionController::ParamsRegistry.registered?("Model50")
    refute_nil ActionController::ParamsRegistry.lookup("Model50")
  end

  def test_register_overwrites_with_different_types
    first_class = Class.new(ActionController::ApplicationParams)
    second_class = Class.new(ActionController::ApplicationParams)

    ActionController::ParamsRegistry.register(:user, first_class)
    assert_equal first_class, ActionController::ParamsRegistry.lookup(:user)

    ActionController::ParamsRegistry.register("user", second_class)
    assert_equal second_class, ActionController::ParamsRegistry.lookup(:user)
  end

  def test_permitted_attributes_for_with_action_symbol_and_string
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :field1, only: :create
      allow :field2
    end

    ActionController::ParamsRegistry.register("Test", test_class)

    # Symbol action
    attrs = ActionController::ParamsRegistry.permitted_attributes_for("Test", action: :create)
    assert_includes attrs, :field1
    assert_includes attrs, :field2

    # String action
    attrs = ActionController::ParamsRegistry.permitted_attributes_for("Test", action: "create")
    assert_includes attrs, :field1
    assert_includes attrs, :field2

    # Update action
    attrs = ActionController::ParamsRegistry.permitted_attributes_for("Test", action: :update)
    refute_includes attrs, :field1
    assert_includes attrs, :field2
  end

  def test_normalize_key_consistency
    # Ensure normalize_registry_key is consistent
    key1 = ActionController::ParamsRegistry.send(:normalize_registry_key, "TestModel")
    key2 = ActionController::ParamsRegistry.send(:normalize_registry_key, :TestModel)
    key3 = ActionController::ParamsRegistry.send(:normalize_registry_key, "test_model")

    assert_equal key1, key2
    assert_equal key1, key3
  end
end
