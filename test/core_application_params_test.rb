# frozen_string_literal: true

require "test_helper"

class CoreApplicationParamsTest < Minitest::Test
  def setup
    # Clear any existing registrations
    DurableParameters::Core::ParamsRegistry.clear!
  end

  def teardown
    DurableParameters::Core::ParamsRegistry.clear!
  end

  # Test basic class structure
  def test_application_params_is_a_class
    assert DurableParameters::Core::ApplicationParams.is_a?(Class)
  end

  def test_application_params_extends_descendants_tracker
    assert DurableParameters::Core::ApplicationParams.respond_to?(:descendants)
    assert DurableParameters::Core::ApplicationParams.descendants.is_a?(Array)
  end

  # Test DSL methods
  def test_allow_adds_to_allowed_attributes
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :name
      allow :email
    end

    assert_equal [:name, :email], params_class.allowed_attributes
  end

  def test_deny_adds_to_denied_attributes
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      deny :admin
      deny :super_user
    end

    assert_equal [:admin, :super_user], params_class.denied_attributes
  end

  def test_flag_sets_flag_values
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      flag :require_approval, true
      flag :auto_verify, false
    end

    assert_equal true, params_class.flag?(:require_approval)
    assert_equal false, params_class.flag?(:auto_verify)
    assert_nil params_class.flag?(:nonexistent)
  end

  def test_metadata_adds_to_allowed_metadata
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      metadata :current_user
      metadata :request_ip
    end

    assert params_class.allowed_metadata.include?(:current_user)
    assert params_class.allowed_metadata.include?(:request_ip)
  end

  def test_current_user_is_always_allowed_in_metadata
    params_class = Class.new(DurableParameters::Core::ApplicationParams)
    assert params_class.metadata_allowed?(:current_user)
  end

  def test_transform_stores_transformation_blocks
    transformation_called = false
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :email
      transform :email do |value, metadata|
        transformation_called = true
        value&.upcase
      end
    end

    assert params_class.transformations.key?(:email)
    # Test that transformation works
    result = params_class.apply_transformations({email: "test@example.com"})
    assert_equal "TEST@EXAMPLE.COM", result[:email]
    assert transformation_called
  end

  # Test attribute checking methods
  def test_allowed_returns_true_for_allowed_attributes
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :name
    end

    assert params_class.allowed?(:name)
    assert params_class.allowed?("name")
  end

  def test_allowed_returns_false_for_denied_attributes
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :admin
      deny :admin
    end

    refute params_class.allowed?(:admin)
    assert params_class.denied?(:admin)
  end

  def test_allowed_returns_false_for_non_allowed_attributes
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :name
    end

    refute params_class.allowed?(:age)
  end

  def test_denied_returns_true_for_denied_attributes
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      deny :secret
    end

    assert params_class.denied?(:secret)
  end

  # Test permitted_attributes generation
  def test_permitted_attributes_returns_allowed_attributes
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :name
      allow :email
      deny :admin
    end

    permitted = params_class.permitted_attributes
    assert_equal [:name, :email], permitted
  end

  def test_permitted_attributes_with_array_attributes
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :tags, array: true
      allow :scores, array: true
    end

    permitted = params_class.permitted_attributes
    assert_equal [{tags: []}, {scores: []}], permitted
  end

  def test_permitted_attributes_with_action_filtering
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :title
      allow :published, only: :create
      allow :updated_at, except: :create
    end

    create_permitted = params_class.permitted_attributes(action: :create)
    assert_includes create_permitted, :title
    assert_includes create_permitted, :published
    refute_includes create_permitted, :updated_at

    update_permitted = params_class.permitted_attributes(action: :update)
    assert_includes update_permitted, :title
    refute_includes update_permitted, :published
    assert_includes update_permitted, :updated_at
  end

  def test_permitted_attributes_caching
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :name
    end

    # First call
    first_result = params_class.permitted_attributes
    # Second call should return the same cached result
    second_result = params_class.permitted_attributes

    assert_same first_result, second_result
  end

  def test_permitted_attributes_cache_invalidation_on_allow
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :name
    end

    first_result = params_class.permitted_attributes
    params_class.allow :email
    second_result = params_class.permitted_attributes

    refute_same first_result, second_result
    assert_equal [:name, :email], second_result
  end

  def test_permitted_attributes_cache_invalidation_on_deny
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :name
      allow :admin
    end

    first_result = params_class.permitted_attributes
    params_class.deny :admin
    second_result = params_class.permitted_attributes

    refute_same first_result, second_result
    assert_equal [:name], second_result
  end

  def test_permitted_attributes_cache_separate_for_actions
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :name
      allow :admin, only: :create
    end

    no_action_result = params_class.permitted_attributes
    create_result = params_class.permitted_attributes(action: :create)
    update_result = params_class.permitted_attributes(action: :update)

    # Different cache entries for different actions
    refute_same no_action_result, create_result
    refute_same create_result, update_result

    assert_equal [:name, :admin], no_action_result
    assert_equal [:name, :admin], create_result
    assert_equal [:name], update_result
  end

  def test_permitted_attributes_cache_invalidation_on_attribute_options_change
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :field, only: :create
    end

    first_result = params_class.permitted_attributes(action: :create)
    params_class.allow :field, only: [:create, :update]  # Change options
    second_result = params_class.permitted_attributes(action: :create)

    refute_same first_result, second_result
    assert_equal [:field], second_result
  end

  def test_permitted_attributes_cache_not_shared_between_classes
    class1 = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :name
    end

    class2 = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :name
    end

    result1 = class1.permitted_attributes
    result2 = class2.permitted_attributes

    # Different classes should have separate caches
    refute_same result1, result2
    assert_equal [:name], result1
    assert_equal [:name], result2
  end

  # Test inheritance
  def test_inheritance_copies_allowed_attributes
    parent_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :name
      allow :email
    end

    child_class = Class.new(parent_class) do
      allow :age
    end

    assert_equal [:name, :email, :age], child_class.allowed_attributes
  end

  def test_inheritance_copies_denied_attributes
    parent_class = Class.new(DurableParameters::Core::ApplicationParams) do
      deny :admin
    end

    child_class = Class.new(parent_class) do
      deny :super_admin
    end

    assert_equal [:admin, :super_admin], child_class.denied_attributes
  end

  def test_inheritance_copies_flags
    parent_class = Class.new(DurableParameters::Core::ApplicationParams) do
      flag :require_approval, true
    end

    child_class = Class.new(parent_class) do
      flag :auto_verify, false
    end

    assert_equal true, child_class.flag?(:require_approval)
    assert_equal false, child_class.flag?(:auto_verify)
  end

  def test_inheritance_copies_metadata
    parent_class = Class.new(DurableParameters::Core::ApplicationParams) do
      metadata :current_user
    end

    child_class = Class.new(parent_class) do
      metadata :request_ip
    end

    assert child_class.allowed_metadata.include?(:current_user)
    assert child_class.allowed_metadata.include?(:request_ip)
  end

  def test_inheritance_copies_transformations
    parent_called = false
    child_called = false

    parent_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :email
      transform :email do |value, metadata|
        parent_called = true
        value&.upcase
      end
    end

    child_class = Class.new(parent_class) do
      transform :email do |value, metadata|
        child_called = true
        "#{value&.upcase!}!"
      end
    end

    result = child_class.apply_transformations({email: "test@example.com"})
    assert_equal "TEST@EXAMPLE.COM!", result[:email]
    assert child_called
    # Parent transformation is overridden
    refute parent_called
  end

  def test_complex_inheritance_with_multiple_levels
    grandparent = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :id
      deny :secret
      flag :inherited_flag, true
      metadata :session
      transform :id do |value, metadata|
        "gp-#{value}"
      end
    end

    parent = Class.new(grandparent) do
      allow :name
      flag :parent_flag, "parent"
      metadata :user
      transform :name do |value, metadata|
        "p-#{value}"
      end
    end

    child = Class.new(parent) do
      allow :email
      deny :id  # Override grandparent's allow
      flag :inherited_flag, false  # Override flag
      metadata :request
      transform :email do |value, metadata|
        "c-#{value}"
      end
    end

    # Check inheritance
    assert_equal [:id, :name, :email], child.allowed_attributes
    assert_equal [:secret, :id], child.denied_attributes
    assert_equal [:name, :email], child.permitted_attributes
    assert_equal false, child.flag?(:inherited_flag)
    assert_equal "parent", child.flag?(:parent_flag)
    assert child.metadata_allowed?(:session)
    assert child.metadata_allowed?(:user)
    assert child.metadata_allowed?(:request)

    # Test transformations
    result = child.apply_transformations({id: "123", name: "John", email: "test@example.com"})
    assert_equal "gp-123", result[:id]  # Grandparent transform still applies even though denied? No, transformations apply before filtering
    assert_equal "p-John", result[:name]
    assert_equal "c-test@example.com", result[:email]
  end

  def test_inheritance_with_attribute_options
    parent = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :field1, only: :create
      allow :field2, except: :update
    end

    child = Class.new(parent) do
      allow :field3, only: [:create, :update]
    end

    # Child inherits parent's attribute options
    assert_equal({only: [:create]}, child.attribute_options(:field1))
    assert_equal({except: [:update]}, child.attribute_options(:field2))
    assert_equal({only: [:create, :update]}, child.attribute_options(:field3))

    # Permitted attributes reflect inherited options
    create_permitted = child.permitted_attributes(action: :create)
    assert_includes create_permitted, :field1
    assert_includes create_permitted, :field2
    assert_includes create_permitted, :field3

    update_permitted = child.permitted_attributes(action: :update)
    refute_includes update_permitted, :field1
    refute_includes update_permitted, :field2
    assert_includes update_permitted, :field3
  end

  # Test invalid inputs
  def test_allowed_with_non_symbolizable_attribute
    params_class = Class.new(DurableParameters::Core::ApplicationParams)

    # Objects that don't respond to to_sym should return false
    refute params_class.allowed?(123)
    refute params_class.allowed?([])
    refute params_class.allowed?({})
    refute params_class.allowed?(nil)
  end

  def test_denied_with_non_symbolizable_attribute
    params_class = Class.new(DurableParameters::Core::ApplicationParams)

    refute params_class.denied?(123)
    refute params_class.denied?([])
    refute params_class.denied?({})
    refute params_class.denied?(nil)
  end

  def test_flag_with_non_symbolizable_name
    params_class = Class.new(DurableParameters::Core::ApplicationParams)

    assert_nil params_class.flag?(123)
    assert_nil params_class.flag?([])
    assert_nil params_class.flag?({})
    assert_nil params_class.flag?(nil)
  end

  def test_metadata_allowed_with_non_symbolizable_key
    params_class = Class.new(DurableParameters::Core::ApplicationParams)

    refute params_class.metadata_allowed?(123)
    refute params_class.metadata_allowed?([])
    refute params_class.metadata_allowed?({})
    refute params_class.metadata_allowed?(nil)
  end

  def test_attribute_options_with_non_symbolizable_attribute
    params_class = Class.new(DurableParameters::Core::ApplicationParams)

    assert_equal({}, params_class.attribute_options(123))
    assert_equal({}, params_class.attribute_options([]))
    assert_equal({}, params_class.attribute_options({}))
    assert_equal({}, params_class.attribute_options(nil))
  end

  def test_allow_with_non_symbolizable_attribute
    params_class = Class.new(DurableParameters::Core::ApplicationParams)

    # Should not raise, but should not add anything
    params_class.allow(123)
    params_class.allow([])
    params_class.allow({})

    assert_empty params_class.allowed_attributes
  end

  def test_deny_with_non_symbolizable_attribute
    params_class = Class.new(DurableParameters::Core::ApplicationParams)

    params_class.deny(123)
    params_class.deny([])
    params_class.deny({})

    assert_empty params_class.denied_attributes
  end

  def test_flag_with_non_symbolizable_name_sets_nothing
    params_class = Class.new(DurableParameters::Core::ApplicationParams)

    params_class.flag(123, "value")
    params_class.flag([], "value")
    params_class.flag({}, "value")

    assert_empty params_class.flags
  end

  def test_metadata_with_non_symbolizable_keys
    params_class = Class.new(DurableParameters::Core::ApplicationParams)

    params_class.metadata(123)
    params_class.metadata([])
    params_class.metadata({})

    assert_equal Set.new, params_class.allowed_metadata
  end

  def test_transform_with_non_symbolizable_attribute
    params_class = Class.new(DurableParameters::Core::ApplicationParams)

    # Should not raise, but should not add transformation
    params_class.transform(123) { |v| v }
    params_class.transform([]) { |v| v }
    params_class.transform({}) { |v| v }

    assert_empty params_class.transformations
  end

  # Test transformations
  def test_apply_transformations_with_no_transformations
    params_class = Class.new(DurableParameters::Core::ApplicationParams)
    input = {name: "John", email: "john@example.com"}
    result = params_class.apply_transformations(input)

    assert_equal input, result
  end

  def test_apply_transformations_with_hash_input
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :email
      transform :email do |value, metadata|
        value&.downcase&.strip
      end
    end

    input = {email: "  JOHN@EXAMPLE.COM  ", name: "John"}
    result = params_class.apply_transformations(input)

    assert_equal "john@example.com", result[:email]
    assert_equal "John", result[:name]
  end

  def test_apply_transformations_with_parameters_object
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :email
      transform :email do |value, metadata|
        value&.upcase
      end
    end

    params = DurableParameters::Core::Parameters.new(email: "test@example.com")
    result = params_class.apply_transformations(params)

    assert_equal "TEST@EXAMPLE.COM", result["email"]
  end

  def test_apply_transformations_with_metadata
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :role
      metadata :current_user
      transform :role do |value, metadata|
        if metadata[:current_user]&.admin?
          value
        else
          'user'
        end
      end
    end

    # Test with admin user
    admin_user = Object.new
    def admin_user.admin?; true; end

    result = params_class.apply_transformations({role: 'admin'}, current_user: admin_user)
    assert_equal 'admin', result[:role]

    # Test with regular user
    regular_user = Object.new
    def regular_user.admin?; false; end

    result = params_class.apply_transformations({role: 'admin'}, current_user: regular_user)
    assert_equal 'user', result[:role]
  end

  def test_apply_transformations_handles_nil_values
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :email
      transform :email do |value, metadata|
        value&.upcase
      end
    end

    result = params_class.apply_transformations({email: nil})
    assert_nil result[:email]
  end

  def test_apply_transformations_with_deep_dup
    transformed = false
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :data
      transform :data do |value, metadata|
        transformed = true
        value[:nested] = "modified"
        value
      end
    end

    original = {data: {nested: "original"}}
    result = params_class.apply_transformations(original.dup)

    assert transformed, "Transformation should have been called"
    assert_equal "original", original[:data][:nested]  # Original should be unchanged
    assert_equal "modified", result[:data][:nested]
  end

  def test_apply_transformations_with_nil_params
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      transform :email do |value, metadata|
        "transformed"
      end
    end

    result = params_class.apply_transformations(nil)
    assert_nil result
  end

  def test_apply_transformations_with_non_hash_params
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      transform :email do |value, metadata|
        "transformed"
      end
    end

    result = params_class.apply_transformations("string")
    assert_equal "string", result

    result = params_class.apply_transformations(123)
    assert_equal 123, result

    result = params_class.apply_transformations([])
    assert_equal [], result
  end

  def test_apply_transformations_with_mixed_string_symbol_keys
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :email
      transform :email do |value, metadata|
        value&.upcase
      end
    end

    # Test with string key
    result = params_class.apply_transformations({"email" => "test@example.com"})
    assert_equal "TEST@EXAMPLE.COM", result["email"]

    # Test with symbol key
    result = params_class.apply_transformations({email: "test@example.com"})
    assert_equal "TEST@EXAMPLE.COM", result[:email]

    # Test with both keys (should transform both)
    hash = {"email" => "string", email: "symbol"}
    result = params_class.apply_transformations(hash)
    assert_equal "STRING", result["email"]
    assert_equal "SYMBOL", result[:email]
  end

  def test_apply_transformations_with_unserializable_objects
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :data
      transform :data do |value, metadata|
        # Try to modify the value
        value[:modified] = true
        value
      end
    end

    # Create an object that can't be marshaled
    unserializable = {proc: proc { "test" }}
    result = params_class.apply_transformations({data: unserializable})

    # Should still work with shallow dup fallback
    assert result[:data][:modified]
    # Original should be unchanged due to dup
    refute unserializable.key?(:modified)
  end

  # Test attribute options
  def test_attribute_options_stores_options
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :tags, array: true, only: :create
    end

    options = params_class.attribute_options(:tags)
    assert_equal({array: true, only: [:create]}, options)
  end

  def test_attribute_options_normalizes_only_and_except
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :field1, only: :create
      allow :field2, except: [:update, :destroy]
    end

    assert_equal [:create], params_class.attribute_options(:field1)[:only]
    assert_equal [:update, :destroy], params_class.attribute_options(:field2)[:except]
  end

  # Test edge cases
  def test_allow_with_duplicate_attributes
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :name
      allow :name
      allow :name
    end

    assert_equal [:name], params_class.allowed_attributes
  end

  def test_deny_with_duplicate_attributes
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      deny :admin
      deny :admin
    end

    assert_equal [:admin], params_class.denied_attributes
  end

  def test_allow_overwrites_previous_options
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :field, only: :create
      allow :field, array: true
    end

    options = params_class.attribute_options(:field)
    assert_equal({array: true}, options)
  end

  def test_metadata_with_duplicate_keys
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      metadata :current_user
      metadata :current_user
    end

    assert_equal 1, params_class.allowed_metadata.count(:current_user)
  end

  def test_transform_requires_block
    assert_raises(ArgumentError) do
      Class.new(DurableParameters::Core::ApplicationParams) do
        transform :email
      end
    end
  end

  def test_transform_overwrites_previous_transformation
    first_called = false
    second_called = false

    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :email
      transform :email do |value, metadata|
        first_called = true
        value&.upcase
      end
      transform :email do |value, metadata|
        second_called = true
        value&.downcase
      end
    end

    result = params_class.apply_transformations({email: "TEST@EXAMPLE.COM"})
    assert_equal "test@example.com", result[:email]
    refute first_called
    assert second_called
  end

  # Test complex scenarios
  def test_complex_inheritance_with_overrides
    base_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :name
      allow :email
      deny :admin
      flag :base_flag, true
      metadata :current_user
    end

    specialized_class = Class.new(base_class) do
      allow :phone
      deny :email  # Override parent's allow
      flag :base_flag, false  # Override flag
      flag :special_flag, true
      metadata :request_ip
    end

    assert_equal [:name, :email, :phone], specialized_class.allowed_attributes
    assert_equal [:admin, :email], specialized_class.denied_attributes
    assert_equal [:name, :phone], specialized_class.permitted_attributes
    assert_equal false, specialized_class.flag?(:base_flag)
    assert_equal true, specialized_class.flag?(:special_flag)
    assert specialized_class.allowed_metadata.include?(:current_user)
    assert specialized_class.allowed_metadata.include?(:request_ip)
  end

  def test_multiple_transformations_on_same_attribute
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :email
      transform :email do |value, metadata|
        value&.strip&.downcase
      end
    end

    result = params_class.apply_transformations({email: "  JOHN@EXAMPLE.COM  "})
    assert_equal "john@example.com", result[:email]
  end

  def test_transformations_with_non_hash_input
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      transform :email do |value, metadata|
        "transformed"
      end
    end

    # Should handle non-hash gracefully
    result = params_class.apply_transformations("not a hash")
    assert_equal "not a hash", result
  end

  def test_permitted_attributes_with_mixed_array_and_scalar
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :name
      allow :tags, array: true
      allow :age
      allow :categories, array: true
    end

    permitted = params_class.permitted_attributes
    assert_includes permitted, :name
    assert_includes permitted, :age
    assert_includes permitted, {tags: []}
    assert_includes permitted, {categories: []}
  end

  def test_permitted_attributes_with_complex_action_filters
    params_class = Class.new(DurableParameters::Core::ApplicationParams) do
      allow :title
      allow :content, only: [:create, :update]
      allow :published_at, only: :create
      allow :updated_at, except: :create
      allow :tags, array: true, only: [:create, :update]
    end

    create_permitted = params_class.permitted_attributes(action: :create)
    assert_includes create_permitted, :title
    assert_includes create_permitted, :content
    assert_includes create_permitted, :published_at
    refute_includes create_permitted, :updated_at
    assert_includes create_permitted, {tags: []}

    update_permitted = params_class.permitted_attributes(action: :update)
    assert_includes update_permitted, :title
    assert_includes update_permitted, :content
    refute_includes update_permitted, :published_at
    assert_includes update_permitted, :updated_at
    assert_includes update_permitted, {tags: []}

    show_permitted = params_class.permitted_attributes(action: :show)
    assert_includes show_permitted, :title
    refute_includes show_permitted, :content
    refute_includes show_permitted, :published_at
    assert_includes show_permitted, :updated_at
    refute_includes show_permitted, {tags: []}
  end
end