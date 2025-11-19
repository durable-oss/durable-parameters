require 'test_helper'
require 'thread'

class ParamsRegistryConcurrencyTest < Minitest::Test
  def setup
    ActionController::ParamsRegistry.clear!
  end

  def teardown
    ActionController::ParamsRegistry.clear!
  end

  # Test concurrent registrations
  def test_concurrent_registrations
    threads = []
    params_classes = {}

    # Create multiple params classes
    10.times do |i|
      params_classes["Model#{i}"] = Class.new(ActionController::ApplicationParams) do
        define_singleton_method(:name) { "Model#{i}Params" }
        allow :field
      end
    end

    # Register them concurrently
    10.times do |i|
      threads << Thread.new do
        ActionController::ParamsRegistry.register("Model#{i}", params_classes["Model#{i}"])
      end
    end

    threads.each(&:join)

    # Verify all were registered
    10.times do |i|
      assert ActionController::ParamsRegistry.registered?("Model#{i}")
      assert_equal params_classes["Model#{i}"], ActionController::ParamsRegistry.lookup("Model#{i}")
    end
  end

  # Test concurrent lookups
  def test_concurrent_lookups
    params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'TestParams'
      end
      allow :field
    end

    ActionController::ParamsRegistry.register('Test', params_class)

    threads = []
    results = []
    mutex = Mutex.new

    # Perform concurrent lookups
    20.times do
      threads << Thread.new do
        result = ActionController::ParamsRegistry.lookup('Test')
        mutex.synchronize do
          results << result
        end
      end
    end

    threads.each(&:join)

    # All should have found the same class
    assert_equal 20, results.length
    results.each do |result|
      assert_equal params_class, result
    end
  end

  # Test concurrent registered? checks
  def test_concurrent_registered_checks
    params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'TestParams'
      end
      allow :field
    end

    ActionController::ParamsRegistry.register('Test', params_class)

    threads = []
    results = []
    mutex = Mutex.new

    # Perform concurrent checks
    20.times do
      threads << Thread.new do
        result = ActionController::ParamsRegistry.registered?('Test')
        mutex.synchronize do
          results << result
        end
      end
    end

    threads.each(&:join)

    # All should return true
    assert_equal 20, results.length
    assert results.all? { |r| r == true }
  end

  # Test concurrent permitted_attributes_for
  def test_concurrent_permitted_attributes_for
    params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'TestParams'
      end
      allow :field1
      allow :field2
      allow :field3
    end

    ActionController::ParamsRegistry.register('Test', params_class)

    threads = []
    results = []
    mutex = Mutex.new

    # Perform concurrent attribute lookups
    20.times do
      threads << Thread.new do
        attrs = ActionController::ParamsRegistry.permitted_attributes_for('Test')
        mutex.synchronize do
          results << attrs
        end
      end
    end

    threads.each(&:join)

    # All should return the same attributes
    assert_equal 20, results.length
    expected = [:field1, :field2, :field3]
    results.each do |result|
      assert_equal expected, result
    end
  end

  # Test concurrent registrations and lookups
  def test_concurrent_registrations_and_lookups
    threads = []
    results = []
    mutex = Mutex.new

    params_classes = {}
    5.times do |i|
      params_classes["Model#{i}"] = Class.new(ActionController::ApplicationParams) do
        define_singleton_method(:name) { "Model#{i}Params" }
        allow "field#{i}".to_sym
      end
    end

    # Mix registrations and lookups
    10.times do |i|
      if i < 5
        # First 5 threads register
        threads << Thread.new do
          ActionController::ParamsRegistry.register("Model#{i}", params_classes["Model#{i}"])
        end
      else
        # Next 5 threads lookup
        threads << Thread.new do
          sleep 0.01  # Small delay to allow some registrations
          idx = i - 5
          result = ActionController::ParamsRegistry.lookup("Model#{idx}")
          mutex.synchronize do
            results << result
          end
        end
      end
    end

    threads.each(&:join)

    # All lookups should eventually succeed
    results.each do |result|
      refute_nil result
    end
  end

  # Test concurrent clear operations
  def test_concurrent_clear_and_register
    threads = []

    params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'TestParams'
      end
      allow :field
    end

    # One thread clears, others try to register
    threads << Thread.new do
      5.times do
        ActionController::ParamsRegistry.clear!
        sleep 0.01
      end
    end

    10.times do |i|
      threads << Thread.new do
        10.times do
          ActionController::ParamsRegistry.register("Model#{i}", params_class)
          sleep 0.005
        end
      end
    end

    threads.each(&:join)

    # At the end, some models might be registered depending on timing
    # This test mainly ensures no crashes occur
    models = ActionController::ParamsRegistry.registered_models
    assert models.is_a?(Array)
  end

  # Test concurrent registered_models calls
  def test_concurrent_registered_models
    5.times do |i|
      params_class = Class.new(ActionController::ApplicationParams) do
        define_singleton_method(:name) { "Model#{i}Params" }
        allow :field
      end
      ActionController::ParamsRegistry.register("Model#{i}", params_class)
    end

    threads = []
    results = []
    mutex = Mutex.new

    20.times do
      threads << Thread.new do
        models = ActionController::ParamsRegistry.registered_models
        mutex.synchronize do
          results << models.sort
        end
      end
    end

    threads.each(&:join)

    # All should return the same models
    expected = (0..4).map { |i| "model#{i}" }.sort
    results.each do |result|
      assert_equal expected, result
    end
  end

  # Test registry isolation between threads
  def test_registry_shared_state
    params_class1 = Class.new(ActionController::ApplicationParams) do
      def self.name
        'Params1'
      end
      allow :field1
    end

    params_class2 = Class.new(ActionController::ApplicationParams) do
      def self.name
        'Params2'
      end
      allow :field2
    end

    thread1_result = nil
    thread2_result = nil

    thread1 = Thread.new do
      ActionController::ParamsRegistry.register('Test1', params_class1)
      sleep 0.02
      thread1_result = ActionController::ParamsRegistry.lookup('Test2')
    end

    thread2 = Thread.new do
      sleep 0.01
      ActionController::ParamsRegistry.register('Test2', params_class2)
      thread2_result = ActionController::ParamsRegistry.lookup('Test1')
    end

    thread1.join
    thread2.join

    # Both threads should see each other's registrations (shared state)
    assert_equal params_class2, thread1_result
    assert_equal params_class1, thread2_result
  end

  # Test many concurrent operations
  def test_high_concurrency_mixed_operations
    threads = []
    errors = []
    mutex = Mutex.new

    # Pre-register some classes
    5.times do |i|
      params_class = Class.new(ActionController::ApplicationParams) do
        define_singleton_method(:name) { "Model#{i}Params" }
        allow :field
      end
      ActionController::ParamsRegistry.register("Model#{i}", params_class)
    end

    # Perform many mixed operations
    50.times do |i|
      threads << Thread.new do
        begin
          case i % 4
          when 0
            # Lookup
            ActionController::ParamsRegistry.lookup("Model#{i % 5}")
          when 1
            # Check registered
            ActionController::ParamsRegistry.registered?("Model#{i % 5}")
          when 2
            # Get permitted attributes
            ActionController::ParamsRegistry.permitted_attributes_for("Model#{i % 5}")
          when 3
            # Get registered models
            ActionController::ParamsRegistry.registered_models
          end
        rescue => e
          mutex.synchronize do
            errors << e
          end
        end
      end
    end

    threads.each(&:join)

    # Should complete without errors
    assert_equal [], errors, "Errors occurred: #{errors.map(&:message).join(', ')}"
  end

  # Test transform_params under concurrent access
  def test_concurrent_transform_params
    params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'UserParams'
      end
      allow :name
      allow :email
    end

    ActionController::ParamsRegistry.register('User', params_class)

    threads = []
    results = []
    mutex = Mutex.new

    20.times do |i|
      threads << Thread.new do
        params = ActionController::Parameters.new(
          user: {
            name: "User#{i}",
            email: "user#{i}@example.com"
          }
        )

        permitted = params.require(:user).transform_params()
        mutex.synchronize do
          results << permitted.to_h
        end
      end
    end

    threads.each(&:join)

    # All should have correct data
    assert_equal 20, results.length
    20.times do |i|
      matching = results.find { |r| r['name'] == "User#{i}" }
      refute_nil matching, "Missing result for User#{i}"
      assert_equal "user#{i}@example.com", matching['email']
    end
  end

  # Test ApplicationParams class isolation
  def test_params_class_modifications_thread_safe
    base_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        'BaseParams'
      end
      allow :id
    end

    ActionController::ParamsRegistry.register('Base', base_class)

    threads = []
    results = []
    mutex = Mutex.new

    # Multiple threads accessing the class attributes
    20.times do
      threads << Thread.new do
        # Read operations
        attrs = base_class.allowed_attributes.dup
        denied = base_class.denied_attributes.dup
        flags = base_class.flags.dup

        mutex.synchronize do
          results << { attrs: attrs, denied: denied, flags: flags }
        end
      end
    end

    threads.each(&:join)

    # All should see the same state
    results.each do |result|
      assert_equal [:id], result[:attrs]
      assert_equal [], result[:denied]
      assert_equal({}, result[:flags])
    end
  end
end
