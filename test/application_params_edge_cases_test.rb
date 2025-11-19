require "test_helper"

class ApplicationParamsEdgeCasesTest < Minitest::Test
  def setup
    ActionController::ParamsRegistry.clear!
  end

  def teardown
    ActionController::ParamsRegistry.clear!
  end

  # Test duplicate allow calls
  def test_duplicate_allow_calls_dont_duplicate_attributes
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :name
      allow :name
      allow :name
    end

    assert_equal [:name], test_class.allowed_attributes
  end

  # Test duplicate deny calls
  def test_duplicate_deny_calls_dont_duplicate_attributes
    test_class = Class.new(ActionController::ApplicationParams) do
      deny :admin
      deny :admin
      deny :admin
    end

    assert_equal [:admin], test_class.denied_attributes
  end

  # Test allow and deny same attribute
  def test_deny_overrides_allow
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :admin
      deny :admin
    end

    # Deny should take precedence
    assert !test_class.allowed?(:admin)
    assert test_class.denied?(:admin)
  end

  # Test order of allow/deny doesn't matter
  def test_deny_before_allow_still_denies
    test_class = Class.new(ActionController::ApplicationParams) do
      deny :admin
      allow :admin
    end

    # Deny should still take precedence
    assert !test_class.allowed?(:admin)
    assert test_class.denied?(:admin)
  end

  # Test empty class
  def test_empty_params_class_has_empty_lists
    test_class = Class.new(ActionController::ApplicationParams)

    assert_equal [], test_class.allowed_attributes
    assert_equal [], test_class.denied_attributes
    assert_equal({}, test_class.flags)
    assert_equal Set.new, test_class.allowed_metadata
  end

  # Test flag overwriting
  def test_flag_can_be_overwritten
    test_class = Class.new(ActionController::ApplicationParams) do
      flag :test_flag, true
      flag :test_flag, false
    end

    assert_equal false, test_class.flag?(:test_flag)
  end

  # Test flag with different value types
  def test_flag_with_string_value
    test_class = Class.new(ActionController::ApplicationParams) do
      flag :status, "active"
    end

    assert_equal "active", test_class.flag?(:status)
  end

  def test_flag_with_numeric_value
    test_class = Class.new(ActionController::ApplicationParams) do
      flag :max_count, 100
    end

    assert_equal 100, test_class.flag?(:max_count)
  end

  def test_flag_with_array_value
    test_class = Class.new(ActionController::ApplicationParams) do
      flag :allowed_actions, [:create, :update]
    end

    assert_equal [:create, :update], test_class.flag?(:allowed_actions)
  end

  def test_flag_with_hash_value
    test_class = Class.new(ActionController::ApplicationParams) do
      flag :config, {min: 1, max: 10}
    end

    assert_equal({min: 1, max: 10}, test_class.flag?(:config))
  end

  # Test attribute options with different formats
  def test_allow_with_only_single_action
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :field, only: :create
    end

    assert_includes test_class.permitted_attributes(action: :create), :field
    refute_includes test_class.permitted_attributes(action: :update), :field
  end

  def test_allow_with_only_array_of_actions
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :field, only: [:create, :update]
    end

    assert_includes test_class.permitted_attributes(action: :create), :field
    assert_includes test_class.permitted_attributes(action: :update), :field
    refute_includes test_class.permitted_attributes(action: :destroy), :field
  end

  def test_allow_with_except_single_action
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :field, except: :destroy
    end

    assert_includes test_class.permitted_attributes(action: :create), :field
    assert_includes test_class.permitted_attributes(action: :update), :field
    refute_includes test_class.permitted_attributes(action: :destroy), :field
  end

  def test_allow_with_except_array_of_actions
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :field, except: [:destroy, :delete]
    end

    assert_includes test_class.permitted_attributes(action: :create), :field
    refute_includes test_class.permitted_attributes(action: :destroy), :field
    refute_includes test_class.permitted_attributes(action: :delete), :field
  end

  # Test multiple attributes with different options
  def test_multiple_attributes_with_different_action_filters
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :name
      allow :email
      allow :status, only: :create
      allow :updated_by, except: :create
    end

    create_attrs = test_class.permitted_attributes(action: :create)
    assert_includes create_attrs, :name
    assert_includes create_attrs, :email
    assert_includes create_attrs, :status
    refute_includes create_attrs, :updated_by

    update_attrs = test_class.permitted_attributes(action: :update)
    assert_includes update_attrs, :name
    assert_includes update_attrs, :email
    refute_includes update_attrs, :status
    assert_includes update_attrs, :updated_by
  end

  # Test inheritance with complex scenarios
  def test_deep_inheritance_chain
    grandparent = Class.new(ActionController::ApplicationParams) do
      allow :id
      flag :grandparent_flag, true
    end

    parent = Class.new(grandparent) do
      allow :name
      flag :parent_flag, true
    end

    child = Class.new(parent) do
      allow :email
      flag :child_flag, true
    end

    # Child should have all attributes
    assert_includes child.allowed_attributes, :id
    assert_includes child.allowed_attributes, :name
    assert_includes child.allowed_attributes, :email

    # Child should have all flags
    assert child.flag?(:grandparent_flag)
    assert child.flag?(:parent_flag)
    assert child.flag?(:child_flag)
  end

  def test_child_modifications_dont_affect_parent
    parent = Class.new(ActionController::ApplicationParams) do
      allow :name
    end

    child = Class.new(parent) do
      allow :email
      deny :name
    end

    # Parent should remain unchanged
    assert_includes parent.allowed_attributes, :name
    assert_equal [], parent.denied_attributes
    assert parent.allowed?(:name)

    # Child should have modifications
    assert_includes child.allowed_attributes, :name
    assert_includes child.allowed_attributes, :email
    assert_includes child.denied_attributes, :name
    assert !child.allowed?(:name)
  end

  # Test symbol/string conversions
  def test_allow_converts_string_to_symbol
    test_class = Class.new(ActionController::ApplicationParams) do
      allow "name"
      allow "email"
    end

    assert_includes test_class.allowed_attributes, :name
    assert_includes test_class.allowed_attributes, :email
  end

  def test_deny_converts_string_to_symbol
    test_class = Class.new(ActionController::ApplicationParams) do
      deny "admin"
    end

    assert_includes test_class.denied_attributes, :admin
  end

  def test_flag_converts_string_name_to_symbol
    test_class = Class.new(ActionController::ApplicationParams) do
      flag "test_flag", true
    end

    assert test_class.flag?(:test_flag)
    assert test_class.flag?("test_flag")
  end

  # Test permitted_attributes without action filter
  def test_permitted_attributes_without_action_includes_all
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :name
      allow :status, only: :create
      allow :email, except: :destroy
    end

    attrs = test_class.permitted_attributes
    assert_includes attrs, :name
    assert_includes attrs, :status
    assert_includes attrs, :email
  end

  # Test metadata edge cases
  def test_metadata_with_duplicate_keys
    test_class = Class.new(ActionController::ApplicationParams) do
      metadata :ip_address
      metadata :ip_address
      metadata :ip_address
    end

    # Should only be stored once
    assert_equal 1, test_class.allowed_metadata.size
    assert test_class.metadata_allowed?(:ip_address)
  end

  def test_metadata_with_mixed_symbol_string
    test_class = Class.new(ActionController::ApplicationParams) do
      metadata :key1
      metadata "key2"
    end

    assert test_class.metadata_allowed?(:key1)
    assert test_class.metadata_allowed?("key1")
    assert test_class.metadata_allowed?(:key2)
    assert test_class.metadata_allowed?("key2")
  end

  # Test attribute_options with non-existent attribute
  def test_attribute_options_for_non_existent_attribute
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :name
    end

    opts = test_class.attribute_options(:non_existent)
    assert_equal({}, opts)
  end

  # Test attribute_options overwriting
  def test_allow_same_attribute_twice_with_different_options
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :field, only: :create
      allow :field, except: :destroy
    end

    # Second call should overwrite options
    opts = test_class.attribute_options(:field)
    assert_nil opts[:only]
    assert_equal [:destroy], opts[:except]
  end

  # Test empty action filters
  def test_allow_with_empty_only_array
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :field, only: []
    end

    # Empty array should exclude field from all actions
    refute_includes test_class.permitted_attributes(action: :create), :field
    refute_includes test_class.permitted_attributes(action: :update), :field
  end

  def test_allow_with_empty_except_array
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :field, except: []
    end

    # Empty array should include field in all actions
    assert_includes test_class.permitted_attributes(action: :create), :field
    assert_includes test_class.permitted_attributes(action: :update), :field
  end

  # Test complex inheritance with metadata
  def test_inheritance_with_metadata_additions
    parent = Class.new(ActionController::ApplicationParams) do
      metadata :parent_meta
    end

    child = Class.new(parent) do
      metadata :child_meta
    end

    assert child.metadata_allowed?(:parent_meta)
    assert child.metadata_allowed?(:child_meta)
    assert parent.metadata_allowed?(:parent_meta)
    assert !parent.metadata_allowed?(:child_meta)
  end

  # Test inheritance with attribute_options
  def test_inheritance_copies_attribute_options
    parent = Class.new(ActionController::ApplicationParams) do
      allow :field, only: :create
    end

    child = Class.new(parent)

    opts = child.attribute_options(:field)
    assert_equal [:create], opts[:only]
  end
end
