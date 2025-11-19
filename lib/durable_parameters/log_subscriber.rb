# frozen_string_literal: true

require "active_support/log_subscriber"
require "active_support/notifications"

module StrongParameters
  # Log subscriber for unpermitted parameters notifications.
  #
  # This subscriber listens for unpermitted parameter events and logs them
  # using the configured logger. This is helpful for development and testing
  # to identify parameters that need to be explicitly permitted.
  class LogSubscriber < ActiveSupport::LogSubscriber
    # Handle unpermitted_parameters notification event.
    #
    # @param event [ActiveSupport::Notifications::Event] the notification event
    # @return [void]
    def unpermitted_parameters(event)
      unpermitted_keys = event.payload[:keys]
      debug("Unpermitted parameters: #{unpermitted_keys.join(", ")}")
    end

    # Returns the logger for this subscriber.
    #
    # @return [Logger] the Action Controller logger
    def logger
      ActionController::Base.logger
    end
  end
end

# Only attach if ActionController is loaded (Rails environment)
if defined?(ActionController)
  StrongParameters::LogSubscriber.attach_to :action_controller
end
