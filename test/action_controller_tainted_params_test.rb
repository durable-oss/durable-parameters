require "test_helper"

class PeopleController < ActionController::Base
  def create
    render plain: params[:person].permitted? ? "untainted" : "tainted"
  end

  def create_with_permit
    render plain: params[:person].permit(:name).permitted? ? "untainted" : "tainted"
  end
end

class ActionControllerTaintedParamsTest < ActionController::TestCase
  tests PeopleController

  setup do
    @routes = Rails.application.routes
  end

  def test_parameters_are_tainted
    post :create, params: {person: {name: "Mjallo!"}}
    assert_equal "tainted", response.body
  end

  def test_parameters_can_be_permitted_and_are_then_not_tainted
    post :create_with_permit, params: {person: {name: "Mjallo!"}}
    assert_equal "untainted", response.body
  end
end
