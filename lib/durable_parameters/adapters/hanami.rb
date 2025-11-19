# frozen_string_literal: true

require 'durable_parameters/core'

module StrongParameters
  module Adapters
    # Hanami adapter for Strong Parameters
    #
    # This adapter integrates the core Strong Parameters functionality with
    # Hanami applications, providing integration with Hanami actions and params.
    #
    # @example Basic usage in a Hanami action (Hanami 2.x)
    #   require 'durable_parameters/adapters/hanami'
    #
    #   module MyApp
    #     module Actions
    #       module Users
    #         class Create < MyApp::Action
    #           include StrongParameters::Adapters::Hanami::Action
    #
    #           def handle(request, response)
    #             user_params = strong_params(request.params).require(:user).permit(:name, :email)
    #             # ... use user_params
    #           end
    #         end
    #       end
    #     end
    #   end
    #
    # @example Basic usage in a Hanami action (Hanami 1.x)
    #   require 'durable_parameters/adapters/hanami'
    #
    #   module Web
    #     module Controllers
    #       module Users
    #         class Create
    #           include Web::Action
    #           include StrongParameters::Adapters::Hanami::Action
    #
    #           def call(params)
    #             user_params = strong_params.require(:user).permit(:name, :email)
    #             # ... use user_params
    #           end
    #         end
    #       end
    #     end
    #   end
    module Hanami
      # Hanami-specific Parameters implementation
      class Parameters < StrongParameters::Core::Parameters
        # Hanami uses symbol keys by default
        private

        def normalize_key(key)
          key.to_s
        end
      end

      # Module to include in Hanami actions
      module Action
        # Access request parameters as a Strong Parameters object.
        #
        # For Hanami 2.x, pass the params object explicitly
        # For Hanami 1.x, it will use the params from the action context
        #
        # @param params_obj [Object, nil] the params object (Hanami 2.x) or nil (Hanami 1.x)
        # @return [Parameters] the request parameters wrapped in a Parameters object
        def strong_params(params_obj = nil)
          params_hash = if params_obj
            # Hanami 2.x - params passed explicitly
            params_obj.respond_to?(:to_h) ? params_obj.to_h : params_obj
          elsif respond_to?(:params)
            # Hanami 1.x - params available on action
            params.respond_to?(:to_h) ? params.to_h : params
          else
            {}
          end

          ::StrongParameters::Adapters::Hanami::Parameters.new(params_hash)
        end

        # Alias for strong_params
        alias sp strong_params

        # Handle ParameterMissing errors (Hanami 2.x style)
        def handle_parameter_missing(exception)
          halt 400, { error: "Required parameter missing: #{exception.param}" }.to_json
        end

        # Handle ForbiddenAttributes errors (Hanami 2.x style)
        def handle_forbidden_attributes(exception)
          halt 400, { error: "Forbidden attributes in mass assignment" }.to_json
        end

        # Handle UnpermittedParameters errors (Hanami 2.x style)
        def handle_unpermitted_parameters(exception)
          halt 400, { error: "Unpermitted parameters: #{exception.params.join(', ')}" }.to_json
        end

        # Set up error handling when this module is included
        def self.included(base)
          # Set up automatic error handling if possible
          if base.respond_to?(:handle_exception)
            base.handle_exception StrongParameters::Core::ParameterMissing => :handle_parameter_missing
            base.handle_exception StrongParameters::Core::ForbiddenAttributes => :handle_forbidden_attributes
            base.handle_exception StrongParameters::Core::UnpermittedParameters => :handle_unpermitted_parameters
          end
        end
      end

      # Setup Hanami integration
      def self.setup!(app = nil)
        # Configure logging for unpermitted parameters in development
        env = if app && app.respond_to?(:config)
          app.config.env
        elsif defined?(::Hanami) && ::Hanami.respond_to?(:env)
          ::Hanami.env
        else
          ENV['HANAMI_ENV'] || ENV['RACK_ENV'] || 'development'
        end

        if env == 'development' || env == :development
          ::StrongParameters::Adapters::Hanami::Parameters.action_on_unpermitted_parameters = :log
          ::StrongParameters::Adapters::Hanami::Parameters.unpermitted_notification_handler = lambda do |keys|
            # Try to get logger from Hanami
            logger = if defined?(::Hanami) && ::Hanami.respond_to?(:logger)
              ::Hanami.logger
            elsif app && app.respond_to?(:logger)
              app.logger
            end

            logger&.warn("Unpermitted parameters: #{keys.join(', ')}")
          end
        end
      end
    end
  end
end
