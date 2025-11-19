# frozen_string_literal: true

require "durable_parameters/core"

module StrongParameters
  module Adapters
    # Rage adapter for Strong Parameters
    #
    # This adapter integrates the core Strong Parameters functionality with
    # Rage framework (a fast Rails-compatible web framework).
    #
    # @example Basic usage in a Rage controller
    #   require 'durable_parameters/adapters/rage'
    #
    #   class UsersController < RageController::API
    #     def create
    #       user_params = params.require(:user).permit(:name, :email)
    #       # ... use user_params
    #     end
    #   end
    module Rage
      # Rage-specific Parameters implementation
      class Parameters < StrongParameters::Core::Parameters
        # Rage uses string keys like Rails

        private

        def normalize_key(key)
          key.to_s
        end
      end

      # Controller integration module for Strong Parameters in Rage.
      #
      # This module provides the params method to controllers and handles
      # ParameterMissing exceptions with a 400 Bad Request response.
      module Controller
        # Access request parameters as a Parameters object.
        #
        # @return [Parameters] the request parameters wrapped in a Parameters object
        def params
          @_strong_params ||= begin
            # Get raw params from Rage controller
            raw_params = if defined?(super)
              super
            else
              {}
            end

            ::StrongParameters::Adapters::Rage::Parameters.new(raw_params)
          end
        end

        # Set the parameters for this request.
        #
        # @param val [Hash, Parameters] the parameters to set
        # @return [Parameters] the parameters
        def params=(val)
          @_strong_params = val.is_a?(Hash) ? ::StrongParameters::Adapters::Rage::Parameters.new(val) : val
        end

        # Handle parameter missing errors
        def handle_parameter_missing(exception)
          render json: {error: "Required parameter missing: #{exception.param}"}, status: 400
        end

        # Handle forbidden attributes errors
        def handle_forbidden_attributes(exception)
          render json: {error: "Forbidden attributes in mass assignment"}, status: 400
        end

        # Handle unpermitted parameters errors
        def handle_unpermitted_parameters(exception)
          render json: {error: "Unpermitted parameters: #{exception.params.join(", ")}"}, status: 400
        end

        # Set up error handling when this module is included
        def self.included(base)
          # Rage uses rescue_from for error handling (Rails-compatible)
          if base.respond_to?(:rescue_from)
            base.rescue_from StrongParameters::Core::ParameterMissing, with: :handle_parameter_missing
            base.rescue_from StrongParameters::Core::ForbiddenAttributes, with: :handle_forbidden_attributes
            base.rescue_from StrongParameters::Core::UnpermittedParameters, with: :handle_unpermitted_parameters
          end
        end
      end

      # Setup Rage integration
      def self.setup!
        # Configure logging for unpermitted parameters
        # Rage uses RAGE_ENV environment variable
        env = ENV["RAGE_ENV"] || ENV["RACK_ENV"] || "development"

        if env == "development" || env == "test"
          ::StrongParameters::Adapters::Rage::Parameters.action_on_unpermitted_parameters = :log
          ::StrongParameters::Adapters::Rage::Parameters.unpermitted_notification_handler = lambda do |keys|
            # Rage has a logger available
            logger = if defined?(::Rage) && ::Rage.respond_to?(:logger)
              ::Rage.logger
            elsif defined?(::Rage::Logger)
              ::Rage::Logger.logger
            end

            logger&.warn("Unpermitted parameters: #{keys.join(", ")}")
          end
        end

        # Integrate with Rage controllers if available
        if defined?(::RageController::API)
          ::RageController::API.include(Controller)
        end

        # Also integrate with base controller if available
        if defined?(::Rage::Controller)
          ::Rage::Controller.include(Controller)
        end
      end

      # Convenience method for manual integration
      def self.included(base)
        base.include Controller
      end
    end
  end
end
