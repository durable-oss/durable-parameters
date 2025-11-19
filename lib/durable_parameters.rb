# frozen_string_literal: true

# Strong Parameters provides a whitelist-based approach to mass assignment protection.
#
# This gem provides a framework-agnostic approach to parameter filtering and mass
# assignment protection, with adapters for various Ruby web frameworks including
# Rails, Sinatra, Hanami, and Rage.
#
# @see StrongParameters::Core::Parameters
# @see StrongParameters::Core::ApplicationParams
# @see StrongParameters::Core::ParamsRegistry

require "durable_parameters/version"
require "durable_parameters/core"

# Auto-detect and load framework adapter
if defined?(Rails)
  # Rails is loaded - use Rails adapter
  require "durable_parameters/railtie"
  require "durable_parameters/log_subscriber"
elsif defined?(Sinatra)
  # Sinatra is loaded - auto-setup Sinatra adapter
  require "durable_parameters/adapters/sinatra"
elsif defined?(Hanami)
  # Hanami is loaded - auto-setup Hanami adapter
  require "durable_parameters/adapters/hanami"
  StrongParameters::Adapters::Hanami.setup!
elsif defined?(Rage) || defined?(RageController)
  # Rage is loaded - auto-setup Rage adapter
  require "durable_parameters/adapters/rage"
  StrongParameters::Adapters::Rage.setup!
end

# Provide top-level convenience aliases
module StrongParameters
  # Convenience aliases for core classes
  Parameters = Core::Parameters unless defined?(Parameters)
  ApplicationParams = Core::ApplicationParams unless defined?(ApplicationParams)
  ParamsRegistry = Core::ParamsRegistry unless defined?(ParamsRegistry)
  ForbiddenAttributesProtection = Core::ForbiddenAttributesProtection unless defined?(ForbiddenAttributesProtection)
end
