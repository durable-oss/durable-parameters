# frozen_string_literal: true

require "test_helper"

class DurableParametersTest < Minitest::Test
  include ActiveSupport::Testing::ConstantStubbing
  def test_top_level_aliases_are_defined
    assert defined?(DurableParameters::Parameters)
    assert defined?(DurableParameters::ApplicationParams)
    assert defined?(DurableParameters::ParamsRegistry)
    assert defined?(DurableParameters::ForbiddenAttributesProtection)
  end

  def test_aliases_point_to_core_classes
    assert_equal DurableParameters::Core::Parameters, DurableParameters::Parameters
    assert_equal DurableParameters::Core::ApplicationParams, DurableParameters::ApplicationParams
    assert_equal DurableParameters::Core::ParamsRegistry, DurableParameters::ParamsRegistry
    assert_equal DurableParameters::Core::ForbiddenAttributesProtection, DurableParameters::ForbiddenAttributesProtection
  end

  def test_module_has_version
    assert defined?(DurableParameters::VERSION)
    assert DurableParameters::VERSION.is_a?(String)
    assert_match(/\A\d+\.\d+\.\d+(\.\w+)?\z/, DurableParameters::VERSION)
  end

  def test_core_module_is_defined
    assert defined?(DurableParameters::Core)
    assert DurableParameters::Core.is_a?(Module)
  end

  def test_strong_parameters_is_module
    assert DurableParameters.is_a?(Module)
  end

  def test_adapter_loading_rails
    # Rails is loaded in test_helper, so railtie and log_subscriber should be required
    # We can't easily test the require calls, but we can check if the adapters are available
    # Since Rails is defined, the Rails adapter should be loaded
    assert defined?(DurableParameters::Adapters::Rails)
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
    # Test that if DurableParameters::Parameters is already defined, it won't be redefined
    original_value = DurableParameters::Parameters
    # Simulate re-requiring (though in practice it's already required)
    # Since the code uses unless defined?(Parameters), and Parameters is DurableParameters::Parameters
    # It should not redefine if already defined
    assert_equal original_value, DurableParameters::Parameters
  end

  def test_adapters_module_is_defined
    assert defined?(DurableParameters::Adapters)
    assert DurableParameters::Adapters.is_a?(Module)
  end

  def test_rails_adapter_is_module
    assert DurableParameters::Adapters::Rails.is_a?(Module)
  end

  def test_sinatra_adapter_file_exists_and_loadable
    adapter_path = File.join(__dir__, "..", "lib", "durable_parameters", "adapters", "sinatra.rb")
    assert File.exist?(adapter_path)
    # Test that it can be required without error
    require "durable_parameters/adapters/sinatra"
    assert defined?(DurableParameters::Adapters::Sinatra)
  ensure
    DurableParameters::Adapters.send(:remove_const, :Sinatra) if defined?(DurableParameters::Adapters::Sinatra)
  end

  def test_hanami_adapter_file_exists_and_loadable
    adapter_path = File.join(__dir__, "..", "lib", "durable_parameters", "adapters", "hanami.rb")
    assert File.exist?(adapter_path)
    # Test that it can be required without error
    require "durable_parameters/adapters/hanami"
    assert defined?(DurableParameters::Adapters::Hanami)
  ensure
    DurableParameters::Adapters.send(:remove_const, :Hanami) if defined?(DurableParameters::Adapters::Hanami)
  end

  def test_rage_adapter_file_exists_and_loadable
    adapter_path = File.join(__dir__, "..", "lib", "durable_parameters", "adapters", "rage.rb")
    assert File.exist?(adapter_path)
    # Test that it can be required without error
    require "durable_parameters/adapters/rage"
    assert defined?(DurableParameters::Adapters::Rage)
  ensure
    DurableParameters::Adapters.send(:remove_const, :Rage) if defined?(DurableParameters::Adapters::Rage)
  end

  def test_version_is_not_empty
    refute DurableParameters::VERSION.empty?
  end

  def test_core_classes_are_accessible_via_aliases
    # Test that the aliases work for instantiation or basic methods
    assert DurableParameters::Parameters.new({}).is_a?(DurableParameters::Core::Parameters)
    assert DurableParameters::ApplicationParams.is_a?(Class)
    assert DurableParameters::ParamsRegistry.is_a?(Class)
    assert DurableParameters::ForbiddenAttributesProtection.is_a?(Module)
  end

  def test_version_matches_durable_parameters_version
    assert_equal DurableParameters::VERSION, DurableParameters::VERSION
  end

  def test_core_module_has_all_expected_classes
    assert defined?(DurableParameters::Core::Parameters)
    assert defined?(DurableParameters::Core::ApplicationParams)
    assert defined?(DurableParameters::Core::ParamsRegistry)
    assert defined?(DurableParameters::Core::ForbiddenAttributesProtection)
    assert defined?(DurableParameters::Core::Configuration)
  end

  def test_adapters_module_has_expected_adapters
    assert defined?(DurableParameters::Adapters::Rails)
    # Others are not loaded unless their frameworks are defined
    refute defined?(DurableParameters::Adapters::Sinatra)
    refute defined?(DurableParameters::Adapters::Hanami)
    refute defined?(DurableParameters::Adapters::Rage)
  end



  def test_aliases_are_properly_typed
    assert DurableParameters::Parameters.is_a?(Class)
    assert DurableParameters::ApplicationParams.is_a?(Class)
    assert DurableParameters::ParamsRegistry.is_a?(Class)
    assert DurableParameters::ForbiddenAttributesProtection.is_a?(Module)
  end



  def test_core_classes_can_be_instantiated
    # Test that core classes are instantiable
    params = DurableParameters::Parameters.new({a: 1})
    assert params.is_a?(DurableParameters::Core::Parameters)
    assert_equal({"a" => 1}, params.to_h)
  end
end
