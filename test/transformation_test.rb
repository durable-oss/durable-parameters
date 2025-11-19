require 'test_helper'

class TransformationTest < Minitest::Test
  def setup
    ActionController::ParamsRegistry.clear!
  end

  def teardown
    ActionController::ParamsRegistry.clear!
  end

  # Test basic transformation
  def test_basic_transformation
    params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'UserParams'
      end

      allow :email
      allow :name

      transform :email do |value, metadata|
        value&.downcase&.strip
      end
    end

    ActionController::ParamsRegistry.register(:user, params_class)

    params = ActionController::Parameters.new(
      user: {
        email: '  TEST@EXAMPLE.COM  ',
        name: 'John Doe'
      }
    )

    result = params.require(:user).transform_params

    assert_equal 'test@example.com', result[:email]
    assert_equal 'John Doe', result[:name]
  end

  # Test transformation with metadata
  def test_transformation_with_metadata
    params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'PostParams'
      end

      allow :title
      allow :published

      metadata :current_user

      transform :published do |value, metadata|
        # Only admins can publish
        metadata[:current_user]&.fetch(:admin, false) ? value : false
      end
    end

    ActionController::ParamsRegistry.register(:post, params_class)

    # Test with admin user
    admin_user = { admin: true }
    params1 = ActionController::Parameters.new(
      post: {
        title: 'My Post',
        published: true
      }
    )

    result1 = params1.require(:post).transform_params(current_user: admin_user)
    assert_equal true, result1[:published]

    # Test with non-admin user
    regular_user = { admin: false }
    params2 = ActionController::Parameters.new(
      post: {
        title: 'My Post',
        published: true
      }
    )

    result2 = params2.require(:post).transform_params(current_user: regular_user)
    assert_equal false, result2[:published]
  end

  # Test multiple transformations
  def test_multiple_transformations
    params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'AccountParams'
      end

      allow :email
      allow :username
      allow :bio

      transform :email do |value, metadata|
        value&.downcase&.strip
      end

      transform :username do |value, metadata|
        value&.strip&.gsub(/\s+/, '_')
      end

      transform :bio do |value, metadata|
        value&.strip&.slice(0, 200)
      end
    end

    ActionController::ParamsRegistry.register(:account, params_class)

    params = ActionController::Parameters.new(
      account: {
        email: '  Admin@Example.COM  ',
        username: '  john   doe  ',
        bio: 'A' * 300
      }
    )

    result = params.require(:account).transform_params

    assert_equal 'admin@example.com', result[:email]
    assert_equal 'john_doe', result[:username]  # gsub(/\s+/, '_') replaces consecutive spaces with single underscore
    assert_equal 200, result[:bio].length
  end

  # Test transformation with nil value
  def test_transformation_with_nil_value
    params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'UserParams'
      end

      allow :email

      transform :email do |value, metadata|
        value&.downcase
      end
    end

    ActionController::ParamsRegistry.register(:user, params_class)

    params = ActionController::Parameters.new(
      user: {
        email: nil
      }
    )

    result = params.require(:user).transform_params

    assert_nil result[:email]
  end

  # Test transformation doesn't affect denied attributes
  def test_transformation_ignores_denied_attributes
    params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'UserParams'
      end

      allow :email
      deny :role

      transform :email do |value, metadata|
        value&.downcase
      end

      transform :role do |value, metadata|
        'admin'  # This should never be applied since role is denied
      end
    end

    ActionController::ParamsRegistry.register(:user, params_class)

    params = ActionController::Parameters.new(
      user: {
        email: 'TEST@EXAMPLE.COM',
        role: 'user'
      }
    )

    result = params.require(:user).transform_params

    assert_equal 'test@example.com', result[:email]
    assert_nil result[:role]  # Denied attributes are filtered out
  end

  # Test transformation with action-specific metadata
  def test_transformation_with_action_metadata
    params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'ArticleParams'
      end

      allow :slug

      transform :slug do |value, metadata|
        if metadata[:action] == :create
          # Auto-generate slug on create
          value || "article-#{Time.now.to_i}"
        else
          # Keep existing slug on update
          value
        end
      end
    end

    ActionController::ParamsRegistry.register(:article, params_class)

    # Create action with no slug
    params1 = ActionController::Parameters.new(article: { slug: nil })
    result1 = params1.require(:article).transform_params(action: :create)
    assert_match(/^article-\d+$/, result1[:slug])

    # Update action with slug
    params2 = ActionController::Parameters.new(article: { slug: 'my-slug' })
    result2 = params2.require(:article).transform_params(action: :update)
    assert_equal 'my-slug', result2[:slug]
  end

  # Test transformation inheritance
  def test_transformation_inheritance
    base_params = Class.new(ActionController::ApplicationParams) do
      def self.name
        'BaseParams'
      end

      allow :email

      transform :email do |value, metadata|
        value&.downcase
      end
    end

    child_params = Class.new(base_params) do
      def self.name
        'ChildParams'
      end

      allow :name

      transform :name do |value, metadata|
        value&.upcase
      end
    end

    ActionController::ParamsRegistry.register(:child, child_params)

    params = ActionController::Parameters.new(
      child: {
        email: 'TEST@EXAMPLE.COM',
        name: 'john doe'
      }
    )

    result = params.require(:child).transform_params

    assert_equal 'test@example.com', result[:email]  # From parent
    assert_equal 'JOHN DOE', result[:name]  # From child
  end

  # Test transformation without params class (should not raise)
  def test_transformation_without_params_class
    params = ActionController::Parameters.new(
      user: {
        email: 'TEST@EXAMPLE.COM'
      }
    )

    result = params.require(:user).transform_params

    # Should return empty permitted params (no transformation or filtering)
    assert result.permitted?
    assert_nil result[:email]
  end

  # Test transformation with complex metadata
  def test_transformation_with_complex_metadata
    params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'CommentParams'
      end

      allow :content
      allow :author_name

      metadata :current_user, :ip_address

      transform :author_name do |value, metadata|
        if metadata[:current_user]
          metadata[:current_user][:name]
        else
          "Anonymous (#{metadata[:ip_address]})"
        end
      end
    end

    ActionController::ParamsRegistry.register(:comment, params_class)

    # With current_user
    params1 = ActionController::Parameters.new(
      comment: {
        content: 'Great post!',
        author_name: 'ignored'
      }
    )

    result1 = params1.require(:comment).transform_params(
      current_user: { name: 'John Doe' },
      ip_address: '192.168.1.1'
    )

    assert_equal 'John Doe', result1[:author_name]

    # Without current_user
    params2 = ActionController::Parameters.new(
      comment: {
        content: 'Great post!',
        author_name: 'ignored'
      }
    )

    result2 = params2.require(:comment).transform_params(
      ip_address: '192.168.1.100'
    )

    assert_equal 'Anonymous (192.168.1.100)', result2[:author_name]
  end

  # Test that transformations are applied before filtering
  def test_transformations_applied_before_filtering
    params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'ProductParams'
      end

      allow :price

      # Transform price from cents to dollars
      transform :price do |value, metadata|
        value.is_a?(Numeric) ? value / 100.0 : value
      end
    end

    ActionController::ParamsRegistry.register(:product, params_class)

    params = ActionController::Parameters.new(
      product: {
        price: 1999,  # 19.99 in cents
        other: 'ignored'
      }
    )

    result = params.require(:product).transform_params

    assert_equal 19.99, result[:price]
    assert_nil result[:other]  # Not allowed
  end
end
