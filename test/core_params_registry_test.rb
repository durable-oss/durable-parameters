require "test_helper"

class CoreParamsRegistryTest < Minitest::Test
  def setup
    StrongParameters::Core::ParamsRegistry.clear!

    @user_params_class = Class.new(StrongParameters::Core::ApplicationParams) do
      def self.name
        "UserParams"
      end

      allow :first_name
      allow :last_name
      allow :email
    end

    @account_params_class = Class.new(StrongParameters::Core::ApplicationParams) do
      def self.name
        "AccountParams"
      end

      allow :name
      allow :description
    end
  end

  def teardown
    StrongParameters::Core::ParamsRegistry.clear!
  end

  def test_register_stores_params_class
    StrongParameters::Core::ParamsRegistry.register("User", @user_params_class)
    assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup("User")
  end

  def test_register_normalizes_model_name
    StrongParameters::Core::ParamsRegistry.register("User", @user_params_class)

    # Should work with different capitalizations and formats
    assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup(:user)
    assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup("user")
    assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup("User")
  end

  def test_lookup_returns_nil_for_unregistered_model
    assert_nil StrongParameters::Core::ParamsRegistry.lookup("NonexistentModel")
  end

  def test_registered_returns_true_for_registered_model
    StrongParameters::Core::ParamsRegistry.register("User", @user_params_class)
    assert StrongParameters::Core::ParamsRegistry.registered?("User")
    assert StrongParameters::Core::ParamsRegistry.registered?(:user)
  end

  def test_registered_returns_false_for_unregistered_model
    assert !StrongParameters::Core::ParamsRegistry.registered?("NonexistentModel")
  end

  def test_permitted_attributes_for_returns_attributes
    StrongParameters::Core::ParamsRegistry.register("User", @user_params_class)

    attrs = StrongParameters::Core::ParamsRegistry.permitted_attributes_for("User")
    assert_equal [:first_name, :last_name, :email], attrs
  end

  def test_permitted_attributes_for_returns_empty_for_unregistered
    attrs = StrongParameters::Core::ParamsRegistry.permitted_attributes_for("NonexistentModel")
    assert_equal [], attrs
  end

  def test_permitted_attributes_for_with_action
    test_class = Class.new(StrongParameters::Core::ApplicationParams) do
      allow :field1, only: :create
      allow :field2
    end

    StrongParameters::Core::ParamsRegistry.register("Test", test_class)

    # With action: :create, should include both fields
    attrs = StrongParameters::Core::ParamsRegistry.permitted_attributes_for("Test", action: :create)
    assert_includes attrs, :field1
    assert_includes attrs, :field2

    # With action: :update, should only include field2
    attrs = StrongParameters::Core::ParamsRegistry.permitted_attributes_for("Test", action: :update)
    refute_includes attrs, :field1
    assert_includes attrs, :field2
  end

  def test_clear_removes_all_registrations
    StrongParameters::Core::ParamsRegistry.register("User", @user_params_class)
    StrongParameters::Core::ParamsRegistry.register("Account", @account_params_class)

    assert StrongParameters::Core::ParamsRegistry.registered?("User")
    assert StrongParameters::Core::ParamsRegistry.registered?("Account")

    StrongParameters::Core::ParamsRegistry.clear!

    assert !StrongParameters::Core::ParamsRegistry.registered?("User")
    assert !StrongParameters::Core::ParamsRegistry.registered?("Account")
  end

  def test_registered_models_returns_all_model_names
    StrongParameters::Core::ParamsRegistry.register("User", @user_params_class)
    StrongParameters::Core::ParamsRegistry.register("Account", @account_params_class)

    models = StrongParameters::Core::ParamsRegistry.registered_models
    assert_includes models, "user"
    assert_includes models, "account"
    assert_equal 2, models.length
  end

  def test_registered_models_returns_empty_array_when_empty
    assert_equal [], StrongParameters::Core::ParamsRegistry.registered_models
  end

  def test_normalize_key_with_camel_case
    StrongParameters::Core::ParamsRegistry.register("BlogPost", @user_params_class)
    assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup(:blog_post)
    assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup("blog_post")
    assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup("BlogPost")
  end

  def test_normalize_key_with_multiple_capitals
    StrongParameters::Core::ParamsRegistry.register("HTTPSConnection", @user_params_class)
    assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup(:https_connection)
  end

  def test_normalize_key_with_single_letter
    StrongParameters::Core::ParamsRegistry.register("A", @user_params_class)
    assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup(:a)
  end

  def test_normalize_key_with_all_lowercase
    StrongParameters::Core::ParamsRegistry.register("user", @user_params_class)
    assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup(:user)
  end

  def test_normalize_key_with_underscores
    StrongParameters::Core::ParamsRegistry.register("user_profile", @user_params_class)
    assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup(:user_profile)
  end

  def test_normalize_key_with_numbers
    StrongParameters::Core::ParamsRegistry.register("User2FA", @user_params_class)
    assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup(:user2_fa)
  end

  def test_register_overwrites_existing_registration
    first_class = Class.new(StrongParameters::Core::ApplicationParams)
    second_class = Class.new(StrongParameters::Core::ApplicationParams)

    StrongParameters::Core::ParamsRegistry.register("User", first_class)
    assert_equal first_class, StrongParameters::Core::ParamsRegistry.lookup(:user)

    StrongParameters::Core::ParamsRegistry.register("User", second_class)
    assert_equal second_class, StrongParameters::Core::ParamsRegistry.lookup(:user)
  end

  def test_registered_with_various_input_types
    StrongParameters::Core::ParamsRegistry.register("User", @user_params_class)

    assert StrongParameters::Core::ParamsRegistry.registered?("User")
    assert StrongParameters::Core::ParamsRegistry.registered?("user")
    assert StrongParameters::Core::ParamsRegistry.registered?(:User)
    assert StrongParameters::Core::ParamsRegistry.registered?(:user)
  end

  def test_lookup_with_nil_returns_nil
    assert_nil StrongParameters::Core::ParamsRegistry.lookup(nil)
  end

  def test_registered_with_nil_returns_false
    refute StrongParameters::Core::ParamsRegistry.registered?(nil)
  end

  def test_register_returns_params_class
    result = StrongParameters::Core::ParamsRegistry.register("User", @user_params_class)
    assert_equal @user_params_class, result
  end

  def test_clear_returns_empty_hash
    StrongParameters::Core::ParamsRegistry.register("User", @user_params_class)
    result = StrongParameters::Core::ParamsRegistry.clear!
    assert_empty result
  end

  def test_registered_models_returns_strings
    StrongParameters::Core::ParamsRegistry.register(:user, @user_params_class)
    models = StrongParameters::Core::ParamsRegistry.registered_models
    assert models.all? { |m| m.is_a?(String) }
  end

  def test_multiple_registrations_independently_stored
    user_class = Class.new(StrongParameters::Core::ApplicationParams) do
      allow :name
    end
    account_class = Class.new(StrongParameters::Core::ApplicationParams) do
      allow :email
    end

    StrongParameters::Core::ParamsRegistry.register("User", user_class)
    StrongParameters::Core::ParamsRegistry.register("Account", account_class)

    assert_equal [:name], StrongParameters::Core::ParamsRegistry.permitted_attributes_for("User")
    assert_equal [:email], StrongParameters::Core::ParamsRegistry.permitted_attributes_for("Account")
  end

  def test_normalize_key_preserves_underscores
    # Test that existing underscores are preserved
    StrongParameters::Core::ParamsRegistry.register("user_profile_settings", @user_params_class)
    assert StrongParameters::Core::ParamsRegistry.registered?("user_profile_settings")
    assert StrongParameters::Core::ParamsRegistry.registered?(:user_profile_settings)
  end

  def test_normalize_key_with_acronyms
    StrongParameters::Core::ParamsRegistry.register("XMLHttpRequest", @user_params_class)
    assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup(:xml_http_request)
  end

  def test_registered_models_returns_all_models
    StrongParameters::Core::ParamsRegistry.register("User", @user_params_class)
    StrongParameters::Core::ParamsRegistry.register("Account", @account_params_class)

    models = StrongParameters::Core::ParamsRegistry.registered_models
    assert_equal 2, models.length
    assert_includes models, "user"
    assert_includes models, "account"
  end

  def test_register_with_invalid_model_name
    # Should handle nil gracefully
    result = StrongParameters::Core::ParamsRegistry.register(nil, @user_params_class)
    assert_equal @user_params_class, result  # register returns the params_class
    assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup(nil)
  end

  def test_lookup_with_invalid_model_name
    # Should handle nil gracefully
    assert_nil StrongParameters::Core::ParamsRegistry.lookup(nil)
  end

  def test_registered_with_invalid_model_name
    # Should handle nil gracefully
    refute StrongParameters::Core::ParamsRegistry.registered?(nil)
  end

  def test_permitted_attributes_for_with_invalid_model_name
    # Should handle nil gracefully
    assert_equal [], StrongParameters::Core::ParamsRegistry.permitted_attributes_for(nil)
  end

  def test_normalize_key_with_empty_string
    StrongParameters::Core::ParamsRegistry.register("", @user_params_class)
    assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup("")
    assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup(:"")
  end

  def test_normalize_key_with_special_characters
    StrongParameters::Core::ParamsRegistry.register("User-Profile", @user_params_class)
    assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup(:user_profile)
  end

  def test_normalize_key_with_unicode
    StrongParameters::Core::ParamsRegistry.register("Usér", @user_params_class)
    assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup(:usér)
  end

  def test_registry_is_singleton
    registry1 = StrongParameters::Core::ParamsRegistry.send(:registry)
    registry2 = StrongParameters::Core::ParamsRegistry.send(:registry)
    assert_same registry1, registry2
  end

  def test_clear_returns_empty_hash
    StrongParameters::Core::ParamsRegistry.register("User", @user_params_class)
    result = StrongParameters::Core::ParamsRegistry.clear!
    assert_empty result
    assert_same StrongParameters::Core::ParamsRegistry.send(:registry), result
  end

  def test_permitted_attributes_for_with_broken_params_class
    broken_class = Class.new do
      def self.permitted_attributes(action: nil)
        raise "Broken"
      end
    end

    StrongParameters::Core::ParamsRegistry.register("Broken", broken_class)
    assert_raises(RuntimeError) do
      StrongParameters::Core::ParamsRegistry.permitted_attributes_for("Broken")
    end
  end

  def test_permitted_attributes_for_with_nil_params_class
    StrongParameters::Core::ParamsRegistry.register("NilClass", nil)
    assert_equal [], StrongParameters::Core::ParamsRegistry.permitted_attributes_for("NilClass")
  end

  def test_registered_models_returns_sorted_strings
    StrongParameters::Core::ParamsRegistry.register("Zebra", @user_params_class)
    StrongParameters::Core::ParamsRegistry.register("Apple", @account_params_class)

    models = StrongParameters::Core::ParamsRegistry.registered_models
    assert_equal ["apple", "zebra"], models.sort
  end

  def test_register_with_frozen_strings
    frozen_name = "FrozenUser".freeze
    StrongParameters::Core::ParamsRegistry.register(frozen_name, @user_params_class)
    assert StrongParameters::Core::ParamsRegistry.registered?(frozen_name)
  end

  def test_normalize_key_with_frozen_symbol
    frozen_symbol = :frozen_user
    StrongParameters::Core::ParamsRegistry.register(frozen_symbol, @user_params_class)
    assert StrongParameters::Core::ParamsRegistry.registered?(frozen_symbol)
  end

  def test_large_registry_performance
    # Test with many registrations
    100.times do |i|
      params_class = Class.new(StrongParameters::Core::ApplicationParams) do
        define_singleton_method(:name) { "Model#{i}Params" }
        allow :field
      end
      StrongParameters::Core::ParamsRegistry.register("Model#{i}", params_class)
    end

    assert_equal 100, StrongParameters::Core::ParamsRegistry.registered_models.length

    # Lookup should still work
    assert StrongParameters::Core::ParamsRegistry.registered?("Model50")
    refute_nil StrongParameters::Core::ParamsRegistry.lookup("Model50")
  end

  def test_register_overwrites_with_different_types
    first_class = Class.new(StrongParameters::Core::ApplicationParams)
    second_class = Class.new(StrongParameters::Core::ApplicationParams)

    StrongParameters::Core::ParamsRegistry.register(:user, first_class)
    assert_equal first_class, StrongParameters::Core::ParamsRegistry.lookup(:user)

    StrongParameters::Core::ParamsRegistry.register("user", second_class)
    assert_equal second_class, StrongParameters::Core::ParamsRegistry.lookup(:user)
  end

  def test_permitted_attributes_for_with_action_symbol_and_string
    test_class = Class.new(StrongParameters::Core::ApplicationParams) do
      allow :field1, only: :create
      allow :field2
    end

    StrongParameters::Core::ParamsRegistry.register("Test", test_class)

    # Symbol action
    attrs = StrongParameters::Core::ParamsRegistry.permitted_attributes_for("Test", action: :create)
    assert_includes attrs, :field1
    assert_includes attrs, :field2

    # String action
    attrs = StrongParameters::Core::ParamsRegistry.permitted_attributes_for("Test", action: "create")
    assert_includes attrs, :field1
    assert_includes attrs, :field2

    # Update action
    attrs = StrongParameters::Core::ParamsRegistry.permitted_attributes_for("Test", action: :update)
    refute_includes attrs, :field1
    assert_includes attrs, :field2
  end

  def test_normalize_key_consistency
    # Ensure normalize_key is consistent
    key1 = StrongParameters::Core::ParamsRegistry.send(:normalize_key, "TestModel")
    key2 = StrongParameters::Core::ParamsRegistry.send(:normalize_key, :TestModel)
    key3 = StrongParameters::Core::ParamsRegistry.send(:normalize_key, "test_model")

    assert_equal key1, key2
    assert_equal key1, key3
  end

  # Test the fallback normalize_key when underscore is not available
  def test_normalize_key_fallback
    # Stub respond_to? to return false to test fallback
    original_respond_to = String.instance_method(:respond_to?)
    String.define_singleton_method(:respond_to?) do |method_name|
      if method_name == :underscore
        false
      else
        original_respond_to.bind(String).call(method_name)
      end
    end

    begin
      # Test fallback with camelCase
      StrongParameters::Core::ParamsRegistry.register("BlogPost", @user_params_class)
      assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup(:blog_post)

      # Test fallback with acronyms
      StrongParameters::Core::ParamsRegistry.register("XMLHttpRequest", @account_params_class)
      assert_equal @account_params_class, StrongParameters::Core::ParamsRegistry.lookup(:xml_http_request)

      # Test fallback with multiple capitals
      StrongParameters::Core::ParamsRegistry.register("HTTPSConnection", @user_params_class)
      assert_equal @user_params_class, StrongParameters::Core::ParamsRegistry.lookup(:https_connection)
    ensure
      # Restore original method
      String.singleton_class.remove_method(:respond_to?)
      String.define_singleton_method(:respond_to?, original_respond_to)
    end
  end

  def test_normalize_key_fallback_edge_cases
    # Test fallback directly
    original_respond_to = String.instance_method(:respond_to?)
    String.define_singleton_method(:respond_to?) do |method_name|
      method_name == :underscore ? false : original_respond_to.bind(String).call(method_name)
    end

    begin
      registry = StrongParameters::Core::ParamsRegistry

      # Test various cases
      assert_equal :blog_post, registry.send(:normalize_key, "BlogPost")
      assert_equal :user_profile, registry.send(:normalize_key, "UserProfile")
      assert_equal :https_connection, registry.send(:normalize_key, "HTTPSConnection")
      assert_equal :xml_http_request, registry.send(:normalize_key, "XMLHttpRequest")
      assert_equal :user, registry.send(:normalize_key, "user")
      assert_equal :user_profile_settings, registry.send(:normalize_key, "user_profile_settings")
      assert_equal :user2_fa, registry.send(:normalize_key, "User2FA")
    ensure
      String.singleton_class.remove_method(:respond_to?)
      String.define_singleton_method(:respond_to?, original_respond_to)
    end
  end
end