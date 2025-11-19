require 'test_helper'

class TransformParamsTest < Minitest::Test
  def setup
    ActionController::ParamsRegistry.clear!

    @user_params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'UserParams'
      end

      allow :first_name
      allow :last_name
      allow :email
    end

    ActionController::ParamsRegistry.register('User', @user_params_class)
  end

  def teardown
    ActionController::ParamsRegistry.clear!
  end

  def test_transform_params_with_auto_inferred_class
    params = ActionController::Parameters.new(
      user: {
        first_name: 'John',
        last_name: 'Doe',
        email: 'john@example.com',
        is_admin: true
      }
    )

    permitted = params.require(:user).transform_params()

    assert_equal 'John', permitted[:first_name]
    assert_equal 'Doe', permitted[:last_name]
    assert_equal 'john@example.com', permitted[:email]
    assert_nil permitted[:is_admin]
    assert permitted.permitted?
  end

  def test_transform_params_with_explicit_params_class
    params = ActionController::Parameters.new(
      user: {
        first_name: 'John',
        last_name: 'Doe',
        email: 'john@example.com',
        is_admin: true
      }
    )

    permitted = params.require(:user).transform_params(@user_params_class)

    assert_equal 'John', permitted[:first_name]
    assert_equal 'Doe', permitted[:last_name]
    assert_equal 'john@example.com', permitted[:email]
    assert_nil permitted[:is_admin]
    assert permitted.permitted?
  end

  def test_transform_params_with_current_user_always_allowed
    params = ActionController::Parameters.new(
      user: {
        first_name: 'Jane',
        last_name: 'Smith',
        email: 'jane@example.com'
      }
    )

    current_user = Object.new # Mock user object

    # current_user is always allowed without needing to be declared
    permitted = params.require(:user).transform_params(current_user: current_user)

    assert_equal 'Jane', permitted[:first_name]
    assert_equal 'Smith', permitted[:last_name]
    assert_equal 'jane@example.com', permitted[:email]
  end

  def test_transform_params_with_declared_metadata
    test_params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'AccountParams'
      end

      allow :first_name
      allow :last_name
      allow :email

      # Declare allowed metadata
      metadata :ip_address, :role
    end

    ActionController::ParamsRegistry.register('Account', test_params_class)

    params = ActionController::Parameters.new(
      account: {
        first_name: 'Jane',
        last_name: 'Smith',
        email: 'jane@example.com'
      }
    )

    # Can pass declared metadata along with current_user
    permitted = params.require(:account).transform_params(
      current_user: Object.new,
      ip_address: '127.0.0.1',
      role: :admin
    )

    assert_equal 'Jane', permitted[:first_name]
    assert_equal 'Smith', permitted[:last_name]
    assert_equal 'jane@example.com', permitted[:email]
  end

  def test_transform_params_raises_on_undeclared_metadata
    params = ActionController::Parameters.new(
      user: {
        first_name: 'Jane',
        last_name: 'Smith',
        email: 'jane@example.com'
      }
    )

    # Should raise error when passing metadata that hasn't been declared
    error = assert_raises(ArgumentError) do
      params.require(:user).transform_params(
        current_user: Object.new,
        ip_address: '127.0.0.1'  # Not declared in UserParams
      )
    end

    assert_includes error.message, 'ip_address'
    assert_includes error.message, 'metadata :ip_address'
  end

  def test_transform_params_with_additional_attrs
    params = ActionController::Parameters.new(
      user: {
        first_name: 'John',
        last_name: 'Doe',
        email: 'john@example.com',
        age: 30
      }
    )

    permitted = params.require(:user).transform_params(additional_attrs: [:age])

    assert_equal 'John', permitted[:first_name]
    assert_equal 30, permitted[:age]
  end

  def test_transform_params_with_action_filter
    test_params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'PostParams'
      end

      allow :title
      allow :body
      allow :published, only: :create
    end

    ActionController::ParamsRegistry.register('Post', test_params_class)

    # With action: :create, published should be permitted
    params = ActionController::Parameters.new(
      post: {
        title: 'Test',
        body: 'Content',
        published: true
      }
    )
    permitted = params.require(:post).transform_params(action: :create)
    assert_equal 'Test', permitted[:title]
    assert_equal 'Content', permitted[:body]
    assert_equal true, permitted[:published]

    # With action: :update, published should not be permitted
    params2 = ActionController::Parameters.new(
      post: {
        title: 'Test',
        body: 'Content',
        published: true
      }
    )
    permitted2 = params2.require(:post).transform_params(action: :update)
    assert_equal 'Test', permitted2[:title]
    assert_equal 'Content', permitted2[:body]
    assert_nil permitted2[:published]
  end

  def test_transform_params_with_unregistered_model
    params = ActionController::Parameters.new(
      nonexistent: {
        name: 'Test',
        value: 123
      }
    )

    permitted = params.require(:nonexistent).transform_params()

    # Should return empty permitted params
    assert permitted.permitted?
    assert_nil permitted[:name]
    assert_nil permitted[:value]
  end

  # Test backwards compatibility with permit_by_model
  def test_permit_by_model_still_works_for_backwards_compatibility
    params = ActionController::Parameters.new(
      first_name: 'John',
      last_name: 'Doe',
      email: 'john@example.com',
      is_admin: true
    )

    permitted = params.permit_by_model(:user)

    assert_equal 'John', permitted[:first_name]
    assert_equal 'Doe', permitted[:last_name]
    assert_equal 'john@example.com', permitted[:email]
    assert_nil permitted[:is_admin]
    assert permitted.permitted?
  end
end
