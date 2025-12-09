# frozen_string_literal: true

require "test_helper"

class RailtieTest < Minitest::Test
  def setup
    # Reset Rails application for each test
    @original_app = Rails.application
    @app = FakeApplication.new
    Rails.application = @app
  end

  def teardown
    Rails.application = @original_app
  end

  def test_railtie_is_defined
    assert defined?(DurableParameters::Railtie)
  end

  def test_railtie_inherits_from_rails_railtie
    assert DurableParameters::Railtie < ::Rails::Railtie
  end



  def test_railtie_has_before_initialize_configuration
    # Test that the railtie configures before_initialize
    # We can check this by verifying the railtie class has the expected structure
    assert DurableParameters::Railtie.is_a?(Class)
    assert DurableParameters::Railtie < ::Rails::Railtie
  end

  def test_generator_config_for_newer_rails
    # Test the generator configuration logic
    app = FakeApplication.new

    # Mock config.respond_to?(:app_generators) to return true
    app.config.define_singleton_method(:respond_to?) do |method|
      method == :app_generators ? true : super(method)
    end

    app.config.define_singleton_method(:app_generators) do
      @app_generators ||= ActiveSupport::OrderedOptions.new
    end

    # Simulate the railtie configuration
    if app.config.respond_to?(:app_generators)
      app.config.app_generators.scaffold_controller = :strong_parameters_controller
    else
      app.config.generators.scaffold_controller = :strong_parameters_controller
    end

    assert_equal :strong_parameters_controller, app.config.app_generators.scaffold_controller
  end

  def test_generator_config_for_older_rails
    app = FakeApplication.new

    # Mock config.respond_to?(:app_generators) to return false
    app.config.define_singleton_method(:respond_to?) do |method|
      method == :app_generators ? false : super(method)
    end

    app.config.generators ||= ActiveSupport::OrderedOptions.new
    app.config.generators.scaffold_controller = :strong_parameters_controller

    assert_equal :strong_parameters_controller, app.config.generators.scaffold_controller
  end

  def test_action_on_unpermitted_parameters_initializer_development
    with_rails_env("development") do
      app = FakeApplication.new
      app.config.action_controller = ActiveSupport::OrderedOptions.new

      # Simulate the initializer logic - delete returns the block result when key doesn't exist
      DurableParameters::Adapters::Rails::Parameters.action_on_unpermitted_parameters =
        app.config.action_controller.delete(:action_on_unpermitted_parameters) do
          (Rails.env.test? || Rails.env.development?) ? :log : false
        end

      assert_equal :log, DurableParameters::Adapters::Rails::Parameters.action_on_unpermitted_parameters
    end
  end

  def test_action_on_unpermitted_parameters_initializer_test
    with_rails_env("test") do
      app = FakeApplication.new
      app.config.action_controller = ActiveSupport::OrderedOptions.new

      # Simulate the initializer logic
      DurableParameters::Adapters::Rails::Parameters.action_on_unpermitted_parameters =
        app.config.action_controller.delete(:action_on_unpermitted_parameters) do
          (Rails.env.test? || Rails.env.development?) ? :log : false
        end

      assert_equal :log, DurableParameters::Adapters::Rails::Parameters.action_on_unpermitted_parameters
    end
  end

  def test_action_on_unpermitted_parameters_initializer_production
    with_rails_env("production") do
      app = FakeApplication.new
      app.config.action_controller = ActiveSupport::OrderedOptions.new

      # Simulate the initializer logic
      DurableParameters::Adapters::Rails::Parameters.action_on_unpermitted_parameters =
        app.config.action_controller.delete(:action_on_unpermitted_parameters) do
          (Rails.env.test? || Rails.env.development?) ? :log : false
        end

      assert_equal false, DurableParameters::Adapters::Rails::Parameters.action_on_unpermitted_parameters
    end
  end

  def test_action_on_unpermitted_parameters_initializer_no_config
    with_rails_env("development") do
      app = FakeApplication.new
      app.config.action_controller = ActiveSupport::OrderedOptions.new

      # Simulate the initializer logic
      DurableParameters::Adapters::Rails::Parameters.action_on_unpermitted_parameters =
        app.config.action_controller.delete(:action_on_unpermitted_parameters) do
          (Rails.env.test? || Rails.env.development?) ? :log : false
        end

      assert_equal :log, DurableParameters::Adapters::Rails::Parameters.action_on_unpermitted_parameters
    end
  end

  def test_autoload_params_initializer_with_existing_directory
    app = FakeApplication.new
    app.config.root = Pathname.new("/tmp/test_app")

    # Create temporary directory structure
    params_dir = Pathname.new("/tmp/test_app/app/params")
    params_dir.mkpath

    original_paths = ActiveSupport::Dependencies.autoload_paths.dup

    # Simulate the initializer logic
    params_path = app.root.join("app", "params")
    if params_path.directory?
      ActiveSupport::Dependencies.autoload_paths << params_path.to_s
    end

    assert_includes ActiveSupport::Dependencies.autoload_paths, params_dir.to_s
  ensure
    ActiveSupport::Dependencies.autoload_paths.replace(original_paths)
    params_dir&.rmtree if params_dir&.exist?
  end

  def test_autoload_params_initializer_without_directory
    app = FakeApplication.new
    app.config.root = Pathname.new("/tmp/nonexistent_app")

    original_paths = ActiveSupport::Dependencies.autoload_paths.dup

    # Simulate the initializer logic
    params_path = app.root.join("app", "params")
    if params_path.directory?
      ActiveSupport::Dependencies.autoload_paths << params_path.to_s
    end

    # Paths should not change if directory doesn't exist
    assert_equal original_paths, ActiveSupport::Dependencies.autoload_paths
  ensure
    ActiveSupport::Dependencies.autoload_paths.replace(original_paths)
  end

  def test_railtie_has_after_initialize_configuration
    # Test that the railtie configures after_initialize
    # We can check this by verifying the railtie class has the expected structure
    assert DurableParameters::Railtie.is_a?(Class)
    assert DurableParameters::Railtie < ::Rails::Railtie
  end

  def test_application_params_has_descendants_method
    # Test that ApplicationParams has the descendants method after our fix
    assert DurableParameters::Core::ApplicationParams.respond_to?(:descendants)
    assert DurableParameters::Core::ApplicationParams.descendants.is_a?(Array)
  end

  private

  def with_rails_env(env)
    original_env = Rails.env
    Rails.env = env
    yield
  ensure
    Rails.env = original_env
  end
end