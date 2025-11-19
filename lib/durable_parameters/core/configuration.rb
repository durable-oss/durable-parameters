# frozen_string_literal: true

module StrongParameters
  module Core
    # Configuration module for StrongParameters behavior.
    #
    # This module provides centralized configuration for how strong parameters
    # behaves throughout the application, including handling of unpermitted
    # parameters and notification mechanisms.
    #
    # @example Configure action on unpermitted parameters
    #   StrongParameters::Core::Configuration.action_on_unpermitted_parameters = :log
    #
    # @example Set custom notification handler
    #   StrongParameters::Core::Configuration.unpermitted_notification_handler = ->(keys) do
    #     Rails.logger.warn("Unpermitted parameters: #{keys.join(', ')}")
    #   end
    module Configuration
      class << self
        # Action to take when unpermitted parameters are detected.
        #
        # **Options:**
        # - `:log` - Log unpermitted parameters via notification handler
        # - `:raise` - Raise UnpermittedParameters exception
        # - `false` or `nil` - Ignore unpermitted parameters (not recommended for production)
        #
        # @return [Symbol, Boolean, nil] the configured action
        #
        # @example Enable logging
        #   Configuration.action_on_unpermitted_parameters = :log
        #
        # @example Enable strict mode (raise on unpermitted)
        #   Configuration.action_on_unpermitted_parameters = :raise
        attr_accessor :action_on_unpermitted_parameters

        # Handler for unpermitted parameter notifications.
        #
        # This proc/lambda is called when unpermitted parameters are detected
        # and `action_on_unpermitted_parameters` is set to `:log`. The handler
        # receives an array of unpermitted parameter keys.
        #
        # @return [Proc, nil] the notification handler
        #
        # @example Set custom handler
        #   Configuration.unpermitted_notification_handler = ->(keys) do
        #     MyLogger.warn("Unpermitted: #{keys.join(', ')}")
        #   end
        attr_accessor :unpermitted_notification_handler

        # Parameters that are never considered unpermitted.
        #
        # These are typically framework-added parameters that are not security
        # concerns (like 'controller' and 'action' in Rails).
        #
        # @return [Array<String>] array of parameter names to always allow
        attr_accessor :always_permitted_parameters

        # Reset configuration to default values.
        #
        # @return [void]
        def reset!
          @action_on_unpermitted_parameters = nil
          @unpermitted_notification_handler = nil
          @always_permitted_parameters = %w[controller action].freeze
        end

        # Apply configuration to Parameters class.
        #
        # This method synchronizes the configuration module settings with the
        # Parameters class class variables for backwards compatibility.
        #
        # @return [void]
        def apply!
          Parameters.action_on_unpermitted_parameters = action_on_unpermitted_parameters
          Parameters.unpermitted_notification_handler = unpermitted_notification_handler
        end
      end

      # Initialize with defaults
      reset!
    end
  end
end
