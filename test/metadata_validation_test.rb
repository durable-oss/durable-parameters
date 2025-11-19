require "test_helper"

class MetadataValidationTest < Minitest::Test
  def setup
    ActionController::ParamsRegistry.clear!

    @basic_params_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "BasicParams"
      end

      allow :name
      allow :email
    end

    @params_with_metadata = Class.new(ActionController::ApplicationParams) do
      def self.name
        "ParamsWithMetadata"
      end

      allow :name
      allow :email
      metadata :ip_address, :user_agent, :session_id
    end

    ActionController::ParamsRegistry.register("Basic", @basic_params_class)
    ActionController::ParamsRegistry.register("WithMetadata", @params_with_metadata)
  end

  def teardown
    ActionController::ParamsRegistry.clear!
  end

  # Test current_user is always allowed without declaration
  def test_current_user_always_allowed_without_declaration
    params = ActionController::Parameters.new(
      basic: {
        name: "Test User",
        email: "test@example.com"
      }
    )

    # Should not raise even though current_user not declared
    permitted = params.require(:basic).transform_params(current_user: Object.new)

    assert_equal "Test User", permitted[:name]
    assert_equal "test@example.com", permitted[:email]
  end

  # Test metadata_allowed? method
  def test_metadata_allowed_returns_true_for_current_user
    assert @basic_params_class.metadata_allowed?(:current_user)
    assert @basic_params_class.metadata_allowed?("current_user")
  end

  def test_metadata_allowed_returns_false_for_undeclared_keys
    assert !@basic_params_class.metadata_allowed?(:ip_address)
    assert !@basic_params_class.metadata_allowed?(:random_key)
  end

  def test_metadata_allowed_returns_true_for_declared_keys
    assert @params_with_metadata.metadata_allowed?(:ip_address)
    assert @params_with_metadata.metadata_allowed?("user_agent")
    assert @params_with_metadata.metadata_allowed?(:session_id)
  end

  # Test multiple metadata keys
  def test_multiple_metadata_keys_can_be_passed
    params = ActionController::Parameters.new(
      with_metadata: {
        name: "Test User",
        email: "test@example.com"
      }
    )

    # Should not raise with all declared metadata
    permitted = params.require(:with_metadata).transform_params(
      current_user: Object.new,
      ip_address: "192.168.1.1",
      user_agent: "Mozilla/5.0",
      session_id: "abc123"
    )

    assert_equal "Test User", permitted[:name]
    assert_equal "test@example.com", permitted[:email]
  end

  # Test error messages
  def test_error_message_includes_undeclared_key
    params = ActionController::Parameters.new(
      basic: {name: "Test"}
    )

    error = assert_raises(ArgumentError) do
      params.require(:basic).transform_params(ip_address: "127.0.0.1")
    end

    assert_includes error.message, "ip_address"
  end

  def test_error_message_includes_params_class_name
    params = ActionController::Parameters.new(
      basic: {name: "Test"}
    )

    error = assert_raises(ArgumentError) do
      params.require(:basic).transform_params(ip_address: "127.0.0.1")
    end

    assert_includes error.message, "BasicParams"
  end

  def test_error_message_includes_declaration_hint
    params = ActionController::Parameters.new(
      basic: {name: "Test"}
    )

    error = assert_raises(ArgumentError) do
      params.require(:basic).transform_params(ip_address: "127.0.0.1")
    end

    assert_includes error.message, "metadata :ip_address"
  end

  def test_error_message_mentions_current_user_is_always_allowed
    params = ActionController::Parameters.new(
      basic: {name: "Test"}
    )

    error = assert_raises(ArgumentError) do
      params.require(:basic).transform_params(ip_address: "127.0.0.1")
    end

    assert_includes error.message, "current_user is always allowed"
  end

  # Test multiple undeclared keys
  def test_multiple_undeclared_keys_all_mentioned_in_error
    params = ActionController::Parameters.new(
      basic: {name: "Test"}
    )

    error = assert_raises(ArgumentError) do
      params.require(:basic).transform_params(
        ip_address: "127.0.0.1",
        user_agent: "Mozilla",
        device_id: "xyz"
      )
    end

    assert_includes error.message, "ip_address"
    assert_includes error.message, "user_agent"
    assert_includes error.message, "device_id"
  end

  # Test metadata doesn't affect the actual parameter filtering
  def test_metadata_keys_dont_affect_parameter_filtering
    params = ActionController::Parameters.new(
      with_metadata: {
        name: "Test User",
        email: "test@example.com",
        ip_address: "should not be in result",
        user_agent: "should not be in result"
      }
    )

    permitted = params.require(:with_metadata).transform_params(
      current_user: Object.new,
      ip_address: "192.168.1.1",
      user_agent: "Mozilla/5.0"
    )

    assert_equal "Test User", permitted[:name]
    assert_equal "test@example.com", permitted[:email]
    # These should not be in the permitted params because they're metadata, not allowed attributes
    assert_nil permitted[:ip_address]
    assert_nil permitted[:user_agent]
  end

  # Test inheritance of metadata declarations
  def test_metadata_inherited_from_parent
    parent_class = Class.new(ActionController::ApplicationParams) do
      def self.name
        "ParentParams"
      end

      allow :name
      metadata :ip_address
    end

    child_class = Class.new(parent_class) do
      def self.name
        "ChildParams"
      end

      allow :email
      metadata :session_id
    end

    # Child should have parent's metadata
    assert child_class.metadata_allowed?(:ip_address)
    # Child should have its own metadata
    assert child_class.metadata_allowed?(:session_id)
    # Both should allow current_user
    assert child_class.metadata_allowed?(:current_user)
  end

  # Test empty metadata
  def test_empty_metadata_set_by_default
    assert_equal Set.new, @basic_params_class.allowed_metadata
  end

  # Test metadata method accepts multiple keys at once
  def test_metadata_method_accepts_multiple_keys
    test_class = Class.new(ActionController::ApplicationParams) do
      metadata :key1, :key2, :key3
    end

    assert test_class.metadata_allowed?(:key1)
    assert test_class.metadata_allowed?(:key2)
    assert test_class.metadata_allowed?(:key3)
  end

  # Test metadata with string keys
  def test_metadata_works_with_string_keys
    test_class = Class.new(ActionController::ApplicationParams) do
      metadata "string_key"
    end

    assert test_class.metadata_allowed?(:string_key)
    assert test_class.metadata_allowed?("string_key")
  end

  # Test that action and additional_attrs are not treated as metadata
  def test_action_option_not_treated_as_metadata
    params = ActionController::Parameters.new(
      basic: {name: "Test"}
    )

    # Should not raise even though action not declared as metadata
    permitted = params.require(:basic).transform_params(action: :create)
    assert_equal "Test", permitted[:name]
  end

  def test_additional_attrs_option_not_treated_as_metadata
    params = ActionController::Parameters.new(
      basic: {name: "Test"}
    )

    # Should not raise even though additional_attrs not declared as metadata
    permitted = params.require(:basic).transform_params(additional_attrs: [:other])
    assert_equal "Test", permitted[:name]
  end

  def test_action_and_additional_attrs_with_current_user_all_work
    params = ActionController::Parameters.new(
      basic: {name: "Test"}
    )

    # Should not raise with all non-metadata options
    permitted = params.require(:basic).transform_params(
      action: :create,
      additional_attrs: [:other],
      current_user: Object.new
    )
    assert_equal "Test", permitted[:name]
  end

  # Test nil and empty values
  def test_nil_metadata_values_allowed
    params = ActionController::Parameters.new(
      with_metadata: {name: "Test"}
    )

    # Should not raise with nil metadata value
    permitted = params.require(:with_metadata).transform_params(
      current_user: nil,
      ip_address: nil
    )
    assert_equal "Test", permitted[:name]
  end

  def test_empty_string_metadata_values_allowed
    params = ActionController::Parameters.new(
      with_metadata: {name: "Test"}
    )

    # Should not raise with empty string metadata value
    permitted = params.require(:with_metadata).transform_params(
      ip_address: ""
    )
    assert_equal "Test", permitted[:name]
  end
end
