$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "durable_parameters/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name = "durable_parameters"
  s.version = DurableParameters::VERSION
  s.authors = ["David J Berube"]
  s.email = ["djberube@durableprogramming.com"]
  s.summary = "Framework-agnostic durable parameters with adapters for Rails, Sinatra, Hanami, and Rage"
  s.description = "Durable Parameters provides a whitelist-based approach to mass assignment protection. This gem is framework-agnostic with adapters for Rails, Sinatra, Hanami, and Rage."
  s.homepage = "https://github.com/durableprogramming/durable_parameters"
  s.license = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]

  # No required dependencies - works standalone
  # Framework dependencies are optional
  s.add_development_dependency "rake"
  s.add_development_dependency "minitest"

  # Optional framework dependencies
  # Rails support
  s.add_development_dependency "activesupport", "> 6.0"
  s.add_development_dependency "actionpack", "> 6.0"
  s.add_development_dependency "activemodel", "> 6.0"
  s.add_development_dependency "railties", "> 6.0"

  # Sinatra support
  s.add_development_dependency "sinatra", ">= 1.4"

  # Note: Hanami and Rage are optional and not added as dev dependencies
  # Users can install them separately if needed
end
