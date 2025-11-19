require "test_helper"

class Person
  include StrongParameters::Core::ForbiddenAttributesProtection

  public :sanitize_for_mass_assignment
end

class ActiveModelMassUpdateProtectionTest < Minitest::Test
  def test_forbidden_attributes_cannot_be_used_for_mass_updating
    assert_raises(StrongParameters::Core::ForbiddenAttributes) do
      Person.new.sanitize_for_mass_assignment(ActionController::Parameters.new(a: "b"))
    end
  end

  def test_permitted_attributes_can_be_used_for_mass_updating
    result = Person.new.sanitize_for_mass_assignment(ActionController::Parameters.new(a: "b").permit(:a))
    assert_equal({"a" => "b"}, result.to_h)
  end

  def test_regular_attributes_should_still_be_allowed
    result = Person.new.sanitize_for_mass_assignment(a: "b")
    assert_equal({a: "b"}, result)
  end
end
