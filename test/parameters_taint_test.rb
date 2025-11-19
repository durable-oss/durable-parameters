require 'test_helper'

class ParametersTaintTest < Minitest::Test
  def setup
    @params = ActionController::Parameters.new(
      :person => {
        :age => '32',
        :name => {
          :first => 'David',
          :last => 'Heinemeier Hansson'
        },
        :addresses => [{:city => 'Chicago', :state => 'Illinois'}]
      }
    )
  end

  def test_fetch_raises_parameter_missing_exception
    e = assert_raises(ActionController::ParameterMissing) do
      @params.fetch :foo
    end
    assert_equal :foo, e.param
  end

  def test_fetch_doesnt_raise_parameter_missing_exception_if_there_is_a_default
    assert_equal "monkey", @params.fetch(:foo, "monkey")
    assert_equal "monkey", @params.fetch(:foo) { "monkey" }
  end

  def test_not_permitted_is_sticky_on_accessors
    assert !@params.slice(:person).permitted?
    assert !@params[:person][:name].permitted?
    assert !@params[:person].except(:name).permitted?

    @params.each { |key, value| assert(!value.permitted?) if key == "person" }

    assert !@params.fetch(:person).permitted?

    assert !@params.values_at(:person).first.permitted?
  end

  def test_permitted_is_sticky_on_accessors
    @params.permit!
    assert @params.slice(:person).permitted?
    assert @params[:person][:name].permitted?
    assert @params[:person].except(:name).permitted?

    @params.each { |key, value| assert(value.permitted?) if key == "person" }

    assert @params.fetch(:person).permitted?

    assert @params.values_at(:person).first.permitted?
  end

  def test_not_permitted_is_sticky_on_mutators
    assert !@params.delete_if { |k, v| k == "person" }.permitted?
    assert !@params.keep_if { |k, v| k == "person" }.permitted? if @params.respond_to?(:keep_if)
  end

  def test_permitted_is_sticky_on_mutators
    @params.permit!
    assert @params.delete_if { |k, v| k == "person" }.permitted?
    assert @params.keep_if { |k, v| k == "person" }.permitted? if @params.respond_to?(:keep_if)
  end

  def test_not_permitted_is_sticky_beyond_merges
    assert !@params.merge(:a => "b").permitted?
  end

  def test_permitted_is_sticky_beyond_merges
    @params.permit!
    assert @params.merge(:a => "b").permitted?
  end

  def test_modifying_the_parameters
    @params[:person][:hometown] = "Chicago"
    @params[:person][:family] = { :brother => "Jonas" }

    assert_equal "Chicago", @params[:person][:hometown]
    assert_equal "Jonas", @params[:person][:family][:brother]
  end

  def test_permitting_parameters_that_are_not_there_should_not_include_the_keys
    assert !@params.permit(:person, :funky).has_key?(:funky)
  end

  def test_permit_state_is_kept_on_a_dup
    @params.permit!
    assert_equal @params.permitted?, @params.dup.permitted?
  end

  def test_permit_is_recursive
    @params.permit!
    assert @params.permitted?
    assert @params[:person].permitted?
    assert @params[:person][:name].permitted?
    assert @params[:person][:addresses][0].permitted?
  end
end
