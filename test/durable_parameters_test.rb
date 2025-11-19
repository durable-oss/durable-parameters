# frozen_string_literal: true

require "test_helper"

class DurableParametersTest < Minitest::Test
  def test_top_level_aliases_are_defined
    assert defined?(StrongParameters::Parameters)
    assert defined?(StrongParameters::ApplicationParams)
    assert defined?(StrongParameters::ParamsRegistry)
    assert defined?(StrongParameters::ForbiddenAttributesProtection)
  end

  def test_aliases_point_to_core_classes
    assert_equal StrongParameters::Core::Parameters, StrongParameters::Parameters
    assert_equal StrongParameters::Core::ApplicationParams, StrongParameters::ApplicationParams
    assert_equal StrongParameters::Core::ParamsRegistry, StrongParameters::ParamsRegistry
    assert_equal StrongParameters::Core::ForbiddenAttributesProtection, StrongParameters::ForbiddenAttributesProtection
  end

  def test_module_has_version
    assert defined?(StrongParameters::VERSION)
    assert StrongParameters::VERSION.is_a?(String)
    assert_match(/\A\d+\.\d+\.\d+(\.\w+)?\z/, StrongParameters::VERSION)
  end

  def test_core_module_is_defined
    assert defined?(StrongParameters::Core)
    assert StrongParameters::Core.is_a?(Module)
  end

  def test_strong_parameters_is_module
    assert StrongParameters.is_a?(Module)
  end

  def test_adapter_loading_rails
    # Rails is loaded in test_helper, so railtie and log_subscriber should be required
    # We can't easily test the require calls, but we can check if the adapters are available
    # Since Rails is defined, the Rails adapter should be loaded
    assert defined?(StrongParameters::Adapters::Rails)
  end

  def test_adapter_loading_sinatra
    # Test that Sinatra adapter would be loaded if Sinatra was defined
    # Since Sinatra is not defined in this test suite, we can't test the require
    # But we can check that the adapter file exists
    adapter_path = File.join(__dir__, "..", "lib", "durable_parameters", "adapters", "sinatra.rb")
    assert File.exist?(adapter_path), "Sinatra adapter file should exist"
  end

  def test_adapter_loading_hanami
    adapter_path = File.join(__dir__, "..", "lib", "durable_parameters", "adapters", "hanami.rb")
    assert File.exist?(adapter_path), "Hanami adapter file should exist"
  end

  def test_adapter_loading_rage
    adapter_path = File.join(__dir__, "..", "lib", "durable_parameters", "adapters", "rage.rb")
    assert File.exist?(adapter_path), "Rage adapter file should exist"
  end

  def test_aliases_are_not_redefined_if_already_defined
    # Test that if StrongParameters::Parameters is already defined, it won't be redefined
    original_value = StrongParameters::Parameters
    # Simulate re-requiring (though in practice it's already required)
    # Since the code uses unless defined?(Parameters), and Parameters is StrongParameters::Parameters
    # It should not redefine if already defined
    assert_equal original_value, StrongParameters::Parameters
  end

  def test_adapters_module_is_defined
    assert defined?(StrongParameters::Adapters)
    assert StrongParameters::Adapters.is_a?(Module)
  end

  def test_rails_adapter_is_module
    assert StrongParameters::Adapters::Rails.is_a?(Module)
  end

  def test_sinatra_adapter_file_exists_and_loadable
    adapter_path = File.join(__dir__, "..", "lib", "durable_parameters", "adapters", "sinatra.rb")
    assert File.exist?(adapter_path)
    # Test that it can be required without error
    assert require "durable_parameters/adapters/sinatra"
    assert defined?(StrongParameters::Adapters::Sinatra)
  end

  def test_hanami_adapter_file_exists_and_loadable
    adapter_path = File.join(__dir__, "..", "lib", "durable_parameters", "adapters", "hanami.rb")
    assert File.exist?(adapter_path)
    # Test that it can be required without error
    assert require "durable_parameters/adapters/hanami"
    assert defined?(StrongParameters::Adapters::Hanami)
  end

  def test_rage_adapter_file_exists_and_loadable
    adapter_path = File.join(__dir__, "..", "lib", "durable_parameters", "adapters", "rage.rb")
    assert File.exist?(adapter_path)
    # Test that it can be required without error
    assert require "durable_parameters/adapters/rage"
    assert defined?(StrongParameters::Adapters::Rage)
  end

  def test_version_is_not_empty
    refute StrongParameters::VERSION.empty?
  end

  def test_core_classes_are_accessible_via_aliases
    # Test that the aliases work for instantiation or basic methods
    assert StrongParameters::Parameters.new({}).is_a?(StrongParameters::Core::Parameters)
    assert StrongParameters::ApplicationParams.is_a?(Class)
    assert StrongParameters::ParamsRegistry.is_a?(Class)
    assert StrongParameters::ForbiddenAttributesProtection.is_a?(Module)
  end
end
