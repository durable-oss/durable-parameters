require 'test_helper'

class RaiseOnUnpermittedParamsTest < Minitest::Test
  def setup
    ActionController::Parameters.action_on_unpermitted_parameters = :raise
  end

  def teardown
    ActionController::Parameters.action_on_unpermitted_parameters = false
  end

  def test_raises_on_unexpected_params
    params = ActionController::Parameters.new({
      :book => { :pages => 65 },
      :fishing => "Turnips"
    })

    assert_raises(ActionController::UnpermittedParameters) do
      params.permit(:book => [:pages])
    end
  end

  def test_raises_on_unexpected_nested_params
    params = ActionController::Parameters.new({
      :book => { :pages => 65, :title => "Green Cats and where to find then." }
    })

    assert_raises(ActionController::UnpermittedParameters) do
      params.permit(:book => [:pages])
    end
  end
end