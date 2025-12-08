# frozen_string_literal: true

require "test_helper"
require_relative "../lib/legacy/action_controller/application_params"

# Test the legacy ActionController::ApplicationParams implementation
class LegacyActionControllerApplicationParamsTest < Minitest::Test
  def setup
    @application_params_class = ActionController::ApplicationParams
  end

  #
  # --- Class structure tests --------------------------------------------------
  #

  def test_application_params_is_a_class
    assert @application_params_class.is_a?(Class)
  end

  #
  # --- DSL methods tests ------------------------------------------------------
  #

  def test_allow_adds_to_allowed_attributes
    params_class = Class.new(@application_params_class) do
      allow :name
      allow :email
    end

    assert_equal [:name, :email], params_class.allowed_attributes
  end

  def test_allow_with_string_attribute
    params_class = Class.new(@application_params_class) do
      allow "name"
    end

    assert_equal [:name], params_class.allowed_attributes
  end

  def test_allow_prevents_duplicates
    params_class = Class.new(@application_params_class) do
      allow :name
      allow :name
    end

    assert_equal [:name], params_class.allowed_attributes
  end

  def test_allow_with_options_stores_options
    params_class = Class.new(@application_params_class) do
      allow :name, only: :create
      allow :email, except: :update
      allow :tags, array: true
    end

    assert_equal [:name, :email, :tags], params_class.allowed_attributes
    assert_equal({only: [:create]}, params_class.attribute_options(:name))
    assert_equal({except: [:update]}, params_class.attribute_options(:email))
    assert_equal({array: true}, params_class.attribute_options(:tags))
  end

  def test_allow_with_only_as_single_symbol
    params_class = Class.new(@application_params_class) do
      allow :name, only: :create
    end

    assert_equal({only: [:create]}, params_class.attribute_options(:name))
  end

  def test_allow_with_except_as_array
    params_class = Class.new(@application_params_class) do
      allow :name, except: [:update, :destroy]
    end

    assert_equal({except: [:update, :destroy]}, params_class.attribute_options(:name))
  end

  def test_deny_adds_to_denied_attributes
    params_class = Class.new(@application_params_class) do
      deny :admin
      deny :super_user
    end

    assert_equal [:admin, :super_user], params_class.denied_attributes
  end

  def test_deny_with_string_attribute
    params_class = Class.new(@application_params_class) do
      deny "admin"
    end

    assert_equal [:admin], params_class.denied_attributes
  end

  def test_deny_prevents_duplicates
    params_class = Class.new(@application_params_class) do
      deny :admin
      deny :admin
    end

    assert_equal [:admin], params_class.denied_attributes
  end

  def test_flag_sets_flag_values
    params_class = Class.new(@application_params_class) do
      flag :require_approval, true
      flag :auto_verify, false
    end

    assert_equal true, params_class.flag?(:require_approval)
    assert_equal false, params_class.flag?(:auto_verify)
  end

  def test_flag_with_string_name
    params_class = Class.new(@application_params_class) do
      flag "require_approval", true
    end

    assert_equal true, params_class.flag?(:require_approval)
  end

  def test_flag_default_value
    params_class = Class.new(@application_params_class) do
      flag :require_approval
    end

    assert_equal true, params_class.flag?(:require_approval)
  end

  def test_metadata_adds_to_allowed_metadata
    params_class = Class.new(@application_params_class) do
      metadata :ip_address
      metadata :role, :session_id
    end

    assert params_class.metadata_allowed?(:ip_address)
    assert params_class.metadata_allowed?(:role)
    assert params_class.metadata_allowed?(:session_id)
  end

  def test_metadata_with_string_keys
    params_class = Class.new(@application_params_class) do
      metadata "ip_address"
    end

    assert params_class.metadata_allowed?(:ip_address)
  end

  #
  # --- Checker methods tests -------------------------------------------------
  #

  def test_allowed_returns_true_for_allowed_attributes
    params_class = Class.new(@application_params_class) do
      allow :name
      allow :email
    end

    assert params_class.allowed?(:name)
    assert params_class.allowed?(:email)
  end

  def test_allowed_returns_false_for_denied_attributes
    params_class = Class.new(@application_params_class) do
      allow :name
      deny :admin
    end

    refute params_class.allowed?(:admin)
  end

  def test_allowed_returns_false_for_undeclared_attributes
    params_class = Class.new(@application_params_class) do
      allow :name
    end

    refute params_class.allowed?(:email)
  end

  def test_allowed_with_string_attribute
    params_class = Class.new(@application_params_class) do
      allow :name
    end

    assert params_class.allowed?("name")
  end

  def test_denied_returns_true_for_denied_attributes
    params_class = Class.new(@application_params_class) do
      deny :admin
    end

    assert params_class.denied?(:admin)
  end

  def test_denied_returns_false_for_allowed_attributes
    params_class = Class.new(@application_params_class) do
      allow :name
      deny :admin
    end

    refute params_class.denied?(:name)
  end

  def test_denied_with_string_attribute
    params_class = Class.new(@application_params_class) do
      deny :admin
    end

    assert params_class.denied?("admin")
  end

  def test_flag_returns_flag_value
    params_class = Class.new(@application_params_class) do
      flag :require_approval, true
    end

    assert_equal true, params_class.flag?(:require_approval)
  end

  def test_flag_returns_nil_for_unset_flag
    params_class = Class.new(@application_params_class) do
      # no flags set
    end

    assert_nil params_class.flag?(:require_approval)
  end

  def test_flag_with_string_name
    params_class = Class.new(@application_params_class) do
      flag :require_approval, true
    end

    assert_equal true, params_class.flag?("require_approval")
  end

  def test_metadata_allowed_returns_true_for_declared_metadata
    params_class = Class.new(@application_params_class) do
      metadata :ip_address
    end

    assert params_class.metadata_allowed?(:ip_address)
  end

  def test_metadata_allowed_returns_true_for_current_user
    params_class = Class.new(@application_params_class) do
      # no metadata declared
    end

    assert params_class.metadata_allowed?(:current_user)
  end

  def test_metadata_allowed_returns_false_for_undeclared_metadata
    params_class = Class.new(@application_params_class) do
      metadata :ip_address
    end

    refute params_class.metadata_allowed?(:role)
  end

  def test_metadata_allowed_with_string_key
    params_class = Class.new(@application_params_class) do
      metadata :ip_address
    end

    assert params_class.metadata_allowed?("ip_address")
  end

  #
  # --- Permitted attributes tests --------------------------------------------
  #

  def test_permitted_attributes_returns_allowed_attributes
    params_class = Class.new(@application_params_class) do
      allow :name
      allow :email
    end

    assert_equal [:name, :email], params_class.permitted_attributes
  end

  def test_permitted_attributes_excludes_denied_attributes
    params_class = Class.new(@application_params_class) do
      allow :name
      allow :admin
      deny :admin
    end

    assert_equal [:name], params_class.permitted_attributes
  end

  def test_permitted_attributes_with_array_option
    params_class = Class.new(@application_params_class) do
      allow :name
      allow :tags, array: true
    end

    expected = [:name, {tags: []}]
    assert_equal expected, params_class.permitted_attributes
  end

  def test_permitted_attributes_with_only_option
    params_class = Class.new(@application_params_class) do
      allow :name
      allow :published, only: :create
    end

    assert_equal [:name], params_class.permitted_attributes
    assert_equal [:name, :published], params_class.permitted_attributes(action: :create)
  end

  def test_permitted_attributes_with_except_option
    params_class = Class.new(@application_params_class) do
      allow :name
      allow :published, except: :create
    end

    assert_equal [:name, :published], params_class.permitted_attributes
    assert_equal [:name], params_class.permitted_attributes(action: :create)
  end

  def test_permitted_attributes_with_only_as_array
    params_class = Class.new(@application_params_class) do
      allow :name
      allow :published, only: [:create, :update]
    end

    assert_equal [:name], params_class.permitted_attributes
    assert_equal [:name, :published], params_class.permitted_attributes(action: :create)
    assert_equal [:name, :published], params_class.permitted_attributes(action: :update)
  end

  def test_permitted_attributes_with_except_as_array
    params_class = Class.new(@application_params_class) do
      allow :name
      allow :published, except: [:create, :update]
    end

    assert_equal [:name, :published], params_class.permitted_attributes
    assert_equal [:name], params_class.permitted_attributes(action: :create)
    assert_equal [:name], params_class.permitted_attributes(action: :update)
  end

  def test_permitted_attributes_caches_results
    params_class = Class.new(@application_params_class) do
      allow :name
    end

    result1 = params_class.permitted_attributes
    result2 = params_class.permitted_attributes

    assert_equal result1, result2
    assert_equal result1.object_id, result2.object_id
  end

  def test_permitted_attributes_caches_by_action
    params_class = Class.new(@application_params_class) do
      allow :name
      allow :published, only: :create
    end

    result1 = params_class.permitted_attributes
    result2 = params_class.permitted_attributes(action: :create)

    refute_equal result1.object_id, result2.object_id
  end

  def test_permitted_attributes_freezes_result
    params_class = Class.new(@application_params_class) do
      allow :name
    end

    result = params_class.permitted_attributes
    assert result.frozen?
  end

  #
  # --- Inheritance tests -----------------------------------------------------
  #

  def test_inherited_copies_allowed_attributes
    parent_class = Class.new(@application_params_class) do
      allow :name
      allow :email
    end

    child_class = Class.new(parent_class) do
      allow :age
    end

    assert_equal [:name, :email, :age], child_class.allowed_attributes
  end

  def test_inherited_copies_denied_attributes
    parent_class = Class.new(@application_params_class) do
      deny :admin
    end

    child_class = Class.new(parent_class) do
      deny :super_user
    end

    assert_equal [:admin, :super_user], child_class.denied_attributes
  end

  def test_inherited_copies_flags
    parent_class = Class.new(@application_params_class) do
      flag :require_approval, true
    end

    child_class = Class.new(parent_class) do
      flag :auto_verify, false
    end

    assert_equal true, child_class.flag?(:require_approval)
    assert_equal false, child_class.flag?(:auto_verify)
  end

  def test_inherited_copies_metadata
    parent_class = Class.new(@application_params_class) do
      metadata :ip_address
    end

    child_class = Class.new(parent_class) do
      metadata :role
    end

    assert child_class.metadata_allowed?(:ip_address)
    assert child_class.metadata_allowed?(:role)
  end

  def test_inherited_copies_attribute_options
    parent_class = Class.new(@application_params_class) do
      allow :name, only: :create
    end

    child_class = Class.new(parent_class) do
      allow :email, array: true
    end

    assert_equal({only: [:create]}, child_class.attribute_options(:name))
    assert_equal({array: true}, child_class.attribute_options(:email))
  end

  def test_inherited_does_not_copy_cache
    parent_class = Class.new(@application_params_class) do
      allow :name
    end

    # Fill parent's cache
    parent_class.permitted_attributes

    child_class = Class.new(parent_class)

    # Child should have its own cache
    refute_equal parent_class.instance_variable_get(:@permitted_cache).object_id,
                 child_class.instance_variable_get(:@permitted_cache).object_id
  end

  #
  # --- Edge cases and error conditions ---------------------------------------
  #

  def test_attribute_options_returns_empty_hash_for_unknown_attribute
    params_class = Class.new(@application_params_class)

    assert_equal({}, params_class.attribute_options(:unknown))
  end

  def test_attribute_options_with_string_key
    params_class = Class.new(@application_params_class) do
      allow :name, only: :create
    end

    assert_equal({only: [:create]}, params_class.attribute_options("name"))
  end

  def test_permitted_attributes_with_nil_action
    params_class = Class.new(@application_params_class) do
      allow :name
      allow :published, only: :create
    end

    assert_equal [:name], params_class.permitted_attributes(action: nil)
  end

  def test_permitted_attributes_with_empty_action
    params_class = Class.new(@application_params_class) do
      allow :name
      allow :published, only: :create
    end

    assert_equal [:name], params_class.permitted_attributes(action: "")
  end

  def test_allow_with_empty_options
    params_class = Class.new(@application_params_class) do
      allow :name, {}
    end

    assert_equal [:name], params_class.allowed_attributes
    assert_equal({}, params_class.attribute_options(:name))
  end

  def test_metadata_with_empty_args
    params_class = Class.new(@application_params_class) do
      metadata
    end

    assert_equal Set.new, params_class.allowed_metadata
  end

  def test_multiple_inheritance_levels
    grandparent = Class.new(@application_params_class) do
      allow :name
      metadata :ip_address
    end

    parent = Class.new(grandparent) do
      allow :email
      metadata :role
    end

    child = Class.new(parent) do
      allow :age
      metadata :session_id
    end

    assert_equal [:name, :email, :age], child.allowed_attributes
    assert child.metadata_allowed?(:ip_address)
    assert child.metadata_allowed?(:role)
    assert child.metadata_allowed?(:session_id)
  end

  def test_inheritance_preserves_instance_variables
    parent_class = Class.new(@application_params_class) do
      allow :name
    end

    # Ensure parent has instance variables initialized
    parent_class.allowed_attributes
    parent_class.denied_attributes
    parent_class.flags
    parent_class.allowed_metadata

    child_class = Class.new(parent_class)

    assert_equal [:name], child_class.allowed_attributes
    assert_equal [], child_class.denied_attributes
    assert_equal({}, child_class.flags)
    assert_equal Set.new, child_class.allowed_metadata
  end

  #
  # --- Integration tests -----------------------------------------------------
  #

  def test_complex_example_from_documentation
    user_params_class = Class.new(@application_params_class) do
      allow :name
      allow :email
      deny :is_admin
    end

    post_params_class = Class.new(@application_params_class) do
      allow :title
      allow :body
      allow :published, only: :create
      allow :view_count, except: :create
    end

    account_params_class = Class.new(@application_params_class) do
      allow :name
      metadata :ip_address, :role
    end

    assert_equal [:name, :email], user_params_class.permitted_attributes
    assert_equal [:title, :body, :view_count], post_params_class.permitted_attributes
    assert_equal [:title, :body, :published], post_params_class.permitted_attributes(action: :create)
    assert account_params_class.metadata_allowed?(:ip_address)
    assert account_params_class.metadata_allowed?(:role)
  end
end