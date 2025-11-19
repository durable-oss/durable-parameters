require "test_helper"

class ApplicationParamsArrayTest < Minitest::Test
  def setup
    ActionController::ParamsRegistry.clear!
  end

  def teardown
    ActionController::ParamsRegistry.clear!
  end

  # Test basic array support
  def test_allow_array_attribute
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :tags, array: true
    end

    attrs = test_class.permitted_attributes
    assert_equal 1, attrs.length
    assert_equal({tags: []}, attrs.first)
  end

  # Test scalar and array attributes together
  def test_mixed_scalar_and_array_attributes
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :name
      allow :tags, array: true
      allow :email
      allow :categories, array: true
    end

    attrs = test_class.permitted_attributes
    assert_equal 4, attrs.length
    assert attrs.include?(:name)
    assert attrs.include?(:email)
    assert attrs.include?({tags: []})
    assert attrs.include?({categories: []})
  end

  # Test array with action filters
  def test_array_with_only_filter
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :tags, array: true, only: :create
    end

    # With create action
    attrs = test_class.permitted_attributes(action: :create)
    assert_equal 1, attrs.length
    assert_equal({tags: []}, attrs.first)

    # With update action
    attrs = test_class.permitted_attributes(action: :update)
    assert_equal 0, attrs.length
  end

  # Test array with except filter
  def test_array_with_except_filter
    test_class = Class.new(ActionController::ApplicationParams) do
      allow :tags, array: true, except: :destroy
    end

    # With create action
    attrs = test_class.permitted_attributes(action: :create)
    assert_equal 1, attrs.length
    assert_equal({tags: []}, attrs.first)

    # With destroy action
    attrs = test_class.permitted_attributes(action: :destroy)
    assert_equal 0, attrs.length
  end

  # Test array inheritance
  def test_array_inheritance
    parent_class = Class.new(ActionController::ApplicationParams) do
      allow :tags, array: true
    end

    child_class = Class.new(parent_class) do
      allow :categories, array: true
    end

    attrs = child_class.permitted_attributes
    assert_equal 2, attrs.length
    assert attrs.include?({tags: []})
    assert attrs.include?({categories: []})
  end

  # Test array can be denied in child class
  def test_deny_inherited_array
    parent_class = Class.new(ActionController::ApplicationParams) do
      allow :tags, array: true
      allow :name
    end

    child_class = Class.new(parent_class) do
      deny :tags
      allow :email
    end

    attrs = child_class.permitted_attributes
    assert_equal 2, attrs.length
    assert attrs.include?(:name)
    assert attrs.include?(:email)
    assert !attrs.include?({tags: []})
  end

  # Test transform_params with array attributes
  def test_transform_params_with_array
    test_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "ArticleParams"
      end
      allow :title
      allow :tags, array: true
    end

    ActionController::ParamsRegistry.register("Article", test_class)

    params = ActionController::Parameters.new(
      article: {
        title: "Test Article",
        tags: ["ruby", "rails", "testing"],
        body: "Should be filtered out"
      }
    )

    permitted = params.require(:article).transform_params

    assert permitted.permitted?
    assert_equal "Test Article", permitted[:title]
    assert_equal ["ruby", "rails", "testing"], permitted[:tags]
    assert_nil permitted[:body]
  end

  # Test transform_params with empty array
  def test_transform_params_with_empty_array
    test_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "ArticleParams"
      end
      allow :title
      allow :tags, array: true
    end

    ActionController::ParamsRegistry.register("Article", test_class)

    params = ActionController::Parameters.new(
      article: {
        title: "Test Article",
        tags: []
      }
    )

    permitted = params.require(:article).transform_params

    assert permitted.permitted?
    assert_equal "Test Article", permitted[:title]
    assert_equal [], permitted[:tags]
  end

  # Test transform_params filters arrays with non-scalar elements
  def test_transform_params_filters_non_scalar_array_elements
    test_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "ArticleParams"
      end
      allow :title
      allow :tags, array: true
    end

    ActionController::ParamsRegistry.register("Article", test_class)

    params = ActionController::Parameters.new(
      article: {
        title: "Test Article",
        tags: ["valid", {invalid: "hash"}, "also_valid", ["nested", "array"]]
      }
    )

    permitted = params.require(:article).transform_params

    assert permitted.permitted?
    assert_equal "Test Article", permitted[:title]
    # Strong parameters filters out entire array if it contains non-scalar elements
    assert_nil permitted[:tags]
  end

  # Test array attribute with additional_attrs
  def test_array_with_additional_attrs
    test_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "ArticleParams"
      end
      allow :title
    end

    ActionController::ParamsRegistry.register("Article", test_class)

    params = ActionController::Parameters.new(
      article: {
        title: "Test Article",
        tags: ["ruby", "rails"]
      }
    )

    # Add tags as additional attribute with array syntax
    permitted = params.require(:article).transform_params(additional_attrs: [{tags: []}])

    assert permitted.permitted?
    assert_equal "Test Article", permitted[:title]
    assert_equal ["ruby", "rails"], permitted[:tags]
  end

  # Test multiple array attributes
  def test_multiple_array_attributes
    test_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "ArticleParams"
      end
      allow :title
      allow :tags, array: true
      allow :categories, array: true
      allow :author_ids, array: true
    end

    ActionController::ParamsRegistry.register("Article", test_class)

    params = ActionController::Parameters.new(
      article: {
        title: "Test Article",
        tags: ["ruby", "rails"],
        categories: ["tech", "programming"],
        author_ids: [1, 2, 3]
      }
    )

    permitted = params.require(:article).transform_params

    assert permitted.permitted?
    assert_equal "Test Article", permitted[:title]
    assert_equal ["ruby", "rails"], permitted[:tags]
    assert_equal ["tech", "programming"], permitted[:categories]
    assert_equal [1, 2, 3], permitted[:author_ids]
  end
end
