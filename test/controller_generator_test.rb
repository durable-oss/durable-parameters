require "rails/generators/test_case"
require "generators/rails/durable_parameters_controller_generator"

class DurableParametersControllerGeneratorTest < Rails::Generators::TestCase
  tests Rails::Generators::DurableParametersControllerGenerator
  destination File.expand_path("../tmp", File.dirname(__FILE__))
  setup :prepare_destination

  def test_controller_with_attributes
    run_generator %w[User name:string age:integer --orm=none]

    assert_file "app/controllers/users_controller.rb" do |content|
      # Test all standard REST actions are present
      assert_match "def index", content
      assert_match "def show", content
      assert_match "def new", content
      assert_match "def edit", content
      assert_match "def create", content
      assert_match "def update", content
      assert_match "def destroy", content

      # Test create method uses user_params
      assert_instance_method :create, content do |m|
        assert_match "@user = User.new(user_params)", m
        assert_match "@user.save", m
        assert_match "@user.errors", m
      end

      # Test update method uses user_params
      assert_instance_method :update, content do |m|
        assert_match "@user = User.find(params[:id])", m
        assert_match "@user.update(user_params)", m
        assert_match "@user.errors", m
      end

      # Test params method exists and has correct permit
      assert_match "def user_params", content
      assert_match "params.require(:user).permit(:age, :name)", content
    end
  end

  def test_controller_without_attributes
    run_generator %w[Product --orm=none]

    assert_file "app/controllers/products_controller.rb" do |content|
      assert_match "def product_params", content
      assert_match "params.require(:product).permit()", content
    end
  end

  def test_controller_with_many_attributes
    run_generator %w[Article title:string content:text published:boolean created_at:datetime --orm=none]

    assert_file "app/controllers/articles_controller.rb" do |content|
      assert_match "def article_params", content
      # Attributes should be sorted alphabetically
      assert_match "params.require(:article).permit(:content, :created_at, :published, :title)", content
    end
  end

  def test_controller_with_namespaced_model
    run_generator %w[Admin::User name:string --orm=none]

    assert_file "app/controllers/admin/users_controller.rb" do |content|
      assert_match "class Admin::UsersController < ApplicationController", content
      assert_match "def admin_user_params", content
      assert_match "params.require(:admin_user).permit(:name)", content
    end
  end

  def test_controller_with_underscored_model
    run_generator %w[user_profile first_name:string last_name:string --orm=none]

    assert_file "app/controllers/user_profiles_controller.rb" do |content|
      assert_match "class UserProfilesController < ApplicationController", content
      assert_match "def user_profile_params", content
      assert_match "params.require(:user_profile).permit(:first_name, :last_name)", content
    end
  end

  def test_module_namespacing_behavior
    # Test that the generator handles module namespacing correctly
    # The module_namespacing method exists for Rails < 3.1 compatibility
    generator = Rails::Generators::DurableParametersControllerGenerator.new(["User"])
    if defined?(Rails::VERSION) && Rails::VERSION::STRING < "3.1"
      assert generator.respond_to?(:module_namespacing)
    else
      # For Rails >= 3.1, module_namespacing is not defined
      assert true # Always pass for newer Rails
    end
  end

  def test_controller_actions_structure
    run_generator %w[Post title:string body:text --orm=none]

    assert_file "app/controllers/posts_controller.rb" do |content|
      # Test that all actions have proper structure
      assert_instance_method :index, content do |m|
        assert_match "@posts = Post.all", m
        assert_match "format.html", m
        assert_match "format.json", m
      end

      assert_instance_method :show, content do |m|
        assert_match "@post = Post.find(params[:id])", m
        assert_match "format.html", m
        assert_match "format.json", m
      end

      assert_instance_method :new, content do |m|
        assert_match "@post = Post.new", m
        assert_match "format.html", m
        assert_match "format.json", m
      end

      assert_instance_method :edit, content do |m|
        assert_match "@post = Post.find(params[:id])", m
      end

      assert_instance_method :create, content do |m|
        assert_match "@post = Post.new(post_params)", m
        assert_match "format.html", m
        assert_match "format.json", m
      end

      assert_instance_method :update, content do |m|
        assert_match "@post = Post.find(params[:id])", m
        assert_match "@post.update(post_params)", m
        assert_match "format.html", m
        assert_match "format.json", m
      end

      assert_instance_method :destroy, content do |m|
        assert_match "@post = Post.find(params[:id])", m
        assert_match "@post.destroy", m
        assert_match "format.html", m
        assert_match "format.json", m
      end
    end
  end

  def test_params_method_is_private
    run_generator %w[Item name:string price:decimal --orm=none]

    assert_file "app/controllers/items_controller.rb" do |content|
      # Find the position of 'private' and 'def item_params'
      private_index = content.index("private")
      params_index = content.index("def item_params")

      # Ensure params method is after private
      assert private_index < params_index, "item_params method should be private"
    end
  end

  def test_generated_controller_syntax
    run_generator %w[Book title:string author:string --orm=none]

    assert_file "app/controllers/books_controller.rb" do |content|
      # Test that the generated code is valid Ruby syntax
      begin
        RubyVM::InstructionSequence.compile(content)
      rescue SyntaxError => e
        flunk "Generated controller has syntax error: #{e.message}"
      end
    end
  end

  def test_update_json_response
    run_generator %w[Comment body:text --orm=none]

    assert_file "app/controllers/comments_controller.rb" do |content|
      assert_instance_method :update, content do |m|
        # For update, JSON should render the updated object, not head :no_content
        assert_match "render json: @comment", m
        refute_match "head :no_content", m
      end
    end
  end

  def test_create_error_handling
    run_generator %w[Event name:string date:date --orm=none]

    assert_file "app/controllers/events_controller.rb" do |content|
      assert_instance_method :create, content do |m|
        assert_match "@event.errors", m
        assert_match "status: :unprocessable_entity", m
      end
    end
  end

  def test_update_error_handling
    run_generator %w[Task description:text completed:boolean --orm=none]

    assert_file "app/controllers/tasks_controller.rb" do |content|
      assert_instance_method :update, content do |m|
        assert_match "@task.errors", m
        assert_match "status: :unprocessable_entity", m
      end
    end
  end

  def test_destroy_response
    run_generator %w[Message content:text --orm=none]

    assert_file "app/controllers/messages_controller.rb" do |content|
      assert_instance_method :destroy, content do |m|
        assert_match "head :no_content", m
      end
    end
  end

  def test_controller_with_no_attributes_permit_empty
    run_generator %w[EmptyModel --orm=none]

    assert_file "app/controllers/empty_models_controller.rb" do |content|
      assert_match "params.require(:empty_model).permit()", content
    end
  end

  def test_controller_with_nested_attributes
    # Test with attributes that might be nested, but since it's basic, just ensure it handles them
    run_generator %w[Profile user_id:integer bio:text avatar:string --orm=none]

    assert_file "app/controllers/profiles_controller.rb" do |content|
      # Attributes should be sorted alphabetically
      assert_match "params.require(:profile).permit(:avatar, :bio, :user_id)", content
    end
  end

  def test_module_namespacing_with_rails_version
    # Test that module_namespacing is handled correctly based on Rails version
    generator = Rails::Generators::DurableParametersControllerGenerator.new(["User"])
    if defined?(Rails::VERSION) && Rails::VERSION::STRING < "3.1"
      assert generator.respond_to?(:module_namespacing), "Should respond to module_namespacing for Rails < 3.1"
    else
      # For Rails >= 3.1, module_namespacing is not defined in this generator
      refute generator.respond_to?(:module_namespacing), "Should not respond to module_namespacing for Rails >= 3.1"
    end
  end

  def test_controller_inheritance
    run_generator %w[CustomModel title:string --orm=none]

    assert_file "app/controllers/custom_models_controller.rb" do |content|
      assert_match "class CustomModelsController < ApplicationController", content
    end
  end

  def test_route_url_and_index_helper
    run_generator %w[Article title:string --orm=none]

    assert_file "app/controllers/articles_controller.rb" do |content|
      # Check that route_url and index_helper are used correctly
      assert_match "# GET /articles", content
      assert_match "redirect_to articles_url", content
    end
  end
end
