# frozen_string_literal: true

module DurableParameters
  module Core
    # Shared module for metadata key validation.
    #
    # This module provides a common implementation for validating metadata keys
    # against a params class's declared metadata allowlist.
    module MetadataValidation
      # Validate that all provided metadata keys are allowed by the params class.
      #
      # @param params_class [Class] the params class to validate against
      # @param metadata_keys [Array<Symbol>] the metadata keys to validate
      # @raise [ArgumentError] if any metadata keys are not declared
      # @return [void]
      def validate_metadata_keys!(params_class, metadata_keys)
        return if metadata_keys.empty?

        disallowed_keys = metadata_keys.reject { |key| key == :current_user || params_class.allowed_metadata_key?(key) }

        return unless disallowed_keys.any?

        # Build a helpful error message
        keys_list = disallowed_keys.map(&:inspect).join(", ")
        class_name = params_class.name || "AnonymousParamsClass"

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
  end
end
