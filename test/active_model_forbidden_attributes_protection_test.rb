require "test_helper"
require "legacy/active_model/forbidden_attributes_protection"

class MockBase
  def sanitize_for_mass_assignment(*options)
    options.first
  end
end

class TestModel < MockBase
  include ActiveModel::ForbiddenAttributesProtection

  public :sanitize_for_mass_assignment
end

class ActiveModelForbiddenAttributesProtectionTest < Minitest::Test
  def test_forbidden_attributes_cannot_be_used_for_mass_updating
    assert_raises(ActiveModel::ForbiddenAttributes) do
      TestModel.new.sanitize_for_mass_assignment(ActionController::Parameters.new(a: "b"))
    end
  end

  def test_permitted_attributes_can_be_used_for_mass_updating
    result = TestModel.new.sanitize_for_mass_assignment(ActionController::Parameters.new(a: "b").permit(:a))
    assert_equal({"a" => "b"}, result.to_h)
  end

  def test_regular_attributes_should_still_be_allowed
    result = TestModel.new.sanitize_for_mass_assignment(a: "b")
    assert_equal({a: "b"}, result)
  end

  def test_objects_without_permitted_method_are_allowed
    custom_object = Object.new
    def custom_object.to_hash
      {a: "b"}
    end
    result = TestModel.new.sanitize_for_mass_assignment(custom_object)
    assert_equal custom_object, result
  end

  def test_forbidden_attributes_exception_is_standard_error
    assert ActiveModel::ForbiddenAttributes < StandardError
  end

  def test_nil_attributes_are_allowed
    result = TestModel.new.sanitize_for_mass_assignment(nil)
    assert_nil result
  end

  def test_empty_parameters_raise_exception
    assert_raises(ActiveModel::ForbiddenAttributes) do
      TestModel.new.sanitize_for_mass_assignment(ActionController::Parameters.new)
    end
  end

  def test_permitted_empty_parameters_are_allowed
    result = TestModel.new.sanitize_for_mass_assignment(ActionController::Parameters.new.permit!)
    assert_equal({}, result.to_h)
  end

  def test_nested_unpermitted_parameters_raise_exception
    nested_params = ActionController::Parameters.new(user: {name: "John", password: "secret"})
    assert_raises(ActiveModel::ForbiddenAttributes) do
      TestModel.new.sanitize_for_mass_assignment(nested_params)
    end
  end

  def test_nested_permitted_parameters_are_allowed
    nested_params = ActionController::Parameters.new(user: {name: "John", password: "secret"}).permit(user: [:name])
    result = TestModel.new.sanitize_for_mass_assignment(nested_params)
    expected = {"user" => {"name" => "John"}}
    assert_equal expected, result.to_h
  end

  def test_exception_message_is_class_name
    error = assert_raises(ActiveModel::ForbiddenAttributes) do
      TestModel.new.sanitize_for_mass_assignment(ActionController::Parameters.new(a: "b"))
    end
    assert_equal "ActiveModel::ForbiddenAttributes", error.message
  end
end