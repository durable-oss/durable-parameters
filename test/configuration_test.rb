# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    # Save original configuration
    @original_action = StrongParameters::Core::Configuration.action_on_unpermitted_parameters
    @original_handler = StrongParameters::Core::Configuration.unpermitted_notification_handler
    @original_always_permitted = StrongParameters::Core::Configuration.always_permitted_parameters
  end

  def teardown
    # Restore original configuration
    StrongParameters::Core::Configuration.action_on_unpermitted_parameters = @original_action
    StrongParameters::Core::Configuration.unpermitted_notification_handler = @original_handler
    StrongParameters::Core::Configuration.always_permitted_parameters = @original_always_permitted
  end

  def test_action_on_unpermitted_parameters_accessor
    StrongParameters::Core::Configuration.action_on_unpermitted_parameters = :log
    assert_equal :log, StrongParameters::Core::Configuration.action_on_unpermitted_parameters

    StrongParameters::Core::Configuration.action_on_unpermitted_parameters = :raise
    assert_equal :raise, StrongParameters::Core::Configuration.action_on_unpermitted_parameters

    StrongParameters::Core::Configuration.action_on_unpermitted_parameters = nil
    assert_nil StrongParameters::Core::Configuration.action_on_unpermitted_parameters

    StrongParameters::Core::Configuration.action_on_unpermitted_parameters = false
    assert_equal false, StrongParameters::Core::Configuration.action_on_unpermitted_parameters
  end

  def test_unpermitted_notification_handler_accessor
    handler = proc { |keys| puts keys.join(", ") }
    StrongParameters::Core::Configuration.unpermitted_notification_handler = handler
    assert_equal handler, StrongParameters::Core::Configuration.unpermitted_notification_handler

    StrongParameters::Core::Configuration.unpermitted_notification_handler = nil
    assert_nil StrongParameters::Core::Configuration.unpermitted_notification_handler
  end

  def test_always_permitted_parameters_accessor
    custom_params = %w[controller action format]
    StrongParameters::Core::Configuration.always_permitted_parameters = custom_params
    assert_equal custom_params, StrongParameters::Core::Configuration.always_permitted_parameters
  end

  def test_reset_resets_all_configuration
    # Set custom values
    StrongParameters::Core::Configuration.action_on_unpermitted_parameters = :raise
    handler = proc { |keys| }
    StrongParameters::Core::Configuration.unpermitted_notification_handler = handler
    StrongParameters::Core::Configuration.always_permitted_parameters = %w[custom]

    # Reset
    StrongParameters::Core::Configuration.reset!

    # Verify defaults
    assert_nil StrongParameters::Core::Configuration.action_on_unpermitted_parameters
    assert_nil StrongParameters::Core::Configuration.unpermitted_notification_handler
    assert_equal %w[controller action], StrongParameters::Core::Configuration.always_permitted_parameters
  end

  def test_apply_synchronizes_with_parameters_class
    StrongParameters::Core::Configuration.action_on_unpermitted_parameters = :log
    handler = proc { |keys| puts keys }
    StrongParameters::Core::Configuration.unpermitted_notification_handler = handler

    StrongParameters::Core::Configuration.apply!

    assert_equal :log, StrongParameters::Core::Parameters.action_on_unpermitted_parameters
    assert_equal handler, StrongParameters::Core::Parameters.unpermitted_notification_handler
  end

  def test_apply_synchronizes_nil_values
    StrongParameters::Core::Configuration.action_on_unpermitted_parameters = nil
    StrongParameters::Core::Configuration.unpermitted_notification_handler = nil

    StrongParameters::Core::Configuration.apply!

    assert_nil StrongParameters::Core::Parameters.action_on_unpermitted_parameters
    assert_nil StrongParameters::Core::Parameters.unpermitted_notification_handler
  end

  def test_configuration_is_independent_of_parameters_class
    # Set configuration
    StrongParameters::Core::Configuration.action_on_unpermitted_parameters = :log

    # Directly set Parameters class (without apply!)
    StrongParameters::Core::Parameters.action_on_unpermitted_parameters = :raise

    # Configuration should not be affected
    assert_equal :log, StrongParameters::Core::Configuration.action_on_unpermitted_parameters
    assert_equal :raise, StrongParameters::Core::Parameters.action_on_unpermitted_parameters
  end

  def test_reset_and_apply_workflow
    # Set custom configuration
    StrongParameters::Core::Configuration.action_on_unpermitted_parameters = :raise
    custom_handler = proc { |keys| puts keys }
    StrongParameters::Core::Configuration.unpermitted_notification_handler = custom_handler

    # Apply to Parameters class
    StrongParameters::Core::Configuration.apply!
    assert_equal :raise, StrongParameters::Core::Parameters.action_on_unpermitted_parameters

    # Reset configuration
    StrongParameters::Core::Configuration.reset!
    assert_nil StrongParameters::Core::Configuration.action_on_unpermitted_parameters

    # Parameters class is not automatically updated
    assert_equal :raise, StrongParameters::Core::Parameters.action_on_unpermitted_parameters

    # Apply again to synchronize
    StrongParameters::Core::Configuration.apply!
    assert_nil StrongParameters::Core::Parameters.action_on_unpermitted_parameters
  end

  def test_always_permitted_parameters_default
    StrongParameters::Core::Configuration.reset!
    assert_equal %w[controller action], StrongParameters::Core::Configuration.always_permitted_parameters
  end

  def test_always_permitted_parameters_frozen
    StrongParameters::Core::Configuration.reset!
    params = StrongParameters::Core::Configuration.always_permitted_parameters
    assert params.frozen?
  end

  def test_multiple_resets
    3.times do
      StrongParameters::Core::Configuration.action_on_unpermitted_parameters = :raise
      StrongParameters::Core::Configuration.reset!
      assert_nil StrongParameters::Core::Configuration.action_on_unpermitted_parameters
    end
  end

  def test_handler_with_lambda
    handler = ->(keys) { keys.map(&:upcase) }
    StrongParameters::Core::Configuration.unpermitted_notification_handler = handler
    assert_equal handler, StrongParameters::Core::Configuration.unpermitted_notification_handler
  end

  def test_handler_with_method_object
    # Create a simple object that responds to call
    handler = Object.new
    def handler.call(keys)
      keys.join(",")
    end

    StrongParameters::Core::Configuration.unpermitted_notification_handler = handler
    assert_equal handler, StrongParameters::Core::Configuration.unpermitted_notification_handler
  end

  def test_configuration_thread_safety
    threads = 10.times.map do |i|
      Thread.new do
        StrongParameters::Core::Configuration.action_on_unpermitted_parameters = i.even? ? :log : :raise
        sleep 0.001
        StrongParameters::Core::Configuration.action_on_unpermitted_parameters
      end
    end

    results = threads.map(&:value)
    # At least one thread should have set a value
    refute results.all?(&:nil?)
  end
end
