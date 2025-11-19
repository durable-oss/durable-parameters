# frozen_string_literal: true

module ActiveModel
  # Exception raised when attempting mass assignment with unpermitted parameters.
  #
  # This exception is raised when ActionController::Parameters are used in
  # mass assignment without being explicitly permitted using permit() or permit!().
  #
  # @example
  #   User.new(params[:user])
  #   # => ActiveModel::ForbiddenAttributes (if :user params not permitted)
  class ForbiddenAttributes < StandardError
  end

  # Protection module for Active Model mass assignment.
  #
  # This module overrides sanitize_for_mass_assignment to check that
  # ActionController::Parameters objects are marked as permitted before
  # allowing mass assignment.
  #
  # @example Include in a model
  #   class Post < ActiveRecord::Base
  #     include ActiveModel::ForbiddenAttributesProtection
  #   end
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
        raise ActiveModel::ForbiddenAttributes
      end
    end
  end
end
