# frozen_string_literal: true

module ActionController
  # Singleton registry for storing and retrieving param class definitions.
  #
  # ParamsRegistry provides a central location to register and look up params
  # classes for models. This enables automatic inference of params classes in
  # transform_params based on the model name.
  #
  # @example Registering a params class
  #   ParamsRegistry.register(:user, UserParams)
  #
  # @example Looking up a params class
  #   ParamsRegistry.lookup(:user) # => UserParams
  #
  # @example Getting permitted attributes
  #   ParamsRegistry.permitted_attributes_for(:user, action: :create)
  class ParamsRegistry
    class << self
      # Register a params class for a model.
      #
      # The model name is normalized (underscored and symbolized) before storage.
      #
      # @param model_name [String, Symbol] the model name (e.g., 'User', 'Account')
      # @param params_class [Class] the params class (e.g., UserParams)
      # @return [Class] the registered params class
      # @example
      #   ParamsRegistry.register(:user, UserParams)
      #   ParamsRegistry.register('BlogPost', BlogPostParams)
      def register(model_name, params_class)
        registry[normalize_key(model_name)] = params_class
      end

      # Look up the params class for a model.
      #
      # @param model_name [String, Symbol] the model name
      # @return [Class, nil] the params class or nil if not found
      # @example
      #   ParamsRegistry.lookup(:user) # => UserParams
      #   ParamsRegistry.lookup(:unknown) # => nil
      def lookup(model_name)
        registry[normalize_key(model_name)]
      end

      # Get permitted attributes for a model.
      #
      # @param model_name [String, Symbol] the model name
      # @param action [Symbol, String, nil] optional action name for filtering
      # @return [Array<Symbol, Hash>] array of permitted attributes
      # @example
      #   ParamsRegistry.permitted_attributes_for(:user)
      #   ParamsRegistry.permitted_attributes_for(:post, action: :create)
      def permitted_attributes_for(model_name, action: nil)
        params_class = lookup(model_name)
        return [] unless params_class

        params_class.permitted_attributes(action: action)
      end

      # Check if a model has registered params.
      #
      # @param model_name [String, Symbol] the model name
      # @return [Boolean] true if registered, false otherwise
      # @example
      #   ParamsRegistry.registered?(:user) # => true
      #   ParamsRegistry.registered?(:unknown) # => false
      def registered?(model_name)
        registry.key?(normalize_key(model_name))
      end

      # Clear the registry.
      #
      # This is primarily useful for testing to ensure a clean slate between tests.
      #
      # @return [Hash] the empty registry
      def clear!
        registry.clear
      end

      # Get all registered model names.
      #
      # @return [Array<String>] array of model names as strings
      # @example
      #   ParamsRegistry.registered_models # => ["user", "post", "comment"]
      def registered_models
        registry.keys.map(&:to_s)
      end

      private

      # @return [Hash<Symbol, Class>] the internal registry hash
      def registry
        @registry ||= {}
      end

      # Normalize a key by underscoring and symbolizing it.
      #
      # @param key [String, Symbol] the key to normalize
      # @return [Symbol] the normalized key
      # @example
      #   normalize_key('BlogPost') # => :blog_post
      #   normalize_key(:user) # => :user
      def normalize_key(key)
        key.to_s.underscore.to_sym
      end
    end
  end
end
