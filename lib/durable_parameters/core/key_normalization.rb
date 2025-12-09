# frozen_string_literal: true

module DurableParameters
  module Core
    # Shared module for key normalization across adapters.
    #
    # This module provides a consistent way to normalize keys (convert to strings)
    # across different framework adapters.
    module KeyNormalization
      # Normalize a key by converting it to a string.
      #
      # @param key [Symbol, String] the key to normalize
      # @return [String] the normalized key
      # @example
      #   normalize_key(:user) # => "user"
      #   normalize_key("user") # => "user"
      def normalize_key(key)
        key.to_s
      end

      # Normalize a key with underscore conversion for registry lookups.
      #
      # This is used by the registry to convert CamelCase model names to snake_case.
      #
      # @param key [Symbol, String] the key to normalize
      # @return [Symbol] the normalized key as a symbol
      # @example
      #   normalize_registry_key("BlogPost") # => :blog_post
      #   normalize_registry_key(:User) # => :user
      def normalize_registry_key(key)
        if key.to_s.respond_to?(:underscore)
          key.to_s.underscore.to_sym
        else
          # Fallback for environments without ActiveSupport
          key.to_s.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.to_sym
        end
      end
    end
  end
end
