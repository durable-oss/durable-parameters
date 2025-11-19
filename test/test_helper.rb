# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

# Ruby 3.3 compatibility: File.exists? is deprecated, add alias for older Rails
unless File.respond_to?(:exists?)
  class << File
    alias_method :exists?, :exist?
  end
end

require 'minitest/autorun'
require 'rails'

class FakeApplication < Rails::Application; end

Rails.application = FakeApplication
Rails.configuration.action_controller = ActiveSupport::OrderedOptions.new

# Define routes for controller tests
Rails.application.routes.draw do
  post 'people/create' => 'people#create'
  post 'people/create_with_permit' => 'people#create_with_permit'
  post 'books/create' => 'books#create'
end

require 'durable_parameters'

# Manually setup Rails adapter since we're not going through full Rails initialization
StrongParameters::Adapters::Rails.setup!

# Note: ActionController::Base and related test infrastructure is loaded
# only when needed by controller-specific tests to avoid dependency issues.
# See controller_test_helper.rb for controller test setup.

ActionController::Parameters.action_on_unpermitted_parameters = false

# Load support files
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }
