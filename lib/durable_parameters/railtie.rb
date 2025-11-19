# frozen_string_literal: true

require 'rails/railtie'
require 'durable_parameters/adapters/rails'

module StrongParameters
  # Rails integration for Strong Parameters.
  #
  # This railtie configures Strong Parameters within Rails applications,
  # setting up generators, autoload paths, and parameter logging.
  class Railtie < ::Rails::Railtie
    # Setup Rails adapter
    config.before_initialize do
      StrongParameters::Adapters::Rails.setup!
    end

    # Configure scaffold generator to use strong_parameters controller template
    if config.respond_to?(:app_generators)
      config.app_generators.scaffold_controller = :strong_parameters_controller
    else
      config.generators.scaffold_controller = :strong_parameters_controller
    end

    # Configure action on unpermitted parameters (log in dev/test, silent in production)
    initializer 'strong_parameters.config', before: 'action_controller.set_configs' do |app|
      StrongParameters::Adapters::Rails::Parameters.action_on_unpermitted_parameters =
        app.config.action_controller.delete(:action_on_unpermitted_parameters) do
          (Rails.env.test? || Rails.env.development?) ? :log : false
        end
    end

    # Add app/params directory to autoload paths for params classes
    initializer 'strong_parameters.autoload_params' do |app|
      params_path = app.root.join('app', 'params')

      # Add to autoload paths if directory exists
      if params_path.directory?
        ActiveSupport::Dependencies.autoload_paths << params_path.to_s
      end
    end

    # Automatically load and register all params classes after Rails initialization
    config.after_initialize do |app|
      params_path = app.root.join('app', 'params')

      next unless params_path.directory?

      # Load all params class files
      Dir[params_path.join('**', '*_params.rb')].each do |file|
        require_dependency file
      end

      # Register all ApplicationParams subclasses with the registry
      next unless defined?(StrongParameters::Core::ApplicationParams)

      StrongParameters::Core::ApplicationParams.descendants.each do |params_class|
        # Extract model name from class name (e.g., UserParams -> User)
        next unless params_class.name =~ /(.+)Params$/

        model_name = ::Regexp.last_match(1)
        StrongParameters::Core::ParamsRegistry.register(model_name, params_class)
      end
    end
  end
end
