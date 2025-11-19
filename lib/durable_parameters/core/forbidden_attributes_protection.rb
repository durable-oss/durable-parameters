# frozen_string_literal: true

module StrongParameters
  module Core
    # Exception raised when attempting mass assignment with unpermitted parameters.
    #
    # This exception is raised when Parameters are used in mass assignment
    # without being explicitly permitted using permit() or permit!().
    #
    # @example
    #   User.new(params[:user])
    #   # => StrongParameters::Core::ForbiddenAttributes (if :user params not permitted)
    class ForbiddenAttributes < StandardError
    end

    # Protection module for mass assignment.
    #
    # This module can be included in model classes to provide protection
    # against unpermitted mass assignment.
    #
    # @example Include in a model
    #   class Post
    #     include StrongParameters::Core::ForbiddenAttributesProtection
    #
    #     def initialize(attributes = {})
    #       assign_attributes(attributes)
    #     end
    #
    #     def assign_attributes(attributes)
    #       attributes = sanitize_for_mass_assignment(attributes)
    #       # ... assign attributes
    #     end
    #   end
    module ForbiddenAttributesProtection
      # Check if parameters are permitted before mass assignment.
      #
      # @param attributes [Object] mass assignment attributes
      # @return [Object] the attributes if permitted
      # @raise [ForbiddenAttributes] if parameters are not permitted
      def sanitize_for_mass_assignment(attributes)
        if attributes.respond_to?(:permitted?) && !attributes.permitted?
          raise ForbiddenAttributes
        end
        attributes
      end
    end
  end
end
