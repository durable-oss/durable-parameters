require "test_helper"

class BooksController < ActionController::Base
  def create
    params.require(:book).require(:name)
    head :ok
  rescue ActionController::ParameterMissing => e
    render plain: e.message, status: :bad_request
  end
end

class ActionControllerRequiredParamsTest < ActionController::TestCase
  tests BooksController

  setup do
    @routes = Rails.application.routes
  end

  def test_missing_required_parameters_will_raise_exception
    post :create, params: {magazine: {name: "Mjallo!"}}
    assert_response :bad_request

    post :create, params: {book: {title: "Mjallo!"}}
    assert_response :bad_request
  end

  def test_required_parameters_that_are_present_will_not_raise
    post :create, params: {book: {name: "Mjallo!"}}
    assert_response :ok
  end

  def test_missing_parameters_will_be_mentioned_in_the_response
    post :create, params: {magazine: {name: "Mjallo!"}}
    assert_includes response.body, "book"
  end
end
