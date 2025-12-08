# frozen_string_literal: true

require "test_helper"

class SinatraAdapterTest < Minitest::Test
  def setup
    # Ensure Sinatra adapter is loaded
    require "durable_parameters/adapters/sinatra"
  end

  # Test Sinatra::Parameters class
  def test_sinatra_parameters_class_inherits_from_core_parameters
    params = StrongParameters::Adapters::Sinatra::Parameters.new({})
    assert_instance_of StrongParameters::Adapters::Sinatra::Parameters, params
    assert_kind_of StrongParameters::Core::Parameters, params
  end

  def test_sinatra_parameters_normalize_key_converts_to_string
    params_class = StrongParameters::Adapters::Sinatra::Parameters
    instance = params_class.new({})

    # Test with symbol
    assert_equal "name", instance.send(:normalize_key, :name)
    # Test with string
    assert_equal "name", instance.send(:normalize_key, "name")
    # Test with integer
    assert_equal "123", instance.send(:normalize_key, 123)
  end

  def test_sinatra_parameters_handles_mixed_key_types
    input_params = {"name" => "John", :email => "john@example.com", 123 => "value"}
    params = StrongParameters::Adapters::Sinatra::Parameters.new(input_params)

    # Sinatra typically uses string keys, so all should be accessible as strings
    assert_equal "John", params["name"]
    assert_equal "john@example.com", params["email"]
    assert_equal "value", params["123"]
  end

  # Test Helpers module
  def test_helpers_module_provides_strong_params_method
    # Create a mock Sinatra app class that includes the helpers
    mock_app = Class.new do
      include StrongParameters::Adapters::Sinatra::Helpers

      attr_accessor :params

      def initialize
        @params = {"user" => {"name" => "John", "email" => "john@example.com"}}
      end
    end

    app = mock_app.new
    strong_params = app.strong_params

    assert_instance_of StrongParameters::Adapters::Sinatra::Parameters, strong_params
    assert_equal "John", strong_params["user"]["name"]
    assert_equal "john@example.com", strong_params["user"]["email"]
  end

  def test_helpers_module_caches_strong_params
    mock_app = Class.new do
      include StrongParameters::Adapters::Sinatra::Helpers

      attr_accessor :params

      def initialize
        @params = {"user" => {"name" => "John"}}
      end
    end

    app = mock_app.new
    first_call = app.strong_params
    second_call = app.strong_params

    assert_same first_call, second_call
  end

  def test_helpers_module_provides_sp_alias
    mock_app = Class.new do
      include StrongParameters::Adapters::Sinatra::Helpers

      attr_accessor :params

      def initialize
        @params = {"user" => {"name" => "John"}}
      end
    end

    app = mock_app.new
    assert_same app.strong_params, app.sp
  end

  # Test ErrorHandlers module
  def test_error_handlers_module_registers_with_app
    mock_app = Class.new do
      def self.error(*args, &block)
        # Mock error handler registration
        @error_handlers ||= {}
        @error_handlers[args.first] = block
      end

      def self.registered_handlers
        @error_handlers || {}
      end
    end

    # Register error handlers
    StrongParameters::Adapters::Sinatra::ErrorHandlers.registered(mock_app)

    handlers = mock_app.registered_handlers
    assert handlers.key?(StrongParameters::Core::ParameterMissing)
    assert handlers.key?(StrongParameters::Core::ForbiddenAttributes)
    assert handlers.key?(StrongParameters::Core::UnpermittedParameters)
  end





  # Test main Sinatra module registration
  def test_sinatra_module_registered_method
    mock_app = Class.new do
      def self.helpers(*modules)
        @helpers = modules
      end

      def self.register(*modules)
        @registered = modules
      end

      def self.helpers_registered
        @helpers || []
      end

      def self.modules_registered
        @registered || []
      end

      def self.development?
        true
      end

      def self.logger
        @logger ||= StringIO.new
      end
    end

    StrongParameters::Adapters::Sinatra.registered(mock_app)

    assert_includes mock_app.helpers_registered, StrongParameters::Adapters::Sinatra::Helpers
    assert_includes mock_app.modules_registered, StrongParameters::Adapters::Sinatra::ErrorHandlers
  end

  def test_sinatra_module_registered_configures_logging_in_development
    mock_app = Class.new do
      def self.helpers(*modules); end
      def self.register(*modules); end
      def self.development?; true; end
      def self.logger; @logger ||= StringIO.new; end
    end

    StrongParameters::Adapters::Sinatra.registered(mock_app)

    # Check that logging is configured
    params_class = StrongParameters::Adapters::Sinatra::Parameters
    assert_equal :log, params_class.action_on_unpermitted_parameters
    assert params_class.unpermitted_notification_handler.is_a?(Proc)
  end

  def test_sinatra_module_included_method
    mock_base = Class.new do
      def self.register(*args); end
    end

    StrongParameters::Adapters::Sinatra.included(mock_base)
    # Should call register if base responds to it
  end

  # Test integration scenarios
  def test_sinatra_adapter_integration_basic_usage
    # Mock a Sinatra app with the adapter
    mock_app = Class.new do
      include StrongParameters::Adapters::Sinatra::Helpers

      attr_accessor :params

      def initialize(params = {})
        @params = params
      end

      def process_request
        user_params = strong_params.require("user").permit("name", "email")
        {name: user_params["name"], email: user_params["email"]}
      end
    end

    app = mock_app.new({"user" => {"name" => "John", "email" => "john@example.com", "admin" => true}})
    result = app.process_request

    assert_equal "John", result[:name]
    assert_equal "john@example.com", result[:email]
  end

  def test_sinatra_adapter_integration_with_nested_params
    mock_app = Class.new do
      include StrongParameters::Adapters::Sinatra::Helpers

      attr_accessor :params

      def initialize(params = {})
        @params = params
      end

      def process_request
        user_params = strong_params.require("user").permit("name", "profile" => ["bio", "age"])
        user_params
      end
    end

    nested_params = {
      "user" => {
        "name" => "John",
        "profile" => {"bio" => "Developer", "age" => 30},
        "admin" => true
      }
    }

    app = mock_app.new(nested_params)
    result = app.process_request

    assert result.permitted?
    assert_equal "John", result["name"]
    assert_equal "Developer", result["profile"]["bio"]
    assert_equal 30, result["profile"]["age"]
    refute result.key?("admin")
  end

  def test_sinatra_adapter_integration_error_handling
    mock_app = Class.new do
      include StrongParameters::Adapters::Sinatra::Helpers

      attr_accessor :params

      def initialize(params = {})
        @params = params
      end

      def process_request
        strong_params.require("missing_param")
      end
    end

    app = mock_app.new({"user" => {"name" => "John"}})

    assert_raises StrongParameters::Core::ParameterMissing do
      app.process_request
    end
  end

  # Test adapter loading
  def test_sinatra_adapter_is_module
    assert StrongParameters::Adapters::Sinatra.is_a?(Module)
  end

  def test_sinatra_adapter_has_parameters_class
    assert defined?(StrongParameters::Adapters::Sinatra::Parameters)
    assert StrongParameters::Adapters::Sinatra::Parameters.is_a?(Class)
  end

  def test_sinatra_adapter_has_helpers_module
    assert defined?(StrongParameters::Adapters::Sinatra::Helpers)
    assert StrongParameters::Adapters::Sinatra::Helpers.is_a?(Module)
  end

  def test_sinatra_adapter_has_error_handlers_module
    assert defined?(StrongParameters::Adapters::Sinatra::ErrorHandlers)
    assert StrongParameters::Adapters::Sinatra::ErrorHandlers.is_a?(Module)
  end
end