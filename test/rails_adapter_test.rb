# frozen_string_literal: true

require "test_helper"

class RailsAdapterTest < Minitest::Test
  def setup
    # Create test params classes
    @user_params_class = Class.new(ActionController::ApplicationParams) do
      def self.permitted_attributes(action: nil)
        [:name, :email, :age]
      end

      def self.metadata_allowed?(key)
        [:current_user].include?(key)
      end
    end

    @post_params_class = Class.new(ActionController::ApplicationParams) do
      def self.permitted_attributes(action: nil)
        [:title, :content, :tags]
      end

      def self.metadata_allowed?(key)
        [:current_user, :published_at].include?(key)
      end
    end

    # Register params classes
    ActionController::ParamsRegistry.register(:user, @user_params_class)
    ActionController::ParamsRegistry.register(:post, @post_params_class)
  end

  def teardown
    # Clean up registry
    ActionController::ParamsRegistry.instance_variable_get(:@registry).clear
  end

  # Test ParametersExtension module
  def test_transform_params_with_explicit_params_class
    params = ActionController::Parameters.new(user: {name: "John", email: "john@example.com", admin: true})
    user_params = params.require(:user)

    result = user_params.transform_params(@user_params_class)

    assert result.permitted?
    assert_equal "John", result[:name]
    assert_equal "john@example.com", result[:email]
    refute result.key?(:admin)
  end

  def test_transform_params_with_inferred_params_class
    params = ActionController::Parameters.new(user: {name: "John", email: "john@example.com", admin: true})
    user_params = params.require(:user) # This sets required_key

    result = user_params.transform_params

    assert result.permitted?
    assert_equal "John", result[:name]
    assert_equal "john@example.com", result[:email]
    refute result.key?(:admin)
  end

  def test_transform_params_with_nil_params_class
    params = ActionController::Parameters.new(user: {name: "John"})
    user_params = params.require(:user)

    result = user_params.transform_params(nil)

    assert result.permitted?
    assert result.empty?
  end

  def test_transform_params_with_no_required_key_and_no_explicit_class
    params = ActionController::Parameters.new(name: "John")

    result = params.transform_params

    assert result.permitted?
    assert_equal 0, result.keys.length
  end

  def test_transform_params_with_action
    create_params_class = Class.new(ActionController::ApplicationParams) do
      def self.permitted_attributes(action: nil)
        case action
        when :create
          [:name, :email]
        when :update
          [:name, :email, :age]
        else
          []
        end
      end
    end

    params = ActionController::Parameters.new(user: {name: "John", email: "john@example.com", age: 30})
    user_params = params.require(:user)

    result = user_params.transform_params(create_params_class, action: :create)

    assert result.permitted?
    assert_equal "John", result[:name]
    assert_equal "john@example.com", result[:email]
    refute result.key?(:age)
  end

  def test_transform_params_with_additional_attrs
    params = ActionController::Parameters.new(user: {name: "John", email: "john@example.com"})
    user_params = params.require(:user)

    result = user_params.transform_params(@user_params_class, additional_attrs: [:phone])

    assert result.permitted?
    assert_equal "John", result[:name]
    assert_equal "john@example.com", result[:email]
    # Note: additional_attrs are added to permitted, but since they're not in the original params, they won't appear
  end

  def test_transform_params_with_valid_metadata
    params = ActionController::Parameters.new(user: {name: "John"})
    user_params = params.require(:user)

    result = user_params.transform_params(@user_params_class, current_user: "admin")

    assert result.permitted?
    assert_equal "John", result[:name]
  end

  def test_transform_params_with_invalid_metadata_raises_error
    params = ActionController::Parameters.new(user: {name: "John"})
    user_params = params.require(:user)

    error = assert_raises(ArgumentError) do
      user_params.transform_params(@user_params_class, invalid_key: "value")
    end

    assert_includes error.message, "Metadata key(s) :invalid_key not allowed"
    assert_includes error.message, "AnonymousParamsClass"
  end

  def test_permit_by_model
    params = ActionController::Parameters.new(user: {name: "John", email: "john@example.com", admin: true})
    user_params = params.require(:user)

    result = user_params.permit_by_model(:user)

    assert result.permitted?
    assert_equal "John", result[:name]
    assert_equal "john@example.com", result[:email]
    refute result.key?(:admin)
  end

  def test_permit_by_model_with_action
    params = ActionController::Parameters.new(user: {name: "John", email: "john@example.com", age: 30})
    user_params = params.require(:user)

    result = user_params.permit_by_model(:user, action: :update)

    assert result.permitted?
    assert_equal "John", result[:name]
    assert_equal "john@example.com", result[:email]
    assert_equal 30, result[:age]
  end

  def test_permit_by_model_with_additional_attrs
    params = ActionController::Parameters.new(user: {name: "John", email: "john@example.com"})
    user_params = params.require(:user)

    result = user_params.permit_by_model(:user, additional_attrs: [:phone])

    assert result.permitted?
    assert_equal "John", result[:name]
    assert_equal "john@example.com", result[:email]
  end

  def test_require_sets_required_key
    params = ActionController::Parameters.new(user: {name: "John"})

    required_params = params.require(:user)

    assert_equal :user, required_params.required_key
  end

  def test_slice_preserves_required_key
    params = ActionController::Parameters.new(user: {name: "John", email: "john@example.com"})
    params = params.require(:user)

    sliced = params.slice(:name)

    assert_equal :user, sliced.required_key
    assert_equal "John", sliced[:name]
    refute sliced.key?(:email)
  end

  # Test Rails Parameters class
  def test_rails_parameters_indifferent_access_with_symbol_key
    params = StrongParameters::Adapters::Rails::Parameters.new({"name" => "John", "email" => "john@example.com"})

    assert_equal "John", params[:name]
    assert_equal "John", params["name"]
    assert_equal "john@example.com", params[:email]
    assert_equal "john@example.com", params["email"]
  end

  def test_rails_parameters_indifferent_access_assignment
    params = StrongParameters::Adapters::Rails::Parameters.new

    params[:name] = "John"
    params["email"] = "john@example.com"

    assert_equal "John", params["name"]
    assert_equal "john@example.com", params[:email]
  end

  def test_rails_parameters_has_key_indifferent
    params = StrongParameters::Adapters::Rails::Parameters.new({"name" => "John"})

    assert params.has_key?(:name)
    assert params.has_key?("name")
    assert params.key?(:name)
    assert params.key?("name")
    assert params.include?(:name)
    assert params.include?("name")
  end

  def test_rails_parameters_delete_indifferent
    params = StrongParameters::Adapters::Rails::Parameters.new({"name" => "John", "email" => "john@example.com"})

    deleted = params.delete(:name)

    assert_equal "John", deleted
    refute params.has_key?(:name)
    refute params.has_key?("name")
    assert params.has_key?(:email)
  end

  def test_rails_parameters_fetch_indifferent
    params = StrongParameters::Adapters::Rails::Parameters.new({"name" => "John"})

    assert_equal "John", params.fetch(:name)
    assert_equal "John", params.fetch("name")
  end

  def test_rails_parameters_permits_action_dispatch_uploaded_file
    uploaded_file = ActionDispatch::Http::UploadedFile.new(
      tempfile: Tempfile.new,
      filename: "test.jpg",
      type: "image/jpeg"
    )

    params = StrongParameters::Adapters::Rails::Parameters.new({"file" => uploaded_file})

    assert params.permit(:file)
  end

  def test_rails_parameters_permits_rack_uploaded_file
    # Create a mock Rack uploaded file
    uploaded_file = Rack::Test::UploadedFile.new(Tempfile.new, "image/jpeg")

    params = StrongParameters::Adapters::Rails::Parameters.new({"file" => uploaded_file})

    assert params.permit(:file)
  end

  def test_rails_parameters_initializes_with_hash_with_indifferent_access
    hash = {name: "John", email: "john@example.com"}.with_indifferent_access
    params = StrongParameters::Adapters::Rails::Parameters.new(hash)

    assert_equal "John", params[:name]
    assert_equal "John", params["name"]
  end

  def test_rails_parameters_initializes_with_nil
    params = StrongParameters::Adapters::Rails::Parameters.new(nil)

    assert_empty params
  end



  # Test ActiveModel::ForbiddenAttributesProtection
  if defined?(ActiveModel)
    class TestModel
      include ActiveModel::Model
      include StrongParameters::Adapters::Rails::ActiveModel::ForbiddenAttributesProtection

      attr_accessor :name, :email

      def initialize(attributes = {})
        super
        sanitize_for_mass_assignment(attributes)
      end
    end

    def test_active_model_forbidden_attributes_protection_permits_permitted_params
      permitted_params = ActionController::Parameters.new(name: "John", email: "john@example.com").permit(:name, :email)

      model = TestModel.new(permitted_params)

      assert_equal "John", model.name
      assert_equal "john@example.com", model.email
    end

    def test_active_model_forbidden_attributes_protection_raises_on_unpermitted_params
      unpermitted_params = ActionController::Parameters.new(name: "John", admin: true)

      error = assert_raises(StrongParameters::Core::ForbiddenAttributes) do
        TestModel.new(unpermitted_params)
      end

      assert_instance_of StrongParameters::Core::ForbiddenAttributes, error
    end

    def test_active_model_forbidden_attributes_protection_allows_non_parameters_hash
      attributes = {name: "John", email: "john@example.com"}

      model = TestModel.new(attributes)

      assert_equal "John", model.name
      assert_equal "john@example.com", model.email
    end
  end

  # Test setup! method
  def test_setup_extends_action_controller_parameters
    # The setup! is already called in test_helper.rb, so ActionController::Parameters should be extended
    assert ActionController::Parameters.include?(StrongParameters::Adapters::Rails::ParametersExtension)
  end

  def test_setup_adds_application_params_to_action_controller
    assert_equal StrongParameters::Core::ApplicationParams, ActionController::ApplicationParams
  end

  def test_setup_adds_params_registry_to_action_controller
    assert_equal StrongParameters::Core::ParamsRegistry, ActionController::ParamsRegistry
  end

  def test_setup_adds_forbidden_attributes_to_active_model
    skip "ActiveModel not loaded in test environment" unless defined?(ActiveModel)
    assert_equal StrongParameters::Core::ForbiddenAttributes, ActiveModel::ForbiddenAttributes
  end

  def test_setup_adds_forbidden_attributes_protection_to_active_model
    skip "ActiveModel not loaded in test environment" unless defined?(ActiveModel)
    assert_equal StrongParameters::Adapters::Rails::ActiveModel::ForbiddenAttributesProtection, ActiveModel::ForbiddenAttributesProtection
  end
end

# Test ActionController::StrongParameters concern
class TestController < ActionController::Base
  include StrongParameters::Adapters::Rails::ActionController::StrongParameters

  def test_action
    render plain: "OK"
  end

  def test_params_access
    user_params = params.require(:user).transform_params(@user_params_class)
    render plain: user_params[:name]
  end
end

class RailsAdapterControllerTest < ActionController::TestCase
  tests TestController

  setup do
    @routes = Rails.application.routes
    Rails.application.routes.draw do
      post "test_action" => "test#test_action"
    end
  end

  teardown do
    Rails.application.routes.clear!
    Rails.application.routes.draw do
      post "people/create" => "people#create"
      post "people/create_with_permit" => "people#create_with_permit"
      post "books/create" => "books#create"
    end
  end

  def test_action_controller_params_method_returns_rails_parameters
    post :test_action, params: {user: {name: "John"}}

    assert_instance_of StrongParameters::Adapters::Rails::Parameters, @controller.params
    assert_equal "John", @controller.params[:user][:name]
  end

  def test_action_controller_params_assignment
    @controller.params = {user: {name: "Jane"}}

    assert_instance_of StrongParameters::Adapters::Rails::Parameters, @controller.params
    assert_equal "Jane", @controller.params[:user][:name]
  end

  def test_action_controller_parameter_missing_exception_handling
    # This test would require setting up a controller that raises ParameterMissing
    # For now, we'll skip this as it's tested elsewhere
    skip "ParameterMissing exception handling is tested in action_controller_required_params_test.rb"
  end
end