# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    # Save original configuration
    @original_action = DurableParameters::Core::Configuration.action_on_unpermitted_parameters
    @original_handler = DurableParameters::Core::Configuration.unpermitted_notification_handler
    @original_always_permitted = DurableParameters::Core::Configuration.always_permitted_parameters

    # Save original Parameters class settings
    @original_params_action = DurableParameters::Core::Parameters.action_on_unpermitted_parameters
    @original_params_handler = DurableParameters::Core::Parameters.unpermitted_notification_handler
    @original_params_never_unpermitted = DurableParameters::Core::Parameters.never_unpermitted_params
  end

  def teardown
    # Restore original configuration
    DurableParameters::Core::Configuration.action_on_unpermitted_parameters = @original_action
    DurableParameters::Core::Configuration.unpermitted_notification_handler = @original_handler
    DurableParameters::Core::Configuration.always_permitted_parameters = @original_always_permitted

    # Restore original Parameters class settings
    DurableParameters::Core::Parameters.action_on_unpermitted_parameters = @original_params_action
    DurableParameters::Core::Parameters.unpermitted_notification_handler = @original_params_handler
    DurableParameters::Core::Parameters.never_unpermitted_params = @original_params_never_unpermitted
  end

  def test_action_on_unpermitted_parameters_accessor
    DurableParameters::Core::Configuration.action_on_unpermitted_parameters = :log
    assert_equal :log, DurableParameters::Core::Configuration.action_on_unpermitted_parameters

    DurableParameters::Core::Configuration.action_on_unpermitted_parameters = :raise
    assert_equal :raise, DurableParameters::Core::Configuration.action_on_unpermitted_parameters

    DurableParameters::Core::Configuration.action_on_unpermitted_parameters = nil
    assert_nil DurableParameters::Core::Configuration.action_on_unpermitted_parameters

    DurableParameters::Core::Configuration.action_on_unpermitted_parameters = false
    assert_equal false, DurableParameters::Core::Configuration.action_on_unpermitted_parameters
  end

  def test_unpermitted_notification_handler_accessor
    handler = proc { |keys| puts keys.join(", ") }
    DurableParameters::Core::Configuration.unpermitted_notification_handler = handler
    assert_equal handler, DurableParameters::Core::Configuration.unpermitted_notification_handler

    DurableParameters::Core::Configuration.unpermitted_notification_handler = nil
    assert_nil DurableParameters::Core::Configuration.unpermitted_notification_handler
  end

  def test_always_permitted_parameters_accessor
    custom_params = %w[controller action format]
    DurableParameters::Core::Configuration.always_permitted_parameters = custom_params
    assert_equal custom_params, DurableParameters::Core::Configuration.always_permitted_parameters
  end

  def test_reset_resets_all_configuration
    # Set custom values
    DurableParameters::Core::Configuration.action_on_unpermitted_parameters = :raise
    handler = proc { |keys| }
    DurableParameters::Core::Configuration.unpermitted_notification_handler = handler
    DurableParameters::Core::Configuration.always_permitted_parameters = %w[custom]

    # Reset
    DurableParameters::Core::Configuration.reset!

    # Verify defaults
    assert_nil DurableParameters::Core::Configuration.action_on_unpermitted_parameters
    assert_nil DurableParameters::Core::Configuration.unpermitted_notification_handler
    assert_equal %w[controller action], DurableParameters::Core::Configuration.always_permitted_parameters
  end

  def test_apply_synchronizes_with_parameters_class
    DurableParameters::Core::Configuration.action_on_unpermitted_parameters = :log
    handler = proc { |keys| puts keys }
    DurableParameters::Core::Configuration.unpermitted_notification_handler = handler
    DurableParameters::Core::Configuration.always_permitted_parameters = %w[controller action format]

    DurableParameters::Core::Configuration.apply!

    assert_equal :log, DurableParameters::Core::Parameters.action_on_unpermitted_parameters
    assert_equal handler, DurableParameters::Core::Parameters.unpermitted_notification_handler
    assert_equal %w[controller action format], DurableParameters::Core::Parameters.never_unpermitted_params
  end

  def test_apply_synchronizes_nil_values
    DurableParameters::Core::Configuration.action_on_unpermitted_parameters = nil
    DurableParameters::Core::Configuration.unpermitted_notification_handler = nil
    DurableParameters::Core::Configuration.always_permitted_parameters = []

    DurableParameters::Core::Configuration.apply!

    assert_nil DurableParameters::Core::Parameters.action_on_unpermitted_parameters
    assert_nil DurableParameters::Core::Parameters.unpermitted_notification_handler
    assert_equal [], DurableParameters::Core::Parameters.never_unpermitted_params
  end

  def test_configuration_is_independent_of_parameters_class
    # Set configuration
    DurableParameters::Core::Configuration.action_on_unpermitted_parameters = :log
    DurableParameters::Core::Configuration.always_permitted_parameters = %w[custom]

    # Directly set Parameters class (without apply!)
    DurableParameters::Core::Parameters.action_on_unpermitted_parameters = :raise
    DurableParameters::Core::Parameters.never_unpermitted_params = %w[other]

    # Configuration should not be affected
    assert_equal :log, DurableParameters::Core::Configuration.action_on_unpermitted_parameters
    assert_equal %w[custom], DurableParameters::Core::Configuration.always_permitted_parameters
    assert_equal :raise, DurableParameters::Core::Parameters.action_on_unpermitted_parameters
    assert_equal %w[other], DurableParameters::Core::Parameters.never_unpermitted_params
  end

  def test_reset_and_apply_workflow
    # Set custom configuration
    DurableParameters::Core::Configuration.action_on_unpermitted_parameters = :raise
    custom_handler = proc { |keys| puts keys }
    DurableParameters::Core::Configuration.unpermitted_notification_handler = custom_handler
    DurableParameters::Core::Configuration.always_permitted_parameters = %w[custom]

    # Apply to Parameters class
    DurableParameters::Core::Configuration.apply!
    assert_equal :raise, DurableParameters::Core::Parameters.action_on_unpermitted_parameters
    assert_equal %w[custom], DurableParameters::Core::Parameters.never_unpermitted_params

    # Reset configuration
    DurableParameters::Core::Configuration.reset!
    assert_nil DurableParameters::Core::Configuration.action_on_unpermitted_parameters
    assert_equal %w[controller action], DurableParameters::Core::Configuration.always_permitted_parameters

    # Parameters class is not automatically updated
    assert_equal :raise, DurableParameters::Core::Parameters.action_on_unpermitted_parameters
    assert_equal %w[custom], DurableParameters::Core::Parameters.never_unpermitted_params

    # Apply again to synchronize
    DurableParameters::Core::Configuration.apply!
    assert_nil DurableParameters::Core::Parameters.action_on_unpermitted_parameters
    assert_equal %w[controller action], DurableParameters::Core::Parameters.never_unpermitted_params
  end

  def test_always_permitted_parameters_default
    DurableParameters::Core::Configuration.reset!
    assert_equal %w[controller action], DurableParameters::Core::Configuration.always_permitted_parameters
  end

  def test_parameters_never_unpermitted_params_default
    # Reset to ensure defaults
    DurableParameters::Core::Configuration.reset!
    DurableParameters::Core::Configuration.apply!
    assert_equal %w[controller action], DurableParameters::Core::Parameters.never_unpermitted_params
  end

  def test_always_permitted_parameters_frozen
    DurableParameters::Core::Configuration.reset!
    params = DurableParameters::Core::Configuration.always_permitted_parameters
    assert params.frozen?
  end

  def test_always_permitted_parameters_empty_array
    DurableParameters::Core::Configuration.always_permitted_parameters = []
    assert_equal [], DurableParameters::Core::Configuration.always_permitted_parameters
  end

  def test_multiple_resets
    3.times do
      DurableParameters::Core::Configuration.action_on_unpermitted_parameters = :raise
      DurableParameters::Core::Configuration.reset!
      assert_nil DurableParameters::Core::Configuration.action_on_unpermitted_parameters
    end
  end

  def test_handler_with_lambda
    handler = ->(keys) { keys.map(&:upcase) }
    DurableParameters::Core::Configuration.unpermitted_notification_handler = handler
    assert_equal handler, DurableParameters::Core::Configuration.unpermitted_notification_handler
  end

  def test_handler_with_method_object
    # Create a simple object that responds to call
    handler = Object.new
    def handler.call(keys)
      keys.join(",")
    end

    DurableParameters::Core::Configuration.unpermitted_notification_handler = handler
    assert_equal handler, DurableParameters::Core::Configuration.unpermitted_notification_handler
  end

  def test_configuration_thread_safety
    threads = 10.times.map do |i|
      Thread.new do
        DurableParameters::Core::Configuration.action_on_unpermitted_parameters = i.even? ? :log : :raise
        sleep 0.001
        DurableParameters::Core::Configuration.action_on_unpermitted_parameters
      end
    end

    results = threads.map(&:value)
    # At least one thread should have set a value
    refute results.all?(&:nil?)
  end

  def test_always_permitted_parameters_thread_safety
    threads = 10.times.map do |i|
      Thread.new do
        DurableParameters::Core::Configuration.always_permitted_parameters = i.even? ? %w[controller action] : %w[format]
        sleep 0.001
        DurableParameters::Core::Configuration.always_permitted_parameters
      end
    end

    results = threads.map(&:value)
    # At least one thread should have set a value
    refute results.all?(&:nil?)
  end
end
