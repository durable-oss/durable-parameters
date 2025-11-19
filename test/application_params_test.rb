require 'test_helper'

class ApplicationParamsTest < Minitest::Test
  def setup
    # Clear the registry before each test
    ActionController::ParamsRegistry.clear!

    # Define test params classes
    @user_params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'UserParams'
      end

      allow :first_name
      allow :last_name
      allow :email
      deny :is_admin
    end

    @account_params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'AccountParams'
      end

      allow :name
      allow :description
      flag :require_approval, true
    end
  end

  def teardown
    ActionController::ParamsRegistry.clear!
  end

  def test_allow_adds_attribute_to_allowed_list
    assert_equal [:first_name, :last_name, :email], @user_params_class.allowed_attributes
  end

  def test_deny_adds_attribute_to_denied_list
    assert_equal [:is_admin], @user_params_class.denied_attributes
  end

  def test_flag_sets_flag_value
    assert_equal true, @account_params_class.flag?(:require_approval)
  end

  def test_flag_returns_nil_for_unset_flag
    assert_nil @user_params_class.flag?(:nonexistent_flag)
  end

  def test_allowed_returns_true_for_allowed_attribute
    assert @user_params_class.allowed?(:first_name)
    assert @user_params_class.allowed?('last_name')
  end

  def test_allowed_returns_false_for_non_allowed_attribute
    assert !@user_params_class.allowed?(:age)
  end

  def test_allowed_returns_false_for_denied_attribute
    assert !@user_params_class.allowed?(:is_admin)
  end

  def test_denied_returns_true_for_denied_attribute
    assert @user_params_class.denied?(:is_admin)
  end

  def test_permitted_attributes_returns_allowed_list
    permitted = @user_params_class.permitted_attributes
    assert_equal [:first_name, :last_name, :email], permitted
  end

  def test_allow_with_only_option
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :title, only: [:create, :update]
      allow :body, except: :destroy
    end

    # With action: :create, should include title
    assert_includes test_class.permitted_attributes(action: :create), :title

    # With action: :show, should not include title
    refute_includes test_class.permitted_attributes(action: :show), :title

    # With action: :destroy, should not include body
    refute_includes test_class.permitted_attributes(action: :destroy), :body

    # With action: :update, should include body
    assert_includes test_class.permitted_attributes(action: :update), :body
  end

  def test_inheritance_copies_parent_attributes
    parent_class = Class.new(ActionController::ApplicationParams) do
      allow :name
      allow :email
      flag :inherited_flag, true
    end

    child_class = Class.new(parent_class) do
      allow :age
      deny :email
    end

    # Child should have parent's allowed attributes
    assert_includes child_class.allowed_attributes, :name
    assert_includes child_class.allowed_attributes, :email
    assert_includes child_class.allowed_attributes, :age

    # Child should have its own denied attributes
    assert_includes child_class.denied_attributes, :email

    # Child should have parent's flags
    assert_equal true, child_class.flag?(:inherited_flag)
  end

  def test_attribute_options
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :field1, only: :create
      allow :field2
    end

    opts = test_class.attribute_options(:field1)
    assert_equal [:create], opts[:only]

    opts2 = test_class.attribute_options(:field2)
    assert_equal({}, opts2)
  end

  def test_allow_with_invalid_options_stores_them
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :field, invalid_option: :value
    end

    opts = test_class.attribute_options(:field)
    assert_equal({ invalid_option: :value }, opts)
  end

  def test_deny_does_not_accept_options
    test_class = Class.new(ActionController::ApplicationParams) do
      deny :field
    end

    # deny doesn't store options, so attribute_options should be empty
    opts = test_class.attribute_options(:field)
    assert_equal({}, opts)
  end

  def test_flag_with_default_value
    test_class = Class.new(ActionController::ApplicationParams) do
      flag :enabled
    end

    assert_equal true, test_class.flag?(:enabled)
  end

  def test_allowed_with_invalid_input
    # Test with nil
    assert !@user_params_class.allowed?(nil)
    # Test with empty string
    assert !@user_params_class.allowed?('')
    # Test with array
    assert !@user_params_class.allowed?([:first_name])
  end

  def test_permitted_attributes_with_invalid_action
    # Should return all permitted attributes regardless of invalid action
    permitted = @user_params_class.permitted_attributes(action: :invalid)
    assert_equal [:first_name, :last_name, :email], permitted
  end

  def test_empty_application_params_class
    empty_class = Class.new(ActionController::ApplicationParams)

    assert_empty empty_class.allowed_attributes
    assert_empty empty_class.denied_attributes
    assert_empty empty_class.permitted_attributes
  end

  def test_multi_level_inheritance
    grandparent_class = Class.new(ActionController::ApplicationParams) do
      allow :name
      flag :inherited, true
    end

    parent_class = Class.new(grandparent_class) do
      allow :email
      flag :parent_flag, 'value'
    end

    child_class = Class.new(parent_class) do
      allow :age
      deny :name
    end

    # Child should inherit from grandparent and parent
    assert_includes child_class.allowed_attributes, :name
    assert_includes child_class.allowed_attributes, :email
    assert_includes child_class.allowed_attributes, :age
    assert_includes child_class.denied_attributes, :name

    assert_equal true, child_class.flag?(:inherited)
    assert_equal 'value', child_class.flag?(:parent_flag)
  end

  def test_attribute_options_for_nonexistent_attribute
    opts = @user_params_class.attribute_options(:nonexistent)
    assert_equal({}, opts)
  end

  def test_flag_for_nonexistent_flag
    assert_nil @user_params_class.flag?(:nonexistent)
  end

  def test_complex_attribute_options
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :field1, only: [:create, :update], custom_option: 'value'
      allow :field2, except: :destroy
    end

    opts1 = test_class.attribute_options(:field1)
    assert_equal [:create, :update], opts1[:only]
    assert_equal 'value', opts1[:custom_option]

    opts2 = test_class.attribute_options(:field2)
    assert_equal [:destroy], opts2[:except]
  end

  def test_metadata_declares_allowed_metadata_keys
    test_class = Class.new(ActionController::ApplicationParams) do
      metadata :ip_address, :role
    end

    assert test_class.metadata_allowed?(:ip_address)
    assert test_class.metadata_allowed?(:role)
    assert !test_class.metadata_allowed?(:unknown)
  end

  def test_current_user_always_allowed
    test_class = Class.new(ActionController::ApplicationParams)

    assert test_class.metadata_allowed?(:current_user)
  end

  def test_metadata_allowed_with_invalid_inputs
    test_class = Class.new(ActionController::ApplicationParams) do
      metadata :ip_address
    end

    # Test with nil
    assert !test_class.metadata_allowed?(nil)
    # Test with empty string
    assert !test_class.metadata_allowed?('')
    # Test with array
    assert !test_class.metadata_allowed?([:ip_address])
    # Test with integer
    assert !test_class.metadata_allowed?(123)
    # Test with hash
    assert !test_class.metadata_allowed?({ip: 'value'})
  end

  def test_transform_applies_transformation
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :email
      transform :email do |value, metadata|
        value&.downcase
      end
    end

    params = { 'email' => 'TEST@EXAMPLE.COM' }
    result = test_class.apply_transformations(params)
    assert_equal 'test@example.com', result['email']
  end

  def test_transform_with_metadata
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :role
      transform :role do |value, metadata|
        metadata[:current_user]&.admin? ? value : 'user'
      end
    end

    params = { 'role' => 'admin' }
    mock_user = Minitest::Mock.new
    mock_user.expect :admin?, true
    metadata = { current_user: mock_user }
    result = test_class.apply_transformations(params, metadata)
    assert_equal 'admin', result['role']
    mock_user.verify

    mock_user2 = Minitest::Mock.new
    mock_user2.expect :admin?, false
    metadata2 = { current_user: mock_user2 }
    result2 = test_class.apply_transformations(params, metadata2)
    assert_equal 'user', result2['role']
    mock_user2.verify
  end

  def test_allow_with_array_option
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :tags, array: true
      allow :name
    end

    permitted = test_class.permitted_attributes
    assert_includes permitted, :name
    assert_includes permitted, { tags: [] }
  end

  def test_allow_with_array_option_and_actions
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :tags, array: true, only: :create
      allow :categories, array: true, except: :update
      allow :name
    end

    # For create action
    permitted_create = test_class.permitted_attributes(action: :create)
    assert_includes permitted_create, :name
    assert_includes permitted_create, { tags: [] }
    assert_includes permitted_create, { categories: [] }

    # For update action
    permitted_update = test_class.permitted_attributes(action: :update)
    assert_includes permitted_update, :name
    refute_includes permitted_update, { tags: [] }
    refute_includes permitted_update, { categories: [] }

    # For show action
    permitted_show = test_class.permitted_attributes(action: :show)
    assert_includes permitted_show, :name
    refute_includes permitted_show, { tags: [] }
    assert_includes permitted_show, { categories: [] }
  end

  def test_permitted_attributes_caching
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :name
    end

    first = test_class.permitted_attributes
    second = test_class.permitted_attributes
    assert_equal first, second
    assert first.object_id == second.object_id  # frozen
  end

  def test_apply_transformations_with_parameters_object
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :email
      transform :email do |value|
        value&.upcase
      end
    end

    # Mock a Parameters-like object
    params_class = Class.new do
      def to_unsafe_h
        { 'email' => 'test' }
      end
    end
    params = params_class.new

    result = test_class.apply_transformations(params)
    assert_equal 'TEST', result['email']
  end

  def test_apply_transformations_with_to_h_method
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :email
      transform :email do |value|
        value&.upcase
      end
    end

    # Mock an object that has to_h but not to_unsafe_h
    params_class = Class.new do
      def to_h
        { 'email' => 'test' }
      end
    end
    params = params_class.new

    result = test_class.apply_transformations(params)
    assert_equal 'TEST', result['email']
  end

  def test_apply_transformations_with_plain_hash
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :email
      transform :email do |value|
        value&.upcase
      end
    end

    params = { 'email' => 'test' }
    result = test_class.apply_transformations(params)
    assert_equal 'TEST', result['email']
  end

  def test_transform_requires_block
    assert_raises ArgumentError do
      Class.new(ActionController::ApplicationParams) do
        transform :email
      end
    end
  end

  def test_apply_transformations_no_transformations
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :name
    end

    params = { 'name' => 'John' }
    result = test_class.apply_transformations(params)
    assert_equal params, result
  end

  def test_transformation_error_handling
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :email
      transform :email do |value, metadata|
        raise "Transformation error"
      end
    end

    params = { 'email' => 'test@example.com' }
    assert_raises(RuntimeError, "Transformation error") do
      test_class.apply_transformations(params)
    end
  end

  def test_apply_transformations_with_nested_hashes
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :user
      transform :user do |value, metadata|
        if value.is_a?(Hash)
          value.merge('processed' => true)
        else
          value
        end
      end
    end

    params = { 'user' => { 'name' => 'John', 'email' => 'john@example.com' } }
    result = test_class.apply_transformations(params)
    expected = { 'user' => { 'name' => 'John', 'email' => 'john@example.com', 'processed' => true } }
    assert_equal expected, result
  end

  def test_apply_transformations_with_arrays
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :tags
      transform :tags do |value, metadata|
        if value.is_a?(Array)
          value.map(&:upcase)
        else
          value
        end
      end
    end

    params = { 'tags' => ['ruby', 'rails'] }
    result = test_class.apply_transformations(params)
    assert_equal ['RUBY', 'RAILS'], result['tags']
  end

  def test_metadata_validation_in_transformations
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :role
      metadata :current_user  # current_user is always allowed, but let's declare it
      transform :role do |value, metadata|
        metadata[:current_user]&.admin? ? value : 'user'
      end
    end

    params = { 'role' => 'admin' }
    mock_user = Minitest::Mock.new
    mock_user.expect :admin?, true
    # current_user is always allowed, so this should work
    result = test_class.apply_transformations(params, current_user: mock_user)
    assert_equal 'admin', result['role']
    mock_user.verify
  end

  def test_complex_action_filtering
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :title
      allow :body
      allow :published, only: [:create, :update]
      allow :archived, only: :archive
      allow :view_count, except: [:create, :edit]
    end

    # Test create action
    permitted_create = test_class.permitted_attributes(action: :create)
    assert_includes permitted_create, :title
    assert_includes permitted_create, :body
    assert_includes permitted_create, :published
    refute_includes permitted_create, :archived
    refute_includes permitted_create, :view_count

    # Test update action
    permitted_update = test_class.permitted_attributes(action: :update)
    assert_includes permitted_update, :title
    assert_includes permitted_update, :body
    assert_includes permitted_update, :published
    refute_includes permitted_update, :archived
    assert_includes permitted_update, :view_count

    # Test archive action
    permitted_archive = test_class.permitted_attributes(action: :archive)
    assert_includes permitted_archive, :title
    assert_includes permitted_archive, :body
    refute_includes permitted_archive, :published
    assert_includes permitted_archive, :archived
    assert_includes permitted_archive, :view_count

    # Test show action (default)
    permitted_show = test_class.permitted_attributes(action: :show)
    assert_includes permitted_show, :title
    assert_includes permitted_show, :body
    refute_includes permitted_show, :published
    refute_includes permitted_show, :archived
    assert_includes permitted_show, :view_count
  end

  def test_permitted_attributes_with_nil_action_and_only_except
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :name
      allow :email
      allow :admin_only, only: :admin
      allow :not_create, except: :create
    end

    # With action: nil, all allowed attributes should be included regardless of only/except
    permitted_nil = test_class.permitted_attributes(action: nil)
    assert_includes permitted_nil, :name
    assert_includes permitted_nil, :email
    assert_includes permitted_nil, :admin_only  # included even with only: :admin
    assert_includes permitted_nil, :not_create  # included even with except: :create

    # Compare with no action (should be same as action: nil)
    permitted_no_action = test_class.permitted_attributes
    assert_equal permitted_nil, permitted_no_action
  end

  def test_allowed_denied_edge_cases
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :name
      deny :admin
    end

    # Test with nil
    assert !test_class.allowed?(nil)
    assert !test_class.denied?(nil)

    # Test with empty string
    assert !test_class.allowed?('')
    assert !test_class.denied?('')

    # Test with integer (doesn't respond to to_sym)
    assert !test_class.allowed?(123)
    assert !test_class.denied?(123)

    # Test with array
    assert !test_class.allowed?([:name])
    assert !test_class.denied?([:admin])

    # Test with hash
    assert !test_class.allowed?({name: 'test'})
    assert !test_class.denied?({admin: true})
  end

  def test_permitted_attributes_caching_detailed
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :name
      allow :email
    end

    # First call should compute and cache
    first_call = test_class.permitted_attributes
    assert_equal [:name, :email], first_call

    # Second call should return cached result
    second_call = test_class.permitted_attributes
    assert_equal first_call, second_call
    assert first_call.object_id == second_call.object_id  # Same object from cache

    # Call with action should cache separately
    action_call = test_class.permitted_attributes(action: :create)
    assert_equal [:name, :email], action_call

    # Call again with same action should return cached
    action_call2 = test_class.permitted_attributes(action: :create)
    assert action_call.object_id == action_call2.object_id
  end

  def test_permitted_attributes_cache_invalidation_on_allow_deny
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :name
    end

    # First call caches
    first_call = test_class.permitted_attributes
    assert_equal [:name], first_call

    # Second call returns cached
    second_call = test_class.permitted_attributes
    assert first_call.object_id == second_call.object_id

    # Call allow again, should clear cache
    test_class.allow :email

    # Now permitted should include email and cache should be new
    third_call = test_class.permitted_attributes
    assert_equal [:name, :email], third_call
    refute_equal first_call.object_id, third_call.object_id  # New cache

    # Call deny, should clear cache
    test_class.deny :name

    fourth_call = test_class.permitted_attributes
    assert_equal [:email], fourth_call
    refute_equal third_call.object_id, fourth_call.object_id
  end

  def test_inheritance_with_transformations_and_metadata
    parent_class = Class.new(ActionController::ApplicationParams) do
      allow :name
      metadata :current_user
      transform :name do |value, metadata|
        value&.capitalize
      end
    end

    child_class = Class.new(parent_class) do
      allow :email
      metadata :ip_address
      transform :email do |value, metadata|
        value&.downcase
      end
    end

    # Child should inherit parent's allowed attributes and metadata
    assert_includes child_class.allowed_attributes, :name
    assert_includes child_class.allowed_attributes, :email
    assert child_class.metadata_allowed?(:current_user)
    assert child_class.metadata_allowed?(:ip_address)

    # Test transformations
    params = { 'name' => 'john', 'email' => 'JOHN@EXAMPLE.COM' }
    result = child_class.apply_transformations(params)
    assert_equal 'John', result['name']
    assert_equal 'john@example.com', result['email']
  end

  def test_inheritance_copies_attribute_options
    parent_class = Class.new(ActionController::ApplicationParams) do
      allow :name, only: :create
      allow :email, except: :update
      allow :tags, array: true, only: [:create, :update]
    end

    child_class = Class.new(parent_class) do
      allow :age
    end

    # Child should inherit parent's attribute options
    assert_equal({ only: [:create] }, child_class.attribute_options(:name))
    assert_equal({ except: [:update] }, child_class.attribute_options(:email))
    assert_equal({ array: true, only: [:create, :update] }, child_class.attribute_options(:tags))
    assert_equal({}, child_class.attribute_options(:age))

    # And permitted attributes should reflect inherited options
    permitted_create = child_class.permitted_attributes(action: :create)
    assert_includes permitted_create, :name
    assert_includes permitted_create, :email
    assert_includes permitted_create, { tags: [] }
    assert_includes permitted_create, :age
  end

  def test_flag_with_various_values
    test_class = Class.new(ActionController::ApplicationParams) do
      flag :enabled, true
      flag :count, 42
      flag :name, 'test'
      flag :data, { key: 'value' }
      flag :disabled, false
    end

    assert_equal true, test_class.flag?(:enabled)
    assert_equal 42, test_class.flag?(:count)
    assert_equal 'test', test_class.flag?(:name)
    assert_equal({ key: 'value' }, test_class.flag?(:data))
    assert_equal false, test_class.flag?(:disabled)
    assert_nil test_class.flag?(:nonexistent)
  end

  def test_flag_with_invalid_inputs
    test_class = Class.new(ActionController::ApplicationParams) do
      flag :enabled, true
    end

    # Test with nil
    assert_nil test_class.flag?(nil)
    # Test with empty string
    assert_nil test_class.flag?('')
    # Test with array
    assert_nil test_class.flag?([:enabled])
    # Test with integer
    assert_nil test_class.flag?(123)
    # Test with hash
    assert_nil test_class.flag?({enabled: true})
  end



  def test_apply_transformations_with_empty_hash
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :email
      transform :email do |value|
        value&.upcase
      end
    end

    result = test_class.apply_transformations({})
    assert_equal({}, result)
  end

  def test_apply_transformations_with_non_hash_params
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :email
      transform :email do |value|
        value&.upcase
      end
    end

    result = test_class.apply_transformations("not a hash")
    assert_equal "not a hash", result
  end

  def test_multiple_transformations
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :email
      allow :name
      transform :email do |value|
        value&.downcase
      end
      transform :name do |value|
        value&.capitalize
      end
    end

    params = { 'email' => 'TEST@EXAMPLE.COM', 'name' => 'john doe' }
    result = test_class.apply_transformations(params)
    assert_equal 'test@example.com', result['email']
    assert_equal 'John doe', result['name']
  end

  def test_redefining_transformation_overwrites
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :email
      transform :email do |value|
        value&.upcase
      end
      # Redefine
      transform :email do |value|
        value&.downcase
      end
    end

    params = { 'email' => 'TEST@EXAMPLE.COM' }
    result = test_class.apply_transformations(params)
    # Should use the last definition
    assert_equal 'test@example.com', result['email']
  end

  def test_deeply_nested_hash_transformations
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :user
      transform :user do |value, metadata|
        if value.is_a?(Hash) && value['profile'].is_a?(Hash)
          value.merge('profile' => value['profile'].merge('processed' => true))
        else
          value
        end
      end
    end

    params = { 'user' => { 'name' => 'John', 'profile' => { 'age' => 30, 'city' => 'NYC' } } }
    result = test_class.apply_transformations(params)
    expected = { 'user' => { 'name' => 'John', 'profile' => { 'age' => 30, 'city' => 'NYC', 'processed' => true } } }
    assert_equal expected, result
  end

  def test_transformation_with_nonexistent_attribute
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :email
      transform :nonexistent do |value|
        'transformed'
      end
    end

    params = { 'email' => 'test@example.com' }
    result = test_class.apply_transformations(params)
    # Should not modify params since transformation key doesn't exist in params
    assert_equal params, result
  end



  def test_transformation_error_handling_detailed
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :email
      transform :email do |value, metadata|
        raise StandardError, "Custom transformation error"
      end
    end

    params = { 'email' => 'test@example.com' }
    assert_raises(StandardError, "Custom transformation error") do
      test_class.apply_transformations(params)
    end
  end

  def test_apply_transformations_preserves_original_nested_hash
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :user
      transform :user do |value, metadata|
        # This attempts to modify the nested hash in place
        if value.is_a?(Hash) && value['profile'].is_a?(Hash)
          value['profile']['modified'] = true
          value
        else
          value
        end
      end
    end

    original_profile = { 'age' => 30, 'city' => 'NYC' }
    params = { 'user' => { 'name' => 'John', 'profile' => original_profile } }

    result = test_class.apply_transformations(params)

    # The original params hash should not be modified
    refute params['user']['profile'].key?('modified')
    # The result should have the modification
    assert_equal true, result['user']['profile']['modified']
  end

  def test_metadata_validation_in_transformations_detailed
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :role
      metadata :current_user, :ip_address
      transform :role do |value, metadata|
        if metadata[:current_user]&.admin? && metadata[:ip_address] == '127.0.0.1'
          'super_admin'
        elsif metadata[:current_user]&.admin?
          'admin'
        else
          'user'
        end
      end
    end

    params = { 'role' => 'requested_role' }

    # Test with admin user and local IP
    mock_user = Minitest::Mock.new
    mock_user.expect :admin?, true
    metadata = { current_user: mock_user, ip_address: '127.0.0.1' }
    result = test_class.apply_transformations(params, metadata)
    assert_equal 'super_admin', result['role']
    mock_user.verify

    # Test with admin user and remote IP
    mock_user2 = Minitest::Mock.new
    mock_user2.expect :admin?, true
    mock_user2.expect :admin?, true  # Called twice in the transformation
    metadata2 = { current_user: mock_user2, ip_address: '192.168.1.1' }
    result2 = test_class.apply_transformations(params, metadata2)
    assert_equal 'admin', result2['role']
    mock_user2.verify

    # Test with non-admin user
    mock_user3 = Minitest::Mock.new
    mock_user3.expect :admin?, false
    mock_user3.expect :admin?, false  # Called twice in the transformation
    metadata3 = { current_user: mock_user3, ip_address: '127.0.0.1' }
    result3 = test_class.apply_transformations(params, metadata3)
    assert_equal 'user', result3['role']
    mock_user3.verify
  end
end
