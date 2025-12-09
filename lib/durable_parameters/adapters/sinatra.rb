# frozen_string_literal: true

require "sinatra/base"
require "durable_parameters/core"

module DurableParameters
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
    #     register DurableParameters::Adapters::Sinatra
    #
    #     post '/users' do
    #       user_params = strong_params.require(:user).permit(:name, :email)
    #       # ... use user_params
    #     end
    #   end
    module Sinatra
      # Sinatra-specific Parameters implementation
      #
      # Extends the core Parameters class for Sinatra applications.
      # Sinatra typically uses string keys, so normalization converts to strings.
      class Parameters < DurableParameters::Core::Parameters
        private

        # Normalize a key by converting to string (Sinatra convention)
        # @param key [Symbol, String] the key to normalize
        # @return [String] the normalized key
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
          @_strong_params ||= ::DurableParameters::Adapters::Sinatra::Parameters.new(params)
        end

        # Alias for strong_params for Rails compatibility
        alias_method :sp, :strong_params
      end

      # Error handler for ParameterMissing
      module ErrorHandlers
        def self.registered(app)
          app.error DurableParameters::Core::ParameterMissing do |exception|
            halt 400, {"error" => "Required parameter missing: #{exception.param}"}.to_json
          end

          app.error DurableParameters::Core::ForbiddenAttributes do |exception|
            halt 400, {"error" => "Forbidden attributes in mass assignment"}.to_json
          end

          app.error DurableParameters::Core::UnpermittedParameters do |exception|
            halt 400, {"error" => "Unpermitted parameters: #{exception.params.join(", ")}"}.to_json
          end
        end
      end

      # Register the adapter with a Sinatra application
      def self.registered(app)
        app.helpers Helpers
        app.register ErrorHandlers

        # Configure logging for unpermitted parameters in development
        if app.development?
          ::DurableParameters::Adapters::Sinatra::Parameters.action_on_unpermitted_parameters = :log
          ::DurableParameters::Adapters::Sinatra::Parameters.unpermitted_notification_handler = lambda do |keys|
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
  ::Sinatra.register DurableParameters::Adapters::Sinatra
end
