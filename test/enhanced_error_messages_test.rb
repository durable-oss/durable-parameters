# frozen_string_literal: true

require "test_helper"

class EnhancedErrorMessagesTest < Minitest::Test
  def setup
    @params = StrongParameters::Core::Parameters.new(
      usr: {name: "John", email: "john@example.com"},
      account: {balance: 100},
      data: {value: "test"}
    )
  end

  def test_parameter_missing_includes_available_keys_in_error_message
    error = assert_raises(StrongParameters::Core::ParameterMissing) do
      @params.require(:missing_key)
    end

    assert_match(/Available keys:/, error.message)
    assert_match(/usr/, error.message)
    assert_match(/account/, error.message)
    assert_match(/data/, error.message)
  end

  def test_parameter_missing_suggests_similar_keys
    error = assert_raises(StrongParameters::Core::ParameterMissing) do
      @params.require(:user)  # Similar to 'usr'
    end

    assert_match(/Did you mean\?/, error.message)
    assert_match(/usr/, error.message)
  end

  def test_parameter_missing_suggests_keys_starting_with_same_letter
    error = assert_raises(StrongParameters::Core::ParameterMissing) do
      @params.require(:accounts)  # Similar to 'account'
    end

    assert_match(/Did you mean\?/, error.message)
    assert_match(/account/, error.message)
  end

  def test_parameter_missing_does_not_suggest_when_no_similar_keys_exist
    error = assert_raises(StrongParameters::Core::ParameterMissing) do
      @params.require(:xyz)
    end

    # Should show available keys but not suggestions
    assert_match(/Available keys:/, error.message)
    refute_match(/Did you mean\?/, error.message)
  end

  def test_parameter_missing_with_empty_params_shows_helpful_message
    empty_params = StrongParameters::Core::Parameters.new({})

    error = assert_raises(StrongParameters::Core::ParameterMissing) do
      empty_params.require(:user)
    end

    assert_match(/param is missing or the value is empty: user/, error.message)
  end

  def test_parameter_missing_with_nested_params
    params = StrongParameters::Core::Parameters.new(
      user: {profile: {name: "John"}}
    )

    user_params = params.require(:user)

    error = assert_raises(StrongParameters::Core::ParameterMissing) do
      user_params.require(:preferences)
    end

    assert_match(/Available keys:/, error.message)
    assert_match(/profile/, error.message)
  end

  def test_parameter_missing_stores_param_attribute
    error = assert_raises(StrongParameters::Core::ParameterMissing) do
      @params.require(:missing)
    end

    assert_equal "missing", error.param
  end

  def test_parameter_missing_when_value_is_empty_hash
    params = StrongParameters::Core::Parameters.new(user: {})

    error = assert_raises(StrongParameters::Core::ParameterMissing) do
      params.require(:user)
    end

    assert_match(/param is missing or the value is empty: user/, error.message)
  end

  def test_parameter_missing_when_value_is_empty_array
    params = StrongParameters::Core::Parameters.new(tags: [])

    error = assert_raises(StrongParameters::Core::ParameterMissing) do
      params.require(:tags)
    end

    assert_match(/param is missing or the value is empty: tags/, error.message)
  end

  def test_parameter_missing_suggestion_with_partial_match
    params = StrongParameters::Core::Parameters.new(
      user_profile: {name: "John"},
      user_settings: {theme: "dark"}
    )

    error = assert_raises(StrongParameters::Core::ParameterMissing) do
      params.require(:user)
    end

    assert_match(/Did you mean\?/, error.message)
    # Should suggest keys containing 'user'
    assert_match(/user_profile|user_settings/, error.message)
  end
end
