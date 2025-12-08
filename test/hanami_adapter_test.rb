# frozen_string_literal: true

require "test_helper"
require "ostruct"

class HanamiAdapterTest < Minitest::Test
  def setup
    # Ensure Hanami adapter is loaded
    require "durable_parameters/adapters/hanami"
  end

  # Test Hanami::Parameters class
  def test_hanami_parameters_class_inherits_from_core_parameters
    params = StrongParameters::Adapters::Hanami::Parameters.new({})
    assert_instance_of StrongParameters::Adapters::Hanami::Parameters, params
    assert_kind_of StrongParameters::Core::Parameters, params
  end

  def test_hanami_parameters_normalize_key_converts_to_string
    params_class = StrongParameters::Adapters::Hanami::Parameters
    instance = params_class.new({})

    # Test with symbol
    assert_equal "name", instance.send(:normalize_key, :name)
    # Test with string
    assert_equal "name", instance.send(:normalize_key, "name")
    # Test with integer
    assert_equal "123", instance.send(:normalize_key, 123)
  end

  def test_hanami_parameters_handles_mixed_key_types
    input_params = {"name" => "John", :email => "john@example.com", 123 => "value"}
    params = StrongParameters::Adapters::Hanami::Parameters.new(input_params)

    # Hanami uses string keys by default
    assert_equal "John", params["name"]
    assert_equal "john@example.com", params["email"]
    assert_equal "value", params["123"]
  end

  def test_hanami_parameters_permits_basic_functionality
    params = StrongParameters::Adapters::Hanami::Parameters.new(
      "user" => {"name" => "John", "email" => "john@example.com", "admin" => true}
    )

    permitted = params.require("user").permit("name", "email")

    assert permitted.permitted?
    assert_equal "John", permitted["name"]
    assert_equal "john@example.com", permitted["email"]
    refute permitted.key?("admin")
  end

  # Test Action module
  def test_action_module_provides_strong_params_method_hanami_2x
    # Mock Hanami 2.x action
    mock_action = Class.new do
      include StrongParameters::Adapters::Hanami::Action

      # Mock halt method for error handling
      def halt(status, response)
        raise "Halted with status #{status}: #{response}"
      end
    end

    action = mock_action.new
    request_params = {"user" => {"name" => "John", "email" => "john@example.com"}}
    strong_params = action.strong_params(request_params)

    assert_instance_of StrongParameters::Adapters::Hanami::Parameters, strong_params
    assert_equal "John", strong_params["user"]["name"]
    assert_equal "john@example.com", strong_params["user"]["email"]
  end

  def test_action_module_provides_strong_params_method_hanami_1x
    # Mock Hanami 1.x action
    mock_action = Class.new do
      include StrongParameters::Adapters::Hanami::Action

      attr_accessor :params

      def initialize(action_params)
        @params = action_params
      end

      # Mock halt method for error handling
      def halt(status, response)
        raise "Halted with status #{status}: #{response}"
      end
    end

    action = mock_action.new({"user" => {"name" => "John", "email" => "john@example.com"}})
    strong_params = action.strong_params

    assert_instance_of StrongParameters::Adapters::Hanami::Parameters, strong_params
    assert_equal "John", strong_params["user"]["name"]
    assert_equal "john@example.com", strong_params["user"]["email"]
  end

  def test_action_module_strong_params_with_nil_params_obj
    mock_action = Class.new do
      include StrongParameters::Adapters::Hanami::Action

      attr_accessor :params

      def initialize(action_params)
        @params = action_params
      end
    end

    action = mock_action.new({"user" => {"name" => "John"}})
    strong_params = action.strong_params(nil)

    assert_instance_of StrongParameters::Adapters::Hanami::Parameters, strong_params
    assert_equal "John", strong_params["user"]["name"]
  end

  def test_action_module_strong_params_with_empty_params
    mock_action = Class.new do
      include StrongParameters::Adapters::Hanami::Action
    end

    action = mock_action.new
    strong_params = action.strong_params

    assert_instance_of StrongParameters::Adapters::Hanami::Parameters, strong_params
    assert_empty strong_params
  end

  def test_action_module_provides_sp_alias
    mock_action = Class.new do
      include StrongParameters::Adapters::Hanami::Action

      attr_accessor :params

      def initialize(action_params)
        @params = action_params
      end
    end

    action = mock_action.new({"user" => {"name" => "John"}})
    strong_params_result = action.strong_params
    sp_result = action.sp
    assert_equal strong_params_result, sp_result
    assert_instance_of StrongParameters::Adapters::Hanami::Parameters, sp_result
  end

  # Test error handling methods
  def test_handle_parameter_missing_error
    mock_action = Class.new do
      include StrongParameters::Adapters::Hanami::Action

      def initialize
        @halt_called = false
        @halt_args = nil
      end

      attr_accessor :halt_called, :halt_args

      def halt(status, response)
        @halt_called = true
        @halt_args = [status, response]
      end
    end

    action = mock_action.new
    exception = StrongParameters::Core::ParameterMissing.new("user")

    action.handle_parameter_missing(exception)

    assert action.halt_called
    assert_equal 400, action.halt_args[0]
    assert_includes action.halt_args[1], "Required parameter missing: user"
  end

  def test_handle_forbidden_attributes_error
    mock_action = Class.new do
      include StrongParameters::Adapters::Hanami::Action

      def initialize
        @halt_called = false
        @halt_args = nil
      end

      attr_accessor :halt_called, :halt_args

      def halt(status, response)
        @halt_called = true
        @halt_args = [status, response]
      end
    end

    action = mock_action.new
    exception = StrongParameters::Core::ForbiddenAttributes.new

    action.handle_forbidden_attributes(exception)

    assert action.halt_called
    assert_equal 400, action.halt_args[0]
    assert_includes action.halt_args[1], "Forbidden attributes in mass assignment"
  end

  def test_handle_unpermitted_parameters_error
    mock_action = Class.new do
      include StrongParameters::Adapters::Hanami::Action

      def initialize
        @halt_called = false
        @halt_args = nil
      end

      attr_accessor :halt_called, :halt_args

      def halt(status, response)
        @halt_called = true
        @halt_args = [status, response]
      end
    end

    action = mock_action.new
    exception = StrongParameters::Core::UnpermittedParameters.new(["admin", "password"])

    action.handle_unpermitted_parameters(exception)

    assert action.halt_called
    assert_equal 400, action.halt_args[0]
    assert_includes action.halt_args[1], "Unpermitted parameters: admin, password"
  end

  # Test Action module included hook
  def test_action_module_included_hook_sets_up_error_handling
    mock_base = Class.new do
      def self.handle_exception(*args)
        @handled_exceptions ||= []
        @handled_exceptions << args
      end

      def self.handled_exceptions
        @handled_exceptions || []
      end
    end

    # Include the module
    mock_base.include StrongParameters::Adapters::Hanami::Action

    # Check that error handling was set up
    handlers = mock_base.handled_exceptions
    assert_equal 3, handlers.length

    # Each handler should be [{exception_class => handler_method}]
    expected_handlers = [
      [{StrongParameters::Core::ParameterMissing => :handle_parameter_missing}],
      [{StrongParameters::Core::ForbiddenAttributes => :handle_forbidden_attributes}],
      [{StrongParameters::Core::UnpermittedParameters => :handle_unpermitted_parameters}]
    ]

    expected_handlers.each do |expected|
      assert_includes handlers, expected
    end
  end

  def test_action_module_included_hook_skips_error_handling_if_not_supported
    mock_base = Class.new do
      # Does not respond to handle_exception
    end

    # Should not raise an error
    assert_silent do
      mock_base.include StrongParameters::Adapters::Hanami::Action
    end
  end

  # Test setup! method
  def test_setup_configures_logging_in_development
    # Mock app with env
    mock_app = Class.new do
      def config
        OpenStruct.new(env: :development)
      end
    end

    # Reset any previous configuration
    StrongParameters::Adapters::Hanami::Parameters.action_on_unpermitted_parameters = nil
    StrongParameters::Adapters::Hanami::Parameters.unpermitted_notification_handler = nil

    StrongParameters::Adapters::Hanami.setup!(mock_app)

    assert_equal :log, StrongParameters::Adapters::Hanami::Parameters.action_on_unpermitted_parameters
    assert StrongParameters::Adapters::Hanami::Parameters.unpermitted_notification_handler.is_a?(Proc)
  end

  def test_setup_configures_logging_in_development_string
    mock_app = Class.new do
      def config
        OpenStruct.new(env: "development")
      end
    end

    StrongParameters::Adapters::Hanami::Parameters.action_on_unpermitted_parameters = nil
    StrongParameters::Adapters::Hanami::Parameters.unpermitted_notification_handler = nil

    StrongParameters::Adapters::Hanami.setup!(mock_app)

    assert_equal :log, StrongParameters::Adapters::Hanami::Parameters.action_on_unpermitted_parameters
    assert StrongParameters::Adapters::Hanami::Parameters.unpermitted_notification_handler.is_a?(Proc)
  end

  def test_setup_skips_logging_in_production
    mock_app = Class.new do
      def config
        OpenStruct.new(env: :production)
      end
    end.new

    # Reset any previous configuration
    StrongParameters::Adapters::Hanami::Parameters.action_on_unpermitted_parameters = nil
    StrongParameters::Adapters::Hanami::Parameters.unpermitted_notification_handler = nil

    # Verify they're nil before setup
    assert_nil StrongParameters::Adapters::Hanami::Parameters.action_on_unpermitted_parameters
    assert_nil StrongParameters::Adapters::Hanami::Parameters.unpermitted_notification_handler

    StrongParameters::Adapters::Hanami.setup!(mock_app)

    # Should not set up logging in production (should remain nil)
    assert_nil StrongParameters::Adapters::Hanami::Parameters.action_on_unpermitted_parameters
    assert_nil StrongParameters::Adapters::Hanami::Parameters.unpermitted_notification_handler
  end

  def test_setup_uses_env_fallback_when_no_app
    # Set environment variable
    original_env = ENV["HANAMI_ENV"]
    ENV["HANAMI_ENV"] = "development"

    StrongParameters::Adapters::Hanami::Parameters.action_on_unpermitted_parameters = nil
    StrongParameters::Adapters::Hanami::Parameters.unpermitted_notification_handler = nil

    StrongParameters::Adapters::Hanami.setup!

    assert_equal :log, StrongParameters::Adapters::Hanami::Parameters.action_on_unpermitted_parameters
    assert StrongParameters::Adapters::Hanami::Parameters.unpermitted_notification_handler.is_a?(Proc)

    ENV["HANAMI_ENV"] = original_env
  end

  def test_setup_uses_rack_env_fallback
    original_hanami_env = ENV["HANAMI_ENV"]
    original_rack_env = ENV["RACK_ENV"]
    ENV["HANAMI_ENV"] = nil
    ENV["RACK_ENV"] = "development"

    StrongParameters::Adapters::Hanami::Parameters.action_on_unpermitted_parameters = nil
    StrongParameters::Adapters::Hanami::Parameters.unpermitted_notification_handler = nil

    StrongParameters::Adapters::Hanami.setup!

    assert_equal :log, StrongParameters::Adapters::Hanami::Parameters.action_on_unpermitted_parameters
    assert StrongParameters::Adapters::Hanami::Parameters.unpermitted_notification_handler.is_a?(Proc)

    ENV["HANAMI_ENV"] = original_hanami_env
    ENV["RACK_ENV"] = original_rack_env
  end

  def test_setup_uses_hanami_constant_when_available
    # Mock Hanami constant
    original_hanami = Object.const_get(:Hanami) if defined?(::Hanami)
    Object.const_set(:Hanami, Module.new)
    ::Hanami.define_singleton_method(:env) { :development }

    StrongParameters::Adapters::Hanami::Parameters.action_on_unpermitted_parameters = nil
    StrongParameters::Adapters::Hanami::Parameters.unpermitted_notification_handler = nil

    StrongParameters::Adapters::Hanami.setup!

    assert_equal :log, StrongParameters::Adapters::Hanami::Parameters.action_on_unpermitted_parameters
    assert StrongParameters::Adapters::Hanami::Parameters.unpermitted_notification_handler.is_a?(Proc)

    # Clean up
    Object.send(:remove_const, :Hanami)
    Object.const_set(:Hanami, original_hanami) if original_hanami
  end

  def test_setup_unpermitted_notification_handler_uses_app_logger
    mock_logger = Class.new do
      attr_accessor :messages
      def initialize
        @messages = []
      end

      def warn(message)
        @messages << message
      end
    end.new

    mock_app = Class.new do
      def config
        OpenStruct.new(env: :development)
      end

      def logger
        @mock_logger
      end
    end.new
    mock_app.instance_variable_set(:@mock_logger, mock_logger)

    StrongParameters::Adapters::Hanami.setup!(mock_app)

    handler = StrongParameters::Adapters::Hanami::Parameters.unpermitted_notification_handler
    handler.call(["admin"])

    assert_includes mock_logger.messages, "Unpermitted parameters: admin"
  end

  def test_setup_unpermitted_notification_handler_uses_hanami_logger
    # Mock Hanami constant with logger
    original_hanami = Object.const_get(:Hanami) if defined?(::Hanami)
    mock_logger = Class.new do
      attr_accessor :messages
      def initialize
        @messages = []
      end

      def warn(message)
        @messages << message
      end
    end.new

    mock_hanami = Module.new
    mock_hanami.define_singleton_method(:env) { :development }
    mock_hanami.define_singleton_method(:logger) { mock_logger }
    Object.const_set(:Hanami, mock_hanami)

    StrongParameters::Adapters::Hanami.setup!

    handler = StrongParameters::Adapters::Hanami::Parameters.unpermitted_notification_handler
    handler.call(["password"])

    assert_includes mock_logger.messages, "Unpermitted parameters: password"

    # Clean up
    Object.send(:remove_const, :Hanami)
    Object.const_set(:Hanami, original_hanami) if original_hanami
  end

  # Test integration scenarios
  def test_hanami_adapter_integration_basic_usage_hanami_2x
    # Mock Hanami 2.x action
    mock_action = Class.new do
      include StrongParameters::Adapters::Hanami::Action

      def initialize(request_params)
        @request_params = request_params
      end

      def halt(status, response)
        raise "Halted with status #{status}: #{response}"
      end

      def handle_request
        user_params = strong_params(@request_params).require("user").permit("name", "email")
        {name: user_params["name"], email: user_params["email"]}
      end
    end

    action = mock_action.new({"user" => {"name" => "John", "email" => "john@example.com", "admin" => true}})
    result = action.handle_request

    assert_equal "John", result[:name]
    assert_equal "john@example.com", result[:email]
  end

  def test_hanami_adapter_integration_basic_usage_hanami_1x
    # Mock Hanami 1.x action
    mock_action = Class.new do
      include StrongParameters::Adapters::Hanami::Action

      attr_accessor :params

      def initialize(action_params)
        @params = action_params
      end

      def halt(status, response)
        raise "Halted with status #{status}: #{response}"
      end

      def call
        user_params = strong_params.require("user").permit("name", "email")
        {name: user_params["name"], email: user_params["email"]}
      end
    end

    action = mock_action.new({"user" => {"name" => "John", "email" => "john@example.com", "admin" => true}})
    result = action.call

    assert_equal "John", result[:name]
    assert_equal "john@example.com", result[:email]
  end

  def test_hanami_adapter_integration_with_nested_params
    mock_action = Class.new do
      include StrongParameters::Adapters::Hanami::Action

      attr_accessor :params

      def initialize(action_params)
        @params = action_params
      end

      def call
        strong_params.require("user").permit("name", "profile" => ["bio", "age"])
      end
    end

    nested_params = {
      "user" => {
        "name" => "John",
        "profile" => {"bio" => "Developer", "age" => 30},
        "admin" => true
      }
    }

    action = mock_action.new(nested_params)
    result = action.call

    assert result.permitted?
    assert_equal "John", result["name"]
    assert_equal "Developer", result["profile"]["bio"]
    assert_equal 30, result["profile"]["age"]
    refute result.key?("admin")
  end

  def test_hanami_adapter_integration_error_handling_parameter_missing
    mock_action = Class.new do
      include StrongParameters::Adapters::Hanami::Action

      attr_accessor :params

      def initialize(action_params)
        @params = action_params
      end

      def halt(status, response)
        raise StrongParameters::Core::ParameterMissing.new("missing_param")
      end

      def call
        strong_params.require("missing_param")
      end
    end

    action = mock_action.new({"user" => {"name" => "John"}})

    assert_raises StrongParameters::Core::ParameterMissing do
      action.call
    end
  end

  def test_hanami_adapter_integration_error_handling_forbidden_attributes
    mock_action = Class.new do
      include StrongParameters::Adapters::Hanami::Action

      attr_accessor :params

      def initialize(action_params)
        @params = action_params
      end

      def call
        # This should raise ForbiddenAttributes if we try to use unpermitted params
        # For this test, we'll simulate the scenario
        strong_params
        # In a real scenario, this would be caught by mass assignment protection
      end
    end

    action = mock_action.new({"user" => {"name" => "John", "admin" => true}})
    result = action.call

    # The params should be wrapped but not permitted yet
    assert_instance_of StrongParameters::Adapters::Hanami::Parameters, result
  end

  # Test adapter loading and structure
  def test_hanami_adapter_is_module
    assert StrongParameters::Adapters::Hanami.is_a?(Module)
  end

  def test_hanami_adapter_has_parameters_class
    assert defined?(StrongParameters::Adapters::Hanami::Parameters)
    assert StrongParameters::Adapters::Hanami::Parameters.is_a?(Class)
  end

  def test_hanami_adapter_has_action_module
    assert defined?(StrongParameters::Adapters::Hanami::Action)
    assert StrongParameters::Adapters::Hanami::Action.is_a?(Module)
  end

  def test_hanami_adapter_has_setup_method
    assert StrongParameters::Adapters::Hanami.respond_to?(:setup!)
  end
end
