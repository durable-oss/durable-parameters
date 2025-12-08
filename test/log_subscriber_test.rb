# frozen_string_literal: true

require "test_helper"

class LogSubscriberTest < Minitest::Test
  def test_log_subscriber_is_defined
    assert defined?(StrongParameters::LogSubscriber)
  end

  def test_log_subscriber_inherits_from_active_support_log_subscriber
    assert StrongParameters::LogSubscriber < ActiveSupport::LogSubscriber
  end

  def test_logger_returns_action_controller_base_logger
    subscriber = StrongParameters::LogSubscriber.new
    assert_equal ActionController::Base.logger, subscriber.logger
  end

  def test_unpermitted_parameters_logs_message
    subscriber = StrongParameters::LogSubscriber.new
    mock_logger = Minitest::Mock.new
    mock_logger.expect :debug, nil, ["Unpermitted parameters: foo, bar"]

    subscriber.stub :logger, mock_logger do
      event = ActiveSupport::Notifications::Event.new("unpermitted_parameters.action_controller", Time.now, Time.now, "id", keys: ["foo", "bar"])
      subscriber.unpermitted_parameters(event)
    end

    mock_logger.verify
  end

  def test_unpermitted_parameters_with_single_key
    subscriber = StrongParameters::LogSubscriber.new
    mock_logger = Minitest::Mock.new
    mock_logger.expect :debug, nil, ["Unpermitted parameters: secret"]

    subscriber.stub :logger, mock_logger do
      event = ActiveSupport::Notifications::Event.new("unpermitted_parameters.action_controller", Time.now, Time.now, "id", keys: ["secret"])
      subscriber.unpermitted_parameters(event)
    end

    mock_logger.verify
  end

  def test_unpermitted_parameters_with_empty_keys
    subscriber = StrongParameters::LogSubscriber.new
    mock_logger = Minitest::Mock.new
    # With empty keys, it should not log

    subscriber.stub :logger, mock_logger do
      event = ActiveSupport::Notifications::Event.new("unpermitted_parameters.action_controller", Time.now, Time.now, "id", keys: [])
      subscriber.unpermitted_parameters(event)
    end

    mock_logger.verify # No expectations, so should not call debug
  end

  def test_unpermitted_parameters_with_nil_keys
    subscriber = StrongParameters::LogSubscriber.new
    mock_logger = Minitest::Mock.new
    # With nil keys, it should not log

    subscriber.stub :logger, mock_logger do
      event = ActiveSupport::Notifications::Event.new("unpermitted_parameters.action_controller", Time.now, Time.now, "id", keys: nil)
      subscriber.unpermitted_parameters(event)
    end

    mock_logger.verify # No expectations
  end

  def test_attach_to_action_controller_when_defined
    # Since ActionController is defined in test_helper, it should have attached
    # We can check if the subscriber is attached
    subscribers = ActiveSupport::LogSubscriber.subscribers
    attached = subscribers.any? { |s| s.is_a?(StrongParameters::LogSubscriber) }
    assert attached, "LogSubscriber should be attached to action_controller"
  end
end