# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/array/wrap"
require "action_controller"
require "action_dispatch/http/upload"
require "durable_parameters/core"

module StrongParameters
  module Adapters
    # Rails adapter for Strong Parameters
    #
    # This adapter integrates the core Strong Parameters functionality with
    # Rails/ActionController, providing Rails-specific features like:
    # - ActiveSupport::HashWithIndifferentAccess integration
    # - ActionDispatch uploaded file support
    # - Rack uploaded file support
    # - ActiveSupport::Concern integration
    # - Automatic controller integration
    module Rails
      # Extension module to add Durable Parameters functionality to Rails' ActionController::Parameters
      module ParametersExtension
        # Track the required key for automatic params class inference
        attr_accessor :required_key

        # Transform and permit parameters using a declarative params class.
        #
        # This method provides a declarative approach to parameter filtering using
        # params classes. It automatically looks up the appropriate params class
        # based on the required_key if not explicitly provided.
        #
        # Transformations defined in the params class are applied before filtering.
        #
        # @param params_class [Class, Symbol, nil] optional params class or :__infer__ (default)
        # @param options [Hash] metadata and configuration options
        # @return [ActionController::Parameters] permitted parameters
        def transform_params(params_class = :__infer__, **options)
          # Extract known options
          action = options[:action]
          additional_attrs = options[:additional_attrs] || []

          # Infer params class from required_key if not explicitly provided
          if params_class == :__infer__
            if instance_variable_defined?(:@required_key) && @required_key
              params_class = ::ActionController::ParamsRegistry.lookup(@required_key)
            else
              # If no required_key and no explicit params_class, return empty permitted params
              return self.class.new.permit!
            end
          end

          # Handle case where params_class is nil
          if params_class.nil?
            return self.class.new.permit!
          end

          # Validate metadata keys (excluding known options)
          metadata_keys = options.keys - [:action, :additional_attrs]
          validate_metadata_keys!(params_class, metadata_keys)

          # Apply transformations first (before filtering)
          transformed_hash = params_class.apply_transformations(to_unsafe_h, options)

          # Create a new Parameters object from the transformed hash
          transformed_params = self.class.new(transformed_hash)

          # Get permitted attributes and apply them
          permitted_attrs = params_class.permitted_attributes(action: action)
          permitted_attrs += additional_attrs
          transformed_params.permit(*permitted_attrs)
        end

        # Permit parameters using a registered params class for a model.
        #
        # This is a convenience method that looks up the params class for the given
        # model name and applies it to permit parameters.
        #
        # @param model_name [Symbol, String] the model name to look up
        # @param action [Symbol, String, nil] optional action for filtering
        # @param additional_attrs [Array<Symbol>] additional attributes to permit
        # @return [ActionController::Parameters] permitted parameters
        def permit_by_model(model_name, action: nil, additional_attrs: [])
          params_class = ::ActionController::ParamsRegistry.lookup(model_name)
          transform_params(params_class, action: action, additional_attrs: additional_attrs)
        end

        # Override require to track the required_key for transform_params
        def require(key)
          value = super
          # Track the required key so transform_params can infer the params class
          if value.is_a?(::ActionController::Parameters)
            value.instance_variable_set(:@required_key, key.to_sym)
          end
          value
        end

        # Override slice to preserve required_key
        def slice(*keys)
          sliced = super
          if sliced.is_a?(::ActionController::Parameters)
            sliced.instance_variable_set(:@required_key, @required_key)
          end
          sliced
        end

        private

        # Validate that all provided metadata keys are allowed by the params class.
        def validate_metadata_keys!(params_class, metadata_keys)
          return if metadata_keys.empty?

          disallowed_keys = metadata_keys.reject { |key| params_class.metadata_allowed?(key) }

          return unless disallowed_keys.any?

          # Build a helpful error message
          keys_list = disallowed_keys.map(&:inspect).join(", ")
          class_name = params_class.name

          raise ArgumentError, <<~ERROR.strip
            Metadata key(s) #{keys_list} not allowed for #{class_name}.

            To fix this, declare them in your params class:

              class #{class_name} < ApplicationParams
                metadata #{disallowed_keys.map(&:inspect).join(", ")}
              end

            Note: :current_user is always allowed and doesn't need to be declared.
          ERROR
        end
      end

      # Rails-specific Parameters implementation (deprecated, kept for compatibility)
      class Parameters < StrongParameters::Core::Parameters
        # Override to use ActiveSupport::HashWithIndifferentAccess behavior
        def initialize(attributes = nil)
          @permitted = false
          @required_key = nil

          if attributes
            # Convert to hash with indifferent access
            hash = attributes.is_a?(Hash) ? attributes.with_indifferent_access : {}
            hash.each { |k, v| self[k] = v }
          end
        end

        # Access parameter value with indifferent access (string or symbol)
        def [](key)
          key = key.to_s if key.is_a?(Symbol)
          convert_hashes_to_parameters(key, super)
        end

        def []=(key, value)
          key = key.to_s if key.is_a?(Symbol)
          super
        end

        def has_key?(key)
          key = key.to_s if key.is_a?(Symbol)
          super
        end

        alias_method :key?, :has_key?
        alias_method :include?, :has_key?

        def delete(key)
          key = key.to_s if key.is_a?(Symbol)
          super
        end

        def fetch(key, *args)
          key = key.to_s if key.is_a?(Symbol)
          super
        end

        private

        def normalize_key(key)
          key.to_s
        end

        # Rails-specific permitted scalar types
        PERMITTED_SCALAR_TYPES = (
          StrongParameters::Core::Parameters::PERMITTED_SCALAR_TYPES + [
            ActionDispatch::Http::UploadedFile,
            Rack::Test::UploadedFile
          ]
        ).freeze

        def permitted_scalar?(value)
          PERMITTED_SCALAR_TYPES.any? { |type| value.is_a?(type) }
        end
      end

      # Map core exceptions to ActionController namespace for compatibility
      module ActionController
        ParameterMissing = StrongParameters::Core::ParameterMissing
        UnpermittedParameters = StrongParameters::Core::UnpermittedParameters

        # Controller integration module for Strong Parameters in Rails.
        #
        # This module provides the params method to controllers and handles
        # ParameterMissing exceptions with a 400 Bad Request response.
        module StrongParameters
          extend ActiveSupport::Concern

          included do
            rescue_from(ActionController::ParameterMissing) do |parameter_missing_exception|
              render plain: "Required parameter missing: #{parameter_missing_exception.param}",
                status: :bad_request
            end
          end

          # Access request parameters as a Parameters object.
          #
          # @return [Parameters] the request parameters wrapped in a Parameters object
          def params
            @_params ||= ::StrongParameters::Adapters::Rails::Parameters.new(request.parameters)
          end

          # Set the parameters for this request.
          #
          # @param val [Hash, Parameters] the parameters to set
          # @return [Parameters] the parameters
          def params=(val)
            @_params = val.is_a?(Hash) ? ::StrongParameters::Adapters::Rails::Parameters.new(val) : val
          end
        end
      end

      # ActiveModel integration
      module ActiveModel
        ForbiddenAttributes = StrongParameters::Core::ForbiddenAttributes

        # Protection module for Active Model mass assignment.
        module ForbiddenAttributesProtection
          # Check if parameters are permitted before mass assignment.
          #
          # @param options [Array] mass assignment options, first element should be attributes hash
          # @return [Object] result of super if permitted
          # @raise [ForbiddenAttributes] if parameters are not permitted
          def sanitize_for_mass_assignment(*options)
            new_attributes = options.first
            if !new_attributes.respond_to?(:permitted?) || new_attributes.permitted?
              super
            else
              raise ::StrongParameters::Core::ForbiddenAttributes
            end
          end
        end
      end

      # Setup Rails integration
      def self.setup!
        # Extend the existing Rails ActionController::Parameters with our functionality
        # Use prepend so our methods override existing ones
        ::ActionController::Parameters.class_eval do
          prepend StrongParameters::Adapters::Rails::ParametersExtension
        end

        # Add our new classes to ActionController namespace
        ::ActionController.const_set(:ApplicationParams, ::StrongParameters::Core::ApplicationParams) unless ::ActionController.const_defined?(:ApplicationParams)
        ::ActionController.const_set(:ParamsRegistry, ::StrongParameters::Core::ParamsRegistry) unless ::ActionController.const_defined?(:ParamsRegistry)

        # Integrate with ActionController
        ActiveSupport.on_load(:action_controller) do
          include ::StrongParameters::Adapters::Rails::ActionController::StrongParameters
        end

        # Inject into ActiveModel using const_set (Ruby 3.5 compatible) - only if ActiveModel is loaded
        if defined?(::ActiveModel)
          ::ActiveModel.const_set(:ForbiddenAttributes, ::StrongParameters::Core::ForbiddenAttributes) unless ::ActiveModel.const_defined?(:ForbiddenAttributes)
          ::ActiveModel.const_set(:ForbiddenAttributesProtection, ::StrongParameters::Adapters::Rails::ActiveModel::ForbiddenAttributesProtection) unless ::ActiveModel.const_defined?(:ForbiddenAttributesProtection)
        end
      end
    end
  end
end
