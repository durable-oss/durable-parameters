# frozen_string_literal: true

require "sinatra/base"
require "durable_parameters/core"

module StrongParameters
  module Adapters
    # Sinatra adapter for Strong Parameters
    #
    # This adapter integrates the core Strong Parameters functionality with
    # Sinatra applications, providing a simple params wrapper and error handling.
    #
    # @example Basic usage in a Sinatra app
    #   require 'sinatra/base'
    #   require 'durable_parameters/adapters/sinatra'
    #
    #   class MyApp < Sinatra::Base
    #     register StrongParameters::Adapters::Sinatra
    #
    #     post '/users' do
    #       user_params = strong_params.require(:user).permit(:name, :email)
    #       # ... use user_params
    #     end
    #   end
    module Sinatra
      # Sinatra-specific Parameters implementation
      class Parameters < StrongParameters::Core::Parameters
        # Sinatra typically uses string keys, so we normalize to strings

        private

        def normalize_key(key)
          key.to_s
        end
      end

      # Module to register with Sinatra applications
      module Helpers
        # Access request parameters as a Strong Parameters object.
        #
        # @return [Parameters] the request parameters wrapped in a Parameters object
        def strong_params
          @_strong_params ||= ::StrongParameters::Adapters::Sinatra::Parameters.new(params)
        end

        # Alias for strong_params for Rails compatibility
        alias_method :sp, :strong_params
      end

      # Error handler for ParameterMissing
      module ErrorHandlers
        def self.registered(app)
          app.error StrongParameters::Core::ParameterMissing do
            halt 400, {error: "Required parameter missing: #{env["sinatra.error"].param}"}.to_json
          end

          app.error StrongParameters::Core::ForbiddenAttributes do
            halt 400, {error: "Forbidden attributes in mass assignment"}.to_json
          end

          app.error StrongParameters::Core::UnpermittedParameters do
            halt 400, {error: "Unpermitted parameters: #{env["sinatra.error"].params.join(", ")}"}.to_json
          end
        end
      end

      # Register the adapter with a Sinatra application
      def self.registered(app)
        app.helpers Helpers
        app.register ErrorHandlers

        # Configure logging for unpermitted parameters in development
        if app.development?
          ::StrongParameters::Adapters::Sinatra::Parameters.action_on_unpermitted_parameters = :log
          ::StrongParameters::Adapters::Sinatra::Parameters.unpermitted_notification_handler = lambda do |keys|
            app.logger.warn "Unpermitted parameters: #{keys.join(", ")}" if app.respond_to?(:logger)
          end
        end
      end

      # Convenience method for class-level registration
      def self.included(base)
        base.register self if base.respond_to?(:register)
      end
    end
  end
end

# Register with Sinatra::Base if it's loaded
if defined?(::Sinatra::Base)
  ::Sinatra.register StrongParameters::Adapters::Sinatra
end
