require "test_helper"

class ParametersCoreMethods < Minitest::Test
  def setup
    @params = ActionController::Parameters.new(
      name: "John",
      email: "john@example.com",
      age: 30,
      admin: true,
      profile: {
        bio: "Developer",
        location: "NYC"
      },
      tags: ["ruby", "rails"]
    )
  end

  # Test initialization
  def test_initialization_with_nil
    assert_raises(NoMethodError) { ActionController::Parameters.new(nil) }
  end

  def test_initialization_with_empty_hash
    params = ActionController::Parameters.new({})
    assert_equal({}, params.permit!.to_h)
    assert params.permitted?
  end

  def test_initialization_with_hash
    params = ActionController::Parameters.new(key: "value")
    assert_equal "value", params[:key]
    assert !params.permitted?
  end

  # Test permitted flag
  def test_permitted_starts_false
    assert !@params.permitted?
  end

  def test_permit_bang_sets_permitted_true
    @params.permit!
    assert @params.permitted?
  end

  def test_permit_bang_returns_self
    result = @params.permit!
    assert_equal @params.object_id, result.object_id
  end

  # Test require method
  def test_require_returns_value_when_present
    params = ActionController::Parameters.new(user: {name: "John"})
    result = params.require(:user)
    assert_equal "John", result[:name]
  end

  def test_require_raises_when_key_missing
    assert_raises(ActionController::ParameterMissing) do
      @params.require(:nonexistent)
    end
  end

  def test_require_raises_when_value_empty
    params = ActionController::Parameters.new(user: nil)
    assert_raises(ActionController::ParameterMissing) do
      params.require(:user)
    end
  end

  def test_require_raises_when_value_empty_string
    params = ActionController::Parameters.new(user: "")
    assert_raises(ActionController::ParameterMissing) do
      params.require(:user)
    end
  end

  def test_require_raises_when_value_empty_array
    params = ActionController::Parameters.new(user: [])
    assert_raises(ActionController::ParameterMissing) do
      params.require(:user)
    end
  end

  def test_require_raises_when_value_empty_hash
    params = ActionController::Parameters.new(user: {})
    assert_raises(ActionController::ParameterMissing) do
      params.require(:user)
    end
  end

  def test_require_accepts_string_key
    params = ActionController::Parameters.new(user: {name: "John"})
    result = params.require("user")
    assert_equal "John", result[:name]
  end

  def test_require_sets_required_key_on_result
    params = ActionController::Parameters.new(user: {name: "John"})
    result = params.require(:user)
    assert_equal :user, result.required_key
  end

  def test_required_alias_works
    params = ActionController::Parameters.new(user: {name: "John"})
    result = params.required(:user)
    assert_equal "John", result[:name]
  end

  # Test permit method
  def test_permit_with_single_key
    permitted = @params.permit(:name)
    assert_equal "John", permitted[:name]
    assert_nil permitted[:email]
    assert permitted.permitted?
  end

  def test_permit_with_multiple_keys
    permitted = @params.permit(:name, :email, :age)
    assert_equal "John", permitted[:name]
    assert_equal "john@example.com", permitted[:email]
    assert_equal 30, permitted[:age]
    assert_nil permitted[:admin]
    assert permitted.permitted?
  end

  def test_permit_with_string_keys
    permitted = @params.permit("name", "email")
    assert_equal "John", permitted[:name]
    assert_equal "john@example.com", permitted[:email]
    assert permitted.permitted?
  end

  def test_permit_returns_new_instance
    permitted = @params.permit(:name)
    refute_equal @params.object_id, permitted.object_id
  end

  def test_permit_doesnt_modify_original
    permitted = @params.permit(:name)
    assert !@params.permitted?
    assert permitted.permitted?
  end

  # Test [] accessor
  def test_bracket_accessor_with_symbol
    assert_equal "John", @params[:name]
  end

  def test_bracket_accessor_with_string
    assert_equal "John", @params["name"]
  end

  def test_bracket_accessor_returns_nil_for_missing_key
    assert_nil @params[:nonexistent]
  end

  def test_bracket_accessor_converts_hash_to_parameters
    profile = @params[:profile]
    assert profile.is_a?(ActionController::Parameters)
    assert_equal "Developer", profile[:bio]
  end

  # Test fetch method
  def test_fetch_returns_value_when_present
    assert_equal "John", @params.fetch(:name)
  end

  def test_fetch_raises_when_key_missing
    assert_raises(ActionController::ParameterMissing) do
      @params.fetch(:nonexistent)
    end
  end

  def test_fetch_with_default_value
    result = @params.fetch(:nonexistent, "default")
    assert_equal "default", result
  end

  def test_fetch_with_block
    result = @params.fetch(:nonexistent) { "from block" }
    assert_equal "from block", result
  end

  def test_fetch_converts_hash_to_parameters
    profile = @params.fetch(:profile)
    assert profile.is_a?(ActionController::Parameters)
  end

  # Test slice method
  def test_slice_returns_subset
    sliced = @params.slice(:name, :email)
    assert_equal "John", sliced[:name]
    assert_equal "john@example.com", sliced[:email]
    assert_nil sliced[:age]
  end

  def test_slice_preserves_permitted_flag
    @params.permit!
    sliced = @params.slice(:name)
    assert sliced.permitted?
  end

  def test_slice_preserves_required_key
    params = ActionController::Parameters.new(user: {name: "John", email: "john@example.com"})
    user_params = params.require(:user)
    sliced = user_params.slice(:name)
    assert_equal :user, sliced.required_key
  end

  def test_slice_returns_new_instance
    sliced = @params.slice(:name)
    refute_equal @params.object_id, sliced.object_id
  end

  # Test dup method
  def test_dup_creates_new_instance
    duped = @params.dup
    refute_equal @params.object_id, duped.object_id
  end

  def test_dup_preserves_data
    duped = @params.dup
    assert_equal "John", duped[:name]
    assert_equal "john@example.com", duped[:email]
    assert_equal 30, duped[:age]
  end

  def test_dup_preserves_permitted_flag
    @params.permit!
    duped = @params.dup
    assert duped.permitted?
  end

  def test_dup_preserves_required_key
    params = ActionController::Parameters.new(user: {name: "John"})
    user_params = params.require(:user)
    duped = user_params.dup
    assert_equal :user, duped.required_key
  end

  def test_dup_creates_shallow_copy
    duped = @params.dup
    duped[:new_key] = "new_value"
    assert_nil @params[:new_key]
  end

  # Test hash conversion
  def test_to_h_returns_hash
    hash = @params.permit(:name).to_h
    assert hash.is_a?(Hash)
  end

  def test_to_h_with_permitted_params
    permitted = @params.permit(:name, :email)
    hash = permitted.to_h
    assert_equal "John", hash["name"]
    assert_equal "john@example.com", hash["email"]
  end

  # Test key checking
  def test_has_key_with_symbol
    assert @params.has_key?(:name)
  end

  def test_has_key_with_string
    assert @params.has_key?("name")
  end

  def test_has_key_returns_false_for_missing
    assert !@params.has_key?(:nonexistent)
  end

  def test_key_alias_works
    assert @params.key?(:name)
  end

  # Test keys method
  def test_keys_returns_all_keys
    keys = @params.keys
    assert_includes keys, "name"
    assert_includes keys, "email"
    assert_includes keys, "age"
  end

  # Test values method
  def test_values_returns_all_values
    values = @params.values
    assert_includes values, "John"
    assert_includes values, "john@example.com"
    assert_includes values, 30
  end

  # Test each methods
  def test_each_iterates_over_pairs
    result = {}
    @params.each { |k, v| result[k] = v }
    assert_equal "John", result["name"]
    assert_equal "john@example.com", result["email"]
  end

  def test_each_pair_iterates_over_pairs
    result = {}
    @params.each_pair { |k, v| result[k] = v }
    assert_equal "John", result["name"]
  end

  # Test merge
  def test_merge_combines_params
    other = ActionController::Parameters.new(country: "USA")
    merged = @params.permit(:name).merge(other.permit(:country))
    assert_equal "John", merged[:name]
    assert_equal "USA", merged[:country]
  end

  def test_merge_doesnt_modify_original
    other = ActionController::Parameters.new(country: "USA")
    merged = @params.permit(:name).merge(other.permit(:country))
    assert_nil @params[:country]
    assert_equal "USA", merged[:country]
  end

  # Test empty checks
  def test_empty_returns_true_for_empty_params
    params = ActionController::Parameters.new({})
    assert params.empty?
  end

  def test_empty_returns_false_for_non_empty_params
    assert !@params.empty?
  end

  # Test nested parameter conversion
  def test_nested_hash_converted_to_parameters
    profile = @params[:profile]
    assert profile.is_a?(ActionController::Parameters)
    assert !profile.permitted?
  end

  def test_array_elements_not_converted
    tags = @params[:tags]
    assert tags.is_a?(Array)
    assert_equal "ruby", tags[0]
  end

  def test_deeply_nested_hashes_converted
    params = ActionController::Parameters.new(
      level1: {
        level2: {
          level3: {
            value: "deep"
          }
        }
      }
    )

    level1 = params[:level1]
    level2 = level1[:level2]
    level3 = level2[:level3]

    assert level1.is_a?(ActionController::Parameters)
    assert level2.is_a?(ActionController::Parameters)
    assert level3.is_a?(ActionController::Parameters)
    assert_equal "deep", level3[:value]
  end

  # Test with indifferent access
  def test_indifferent_access_symbol_and_string
    params = ActionController::Parameters.new(key: "value")
    assert_equal "value", params[:key]
    assert_equal "value", params["key"]
  end

  # Test delete
  def test_delete_removes_key
    @params.delete(:name)
    assert_nil @params[:name]
  end

  def test_delete_returns_value
    result = @params.delete(:name)
    assert_equal "John", result
  end

  # Test select
  def test_select_filters_params
    selected = @params.select { |k, v| v.is_a?(String) }
    assert_includes selected, "name"
    assert_includes selected, "email"
  end

  # Test reject
  def test_reject_filters_params
    rejected = @params.reject { |k, v| v.is_a?(String) }
    assert_includes rejected, "age"
    assert_includes rejected, "admin"
  end

  # Test compact (if available)
  def test_compact_removes_nil_values
    params = ActionController::Parameters.new(
      name: "John",
      email: nil,
      age: 30
    )

    if params.respond_to?(:compact)
      compacted = params.compact
      assert_equal "John", compacted[:name]
      assert_equal 30, compacted[:age]
      assert !compacted.has_key?(:email)
    end
  end

  # Test transform_keys
  def test_transform_keys_if_available
    if @params.respond_to?(:transform_keys)
      transformed = @params.transform_keys { |key| key.to_s.upcase }
      assert_equal "John", transformed["NAME"]
    end
  end

  # Test except
  def test_except_excludes_keys
    if @params.respond_to?(:except)
      excepted = @params.except(:name, :email)
      assert_nil excepted[:name]
      assert_nil excepted[:email]
      assert_equal 30, excepted[:age]
    end
  end

  # Test with special parameter types
  def test_with_file_upload
    file = StringIO.new("file content")
    params = ActionController::Parameters.new(
      name: "John",
      avatar: file
    )

    permitted = params.permit(:name, :avatar)
    assert_equal "John", permitted[:name]
    assert_equal file, permitted[:avatar]
  end

  def test_with_date_time
    now = Time.now
    today = Date.today

    params = ActionController::Parameters.new(
      name: "John",
      created_at: now,
      birth_date: today
    )

    permitted = params.permit(:name, :created_at, :birth_date)
    assert_equal "John", permitted[:name]
    assert_equal now, permitted[:created_at]
    assert_equal today, permitted[:birth_date]
  end

  # Test parameter missing exception
  def test_parameter_missing_exception_includes_param_name
    @params.require(:nonexistent)
    flunk "Should have raised ParameterMissing"
  rescue ActionController::ParameterMissing => e
    assert_equal :nonexistent, e.param
    assert_includes e.message, "nonexistent"
  end

  # Test unpermitted parameters exception
  def test_unpermitted_parameters_exception_includes_params
    params = ["field1", "field2"]
    exception = ActionController::UnpermittedParameters.new(params)
    assert_equal params, exception.params
    assert_includes exception.message, "field1"
    assert_includes exception.message, "field2"
  end

  # Test convert_value method behavior
  def test_nested_array_of_hashes_converted
    params = ActionController::Parameters.new(
      items: [
        {name: "Item 1"},
        {name: "Item 2"}
      ]
    )

    items = params[:items]
    assert items.is_a?(Array)
    assert items[0].is_a?(ActionController::Parameters)
    assert items[1].is_a?(ActionController::Parameters)
    assert_equal "Item 1", items[0][:name]
    assert_equal "Item 2", items[1][:name]
  end

  # Test required_key initialization
  def test_required_key_initially_nil
    params = ActionController::Parameters.new(user: {name: "John"})
    assert_nil params.required_key
  end
end
