require 'test_helper'

class ParametersRequireTest < Minitest::Test
  def test_required_parameters_must_be_present_not_merely_not_nil
    assert_raises(ActionController::ParameterMissing) do
      ActionController::Parameters.new(:person => {}).require(:person)
    end
  end
end
