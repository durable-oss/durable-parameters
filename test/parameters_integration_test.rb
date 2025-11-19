require "test_helper"

class ParametersIntegrationTest < Minitest::Test
  def setup
    ActionController::ParamsRegistry.clear!
  end

  def teardown
    ActionController::ParamsRegistry.clear!
  end

  # Test complete workflow: define params class, register, use
  def test_complete_workflow
    # Step 1: Define params class
    user_params = Class.new(ActionController::ApplicationParams) do
      def self.name
        "UserParams"
      end

      allow :first_name
      allow :last_name
      allow :email
      allow :role, only: :create
      deny :password_digest
      metadata :ip_address
    end

    # Step 2: Register it
    ActionController::ParamsRegistry.register("User", user_params)

    # Step 3: Use it
    params = ActionController::Parameters.new(
      user: {
        first_name: "John",
        last_name: "Doe",
        email: "john@example.com",
        role: "admin",
        password_digest: "secret_hash"
      }
    )

    permitted = params.require(:user).transform_params(
      action: :create,
      current_user: Object.new,
      ip_address: "127.0.0.1"
    )

    assert_equal "John", permitted[:first_name]
    assert_equal "Doe", permitted[:last_name]
    assert_equal "john@example.com", permitted[:email]
    assert_equal "admin", permitted[:role]
    assert_nil permitted[:password_digest]
  end

  # Test multiple models in same request
  def test_multiple_models_in_same_request
    user_params = Class.new(ActionController::ApplicationParams) do
      def self.name
        "UserParams"
      end
      allow :name
    end

    account_params = Class.new(ActionController::ApplicationParams) do
      def self.name
        "AccountParams"
      end
      allow :title
    end

    ActionController::ParamsRegistry.register("User", user_params)
    ActionController::ParamsRegistry.register("Account", account_params)

    params = ActionController::Parameters.new(
      user: {name: "John"},
      account: {title: "My Account"}
    )

    user_permitted = params.require(:user).transform_params
    account_permitted = params.require(:account).transform_params

    assert_equal "John", user_permitted[:name]
    assert_equal "My Account", account_permitted[:title]
  end

  # Test combining permit and transform_params
  def test_combining_permit_and_transform_params
    user_params = Class.new(ActionController::ApplicationParams) do
      def self.name
        "UserParams"
      end
      allow :name
      allow :email
    end

    ActionController::ParamsRegistry.register("User", user_params)

    params = ActionController::Parameters.new(
      user: {name: "John", email: "john@example.com"},
      extra: "value"
    )

    # First permit top-level
    top_level = params.permit(:extra)
    assert_equal "value", top_level[:extra]

    # Then transform nested
    user_permitted = params.require(:user).transform_params
    assert_equal "John", user_permitted[:name]
    assert_equal "john@example.com", user_permitted[:email]
  end

  # Test params class with complex action filters
  def test_complex_action_filtering_scenarios
    params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "ComplexParams"
      end

      # Always allowed
      allow :id
      allow :name

      # Only on create
      allow :created_by, only: :create

      # Only on create and update
      allow :status, only: [:create, :update]

      # Never on destroy
      allow :notes, except: :destroy

      # Never on destroy or delete
      allow :metadata, except: [:destroy, :delete]
    end

    ActionController::ParamsRegistry.register("Complex", params_class)

    # Test create action
    create_params = ActionController::Parameters.new(
      complex: {
        id: 1,
        name: "Test",
        created_by: "admin",
        status: "active",
        notes: "Some notes",
        metadata: {key: "value"}
      }
    )
    create_permitted = create_params.require(:complex).transform_params(action: :create)
    assert_equal 1, create_permitted[:id]
    assert_equal "Test", create_permitted[:name]
    assert_equal "admin", create_permitted[:created_by]
    assert_equal "active", create_permitted[:status]
    assert_equal "Some notes", create_permitted[:notes]

    # Test update action
    update_params = ActionController::Parameters.new(
      complex: {
        id: 1,
        name: "Test",
        created_by: "admin",
        status: "active",
        notes: "Some notes",
        metadata: {key: "value"}
      }
    )
    update_permitted = update_params.require(:complex).transform_params(action: :update)
    assert_equal 1, update_permitted[:id]
    assert_equal "Test", update_permitted[:name]
    assert_nil update_permitted[:created_by]  # only on create
    assert_equal "active", update_permitted[:status]
    assert_equal "Some notes", update_permitted[:notes]

    # Test destroy action
    destroy_params = ActionController::Parameters.new(
      complex: {
        id: 1,
        name: "Test",
        created_by: "admin",
        status: "active",
        notes: "Some notes",
        metadata: {key: "value"}
      }
    )
    destroy_permitted = destroy_params.require(:complex).transform_params(action: :destroy)
    assert_equal 1, destroy_permitted[:id]
    assert_equal "Test", destroy_permitted[:name]
    assert_nil destroy_permitted[:created_by]
    assert_nil destroy_permitted[:status]
    assert_nil destroy_permitted[:notes]  # except destroy
    assert_nil destroy_permitted[:metadata]  # except destroy

    # Test show action
    show_params = ActionController::Parameters.new(
      complex: {
        id: 1,
        name: "Test",
        created_by: "admin",
        status: "active",
        notes: "Some notes",
        metadata: {key: "value"}
      }
    )
    show_permitted = show_params.require(:complex).transform_params(action: :show)
    assert_equal 1, show_permitted[:id]
    assert_equal "Test", show_permitted[:name]
    assert_nil show_permitted[:created_by]
    assert_nil show_permitted[:status]
    assert_equal "Some notes", show_permitted[:notes]
  end

  # Test inheritance chain in real usage
  def test_inheritance_chain_in_usage
    base_params = Class.new(ActionController::ApplicationParams) do
      def self.name
        "BaseParams"
      end
      allow :id
      allow :created_at
    end

    user_params = Class.new(base_params) do
      def self.name
        "UserParams"
      end
      allow :name
      allow :email
      deny :created_at  # Override parent
    end

    admin_params = Class.new(user_params) do
      def self.name
        "AdminParams"
      end
      allow :role
      allow :permissions, array: true
    end

    ActionController::ParamsRegistry.register("Admin", admin_params)

    params = ActionController::Parameters.new(
      admin: {
        id: 1,
        name: "Admin User",
        email: "admin@example.com",
        role: "super_admin",
        permissions: ["all"],
        created_at: Time.now
      }
    )

    permitted = params.require(:admin).transform_params

    assert_equal 1, permitted[:id]
    assert_equal "Admin User", permitted[:name]
    assert_equal "admin@example.com", permitted[:email]
    assert_equal "super_admin", permitted[:role]
    assert_equal ["all"], permitted[:permissions]
    assert_nil permitted[:created_at]  # denied in child
  end

  # Test dynamic additional_attrs based on conditions
  def test_dynamic_additional_attrs
    user_params = Class.new(ActionController::ApplicationParams) do
      def self.name
        "UserParams"
      end
      allow :name
      allow :email
    end

    ActionController::ParamsRegistry.register("User", user_params)

    # Simulate allowing different fields based on user role
    is_admin = true
    additional = is_admin ? [:role, :status] : []

    params = ActionController::Parameters.new(
      user: {
        name: "Test",
        email: "test@example.com",
        role: "admin",
        status: "active"
      }
    )

    permitted = params.require(:user).transform_params(
      additional_attrs: additional
    )

    assert_equal "Test", permitted[:name]
    assert_equal "test@example.com", permitted[:email]
    assert_equal "admin", permitted[:role]
    assert_equal "active", permitted[:status]
  end

  # Test registry lookup with different naming conventions
  def test_registry_with_different_naming_conventions
    params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "UserAccountParams"
      end
      allow :field
    end

    # Test various registration keys
    ActionController::ParamsRegistry.register("UserAccount", params_class)

    params1 = ActionController::Parameters.new(
      user_account: {field: "value1"}
    )
    permitted1 = params1.require(:user_account).transform_params
    assert_equal "value1", permitted1[:field]

    # Clear and try with different registration
    ActionController::ParamsRegistry.clear!
    ActionController::ParamsRegistry.register("user_account", params_class)

    params2 = ActionController::Parameters.new(
      user_account: {field: "value2"}
    )
    permitted2 = params2.require(:user_account).transform_params
    assert_equal "value2", permitted2[:field]
  end

  # Test backward compatibility with permit_by_model
  def test_backward_compatibility_permit_by_model
    user_params = Class.new(ActionController::ApplicationParams) do
      def self.name
        "UserParams"
      end
      allow :name
      allow :email
      allow :status, only: :create
    end

    ActionController::ParamsRegistry.register("User", user_params)

    params = ActionController::Parameters.new(
      name: "John",
      email: "john@example.com",
      status: "active",
      admin: true
    )

    # Old API
    permitted = params.permit_by_model(:user, action: :create)

    assert_equal "John", permitted[:name]
    assert_equal "john@example.com", permitted[:email]
    assert_equal "active", permitted[:status]
    assert_nil permitted[:admin]
  end

  # Test chaining with slice
  def test_chaining_with_slice
    user_params = Class.new(ActionController::ApplicationParams) do
      def self.name
        "UserParams"
      end
      allow :name
      allow :email
    end

    ActionController::ParamsRegistry.register("User", user_params)

    params = ActionController::Parameters.new(
      user: {
        name: "John",
        email: "john@example.com",
        age: 30
      }
    )

    # Slice then transform
    sliced = params.require(:user).slice(:name, :email, :age)
    permitted = sliced.transform_params

    assert_equal "John", permitted[:name]
    assert_equal "john@example.com", permitted[:email]
    assert_nil permitted[:age]  # not allowed
  end

  # Test with dup
  def test_transform_params_with_dup
    user_params = Class.new(ActionController::ApplicationParams) do
      def self.name
        "UserParams"
      end
      allow :name
    end

    ActionController::ParamsRegistry.register("User", user_params)

    params = ActionController::Parameters.new(
      user: {name: "John"}
    )

    user_params = params.require(:user)
    duped = user_params.dup

    # Both should work
    permitted1 = user_params.transform_params
    permitted2 = duped.transform_params

    assert_equal "John", permitted1[:name]
    assert_equal "John", permitted2[:name]
  end

  # Test multiple registrations for same model (last wins)
  def test_multiple_registrations_last_wins
    first_params = Class.new(ActionController::ApplicationParams) do
      def self.name
        "FirstParams"
      end
      allow :field1
    end

    second_params = Class.new(ActionController::ApplicationParams) do
      def self.name
        "SecondParams"
      end
      allow :field2
    end

    ActionController::ParamsRegistry.register("Test", first_params)
    ActionController::ParamsRegistry.register("Test", second_params)

    params = ActionController::Parameters.new(
      test: {
        field1: "value1",
        field2: "value2"
      }
    )

    permitted = params.require(:test).transform_params

    # Should use second registration
    assert_nil permitted[:field1]
    assert_equal "value2", permitted[:field2]
  end

  # Test metadata in inheritance
  def test_metadata_in_inheritance_chain
    parent_params = Class.new(ActionController::ApplicationParams) do
      def self.name
        "ParentParams"
      end
      allow :name
      metadata :parent_meta
    end

    child_params = Class.new(parent_params) do
      def self.name
        "ChildParams"
      end
      allow :email
      metadata :child_meta
    end

    ActionController::ParamsRegistry.register("Child", child_params)

    params = ActionController::Parameters.new(
      child: {
        name: "Test",
        email: "test@example.com"
      }
    )

    # Should accept both parent and child metadata
    permitted = params.require(:child).transform_params(
      parent_meta: "parent_value",
      child_meta: "child_value",
      current_user: Object.new
    )

    assert_equal "Test", permitted[:name]
    assert_equal "test@example.com", permitted[:email]
  end

  # Test flags don't affect filtering
  def test_flags_dont_affect_filtering
    params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "FlaggedParams"
      end
      allow :name
      flag :some_flag, true
      flag :another_flag, "value"
    end

    ActionController::ParamsRegistry.register("Flagged", params_class)

    params = ActionController::Parameters.new(
      flagged: {
        name: "Test",
        some_flag: "should not appear",
        another_flag: "should not appear"
      }
    )

    permitted = params.require(:flagged).transform_params

    assert_equal "Test", permitted[:name]
    assert_nil permitted[:some_flag]
    assert_nil permitted[:another_flag]
  end

  # Test empty registry
  def test_empty_registry_all_transforms_return_empty
    params = ActionController::Parameters.new(
      anything: {field: "value"}
    )

    permitted = params.require(:anything).transform_params

    assert permitted.permitted?
    assert_nil permitted[:field]
  end

  # Test registry.registered_models
  def test_registry_tracking
    user_params = Class.new(ActionController::ApplicationParams) do
      def self.name
        "UserParams"
      end
      allow :name
    end

    account_params = Class.new(ActionController::ApplicationParams) do
      def self.name
        "AccountParams"
      end
      allow :title
    end

    ActionController::ParamsRegistry.register("User", user_params)
    ActionController::ParamsRegistry.register("Account", account_params)

    models = ActionController::ParamsRegistry.registered_models
    assert_equal 2, models.length
    assert_includes models, "user"
    assert_includes models, "account"

    # Both should work
    user_p = ActionController::Parameters.new(user: {name: "John"})
    account_p = ActionController::Parameters.new(account: {title: "My Account"})

    assert_equal "John", user_p.require(:user).transform_params[:name]
    assert_equal "My Account", account_p.require(:account).transform_params[:title]
  end
end
