# frozen_string_literal: true

# Core framework-agnostic durable parameters implementation
#
# The core module provides all essential functionality without any framework dependencies:
# - Parameters: Hash-based parameter filtering and whitelisting
# - ApplicationParams: Declarative DSL for defining parameter permissions
# - ParamsRegistry: Centralized registry for params classes
# - ForbiddenAttributesProtection: Mass assignment protection mixin
# - Configuration: Centralized configuration management
# - MetadataValidation: Shared metadata validation logic
# - KeyNormalization: Shared key normalization logic
require "durable_parameters/core/configuration"
require "durable_parameters/core/key_normalization"
require "durable_parameters/core/metadata_validation"
require "durable_parameters/core/parameters"
require "durable_parameters/core/application_params"
require "durable_parameters/core/params_registry"
require "durable_parameters/core/forbidden_attributes_protection"
