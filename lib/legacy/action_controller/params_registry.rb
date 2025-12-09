# frozen_string_literal: true

module Legacy
  module ActionController
    # Legacy wrapper for ParamsRegistry to maintain backward compatibility.
    #
    # This class delegates all operations to DurableParameters::Core::ParamsRegistry
    # to avoid code duplication while maintaining the legacy namespace.
    #
    # @deprecated Use DurableParameters::Core::ParamsRegistry or ActionController::ParamsRegistry instead
    #
    # @example Registering a params class (legacy)
    #   Legacy::ActionController::ParamsRegistry.register(:user, UserParams)
    #
    # @example Looking up a params class (legacy)
    #   Legacy::ActionController::ParamsRegistry.lookup(:user) # => UserParams
    class ParamsRegistry
      class << self
        # @see DurableParameters::Core::ParamsRegistry.register
        def register(model_name, params_class)
          DurableParameters::Core::ParamsRegistry.register(model_name, params_class)
        end

        # @see DurableParameters::Core::ParamsRegistry.lookup
        def lookup(model_name)
          DurableParameters::Core::ParamsRegistry.lookup(model_name)
        end

        # @see DurableParameters::Core::ParamsRegistry.permitted_attributes_for
        def permitted_attributes_for(model_name, action: nil)
          DurableParameters::Core::ParamsRegistry.permitted_attributes_for(model_name, action: action)
        end

        # @see DurableParameters::Core::ParamsRegistry.registered?
        def registered?(model_name)
          DurableParameters::Core::ParamsRegistry.registered?(model_name)
        end

        # @see DurableParameters::Core::ParamsRegistry.clear!
        def clear!
          DurableParameters::Core::ParamsRegistry.clear!
        end

        # @see DurableParameters::Core::ParamsRegistry.registered_models
        def registered_models
          DurableParameters::Core::ParamsRegistry.registered_models
        end
      end
    end
  end
end
