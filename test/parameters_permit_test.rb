require 'test_helper'
require 'action_dispatch/http/upload'

class NestedParametersTest < Minitest::Test
  def assert_filtered_out(params, key)
    assert !params.has_key?(key), "key #{key.inspect} has not been filtered out"
  end

  #
  # --- Basic interface --------------------------------------------------------
  #

  # --- nothing ----------------------------------------------------------------

  def test_if_nothing_is_permitted_the_hash_becomes_empty
    params = ActionController::Parameters.new(:id => '1234')
    permitted = params.permit
    assert permitted.permitted?
    assert permitted.empty?
  end

  # --- key --------------------------------------------------------------------

  def test_key_permitted_scalar_values
    values  = ['a', :a, nil]
    values += [0, 1.0, 2**128, BigDecimal('1')]
    values += [true, false]
    values += [Date.today, Time.now, DateTime.now]
    values += [StringIO.new, STDOUT, ActionDispatch::Http::UploadedFile.new(:tempfile => __FILE__), Rack::Test::UploadedFile.new(__FILE__)]

    values.each do |value|
      params = ActionController::Parameters.new(:id => value)
      permitted = params.permit(:id)
      if value.nil?
        assert_nil permitted[:id]
      else
        assert_equal value, permitted[:id]
      end

      %w(i f).each do |suffix|
        params = ActionController::Parameters.new("foo(000#{suffix})" => value)
        permitted = params.permit(:foo)
        if value.nil?
          assert_nil permitted["foo(000#{suffix})"]
        else
          assert_equal value, permitted["foo(000#{suffix})"]
        end
      end
    end
  end

  def test_key_unknown_keys_are_filtered_out
    params = ActionController::Parameters.new(:id => '1234', :injected => 'injected')
    permitted = params.permit(:id)
    assert_equal '1234', permitted[:id]
    assert_filtered_out permitted, :injected
  end

  def test_key_arrays_are_filtered_out
    [[], [1], ['1']].each do |array|
      params = ActionController::Parameters.new(:id => array)
      permitted = params.permit(:id)
      assert_filtered_out permitted, :id

      %w(i f).each do |suffix|
        params = ActionController::Parameters.new("foo(000#{suffix})" => array)
        permitted = params.permit(:foo)
        assert_filtered_out permitted, "foo(000#{suffix})"
      end
    end
  end

  def test_key_hashes_are_filtered_out
    [{}, {:foo => 1}, {:foo => 'bar'}].each do |hash|
      params = ActionController::Parameters.new(:id => hash)
      permitted = params.permit(:id)
      assert_filtered_out permitted, :id

      %w(i f).each do |suffix|
        params = ActionController::Parameters.new("foo(000#{suffix})" => hash)
        permitted = params.permit(:foo)
        assert_filtered_out permitted, "foo(000#{suffix})"
      end
    end
  end

  def test_key_non_permitted_scalar_values_are_filtered_out
    params = ActionController::Parameters.new(:id => Object.new)
    permitted = params.permit(:id)
    assert_filtered_out permitted, :id

    %w(i f).each do |suffix|
      params = ActionController::Parameters.new("foo(000#{suffix})" => Object.new)
      permitted = params.permit(:foo)
      assert_filtered_out permitted, "foo(000#{suffix})"
    end
  end

  def test_key_it_is_not_assigned_if_not_present_in_params
    params = ActionController::Parameters.new(:name => 'Joe')
    permitted = params.permit(:id)
    assert !permitted.has_key?(:id)
  end

  def test_do_not_break_params_filtering_on_nil_values
    params = ActionController::Parameters.new(:a => 1, :b => [1, 2, 3], :c => nil)

    permitted = params.permit(:a, :c => [], :b => [])
    assert_equal 1, permitted[:a]
    assert_equal [1, 2, 3], permitted[:b]
    assert_nil permitted[:c]
  end

  def test_permit_parameters_as_an_array
    params = ActionController::Parameters.new(:foo => 'bar')

    assert_equal 'bar', params.permit([:foo])[:foo]
  end

  # --- key to empty array -----------------------------------------------------

  def test_key_to_empty_array_empty_arrays_pass
    params = ActionController::Parameters.new(:id => [])
    permitted = params.permit(:id => [])
    assert_equal [], permitted[:id]
  end

  def test_key_to_empty_array_arrays_of_permitted_scalars_pass
    [['foo'], [1], ['foo', 'bar'], [1, 2, 3]].each do |array|
      params = ActionController::Parameters.new(:id => array)
      permitted = params.permit(:id => [])
      assert_equal array, permitted[:id]
    end
  end

  def test_key_to_empty_array_permitted_scalar_values_do_not_pass
    ['foo', 1].each do |permitted_scalar|
      params = ActionController::Parameters.new(:id => permitted_scalar)
      permitted = params.permit(:id => [])
      assert_filtered_out permitted, :id
    end
  end

  def test_key_to_empty_array_arrays_of_non_permitted_scalar_do_not_pass
    [[Object.new], [[]], [[1]], [{}], [{:id => '1'}]].each do |non_permitted_scalar|
      params = ActionController::Parameters.new(:id => non_permitted_scalar)
      permitted = params.permit(:id => [])
      assert_filtered_out permitted, :id
    end
  end

  #
  # --- Nesting ----------------------------------------------------------------
  #

  def test_permitted_nested_parameters
    params = ActionController::Parameters.new({
      :book => {
        :title => "Romeo and Juliet",
        :authors => [{
          :name => "William Shakespeare",
          :born => "1564-04-26"
        }, {
          :name => "Christopher Marlowe"
        }, {
          :name => %w(malicious injected names)
        }],
        :details => {
          :pages => 200,
          :genre => "Tragedy"
        }
      },
      :magazine => "Mjallo!"
    })

    permitted = params.permit :book => [ :title, { :authors => [ :name ] }, { :details => :pages } ]

    assert permitted.permitted?
    assert_equal "Romeo and Juliet", permitted[:book][:title]
    assert_equal "William Shakespeare", permitted[:book][:authors][0][:name]
    assert_equal "Christopher Marlowe", permitted[:book][:authors][1][:name]
    assert_equal 200, permitted[:book][:details][:pages]

    assert_filtered_out permitted[:book][:authors][2], :name

    assert_filtered_out permitted, :magazine
    assert_filtered_out permitted[:book][:details], :genre
    assert_filtered_out permitted[:book][:authors][0], :born
  end

  def test_permitted_nested_parameters_with_a_string_or_a_symbol_as_a_key
    params = ActionController::Parameters.new({
      :book => {
        'authors' => [
          { :name => "William Shakespeare", :born => "1564-04-26" },
          { :name => "Christopher Marlowe" }
        ]
      }
    })

    permitted = params.permit :book => [ { 'authors' => [ :name ] } ]

    assert_equal "William Shakespeare", permitted[:book]['authors'][0][:name]
    assert_equal "William Shakespeare", permitted[:book][:authors][0][:name]
    assert_equal "Christopher Marlowe", permitted[:book]['authors'][1][:name]
    assert_equal "Christopher Marlowe", permitted[:book][:authors][1][:name]

    permitted = params.permit :book => [ { :authors => [ :name ] } ]

    assert_equal "William Shakespeare", permitted[:book]['authors'][0][:name]
    assert_equal "William Shakespeare", permitted[:book][:authors][0][:name]
    assert_equal "Christopher Marlowe", permitted[:book]['authors'][1][:name]
    assert_equal "Christopher Marlowe", permitted[:book][:authors][1][:name]
  end

  def test_nested_arrays_with_strings
    params = ActionController::Parameters.new({
      :book => {
        :genres => ["Tragedy"]
      }
    })

    permitted = params.permit :book => {:genres => []}
    assert_equal ["Tragedy"], permitted[:book][:genres]
  end

  def test_permit_may_specify_symbols_or_strings
    params = ActionController::Parameters.new({
      :book => {
        :title => "Romeo and Juliet",
        :author => "William Shakespeare"
      },
      :magazine => "Shakespeare Today"
    })

    permitted = params.permit({ :book => ["title", :author] }, "magazine")
    assert_equal "Romeo and Juliet", permitted[:book][:title]
    assert_equal "William Shakespeare", permitted[:book][:author]
    assert_equal "Shakespeare Today", permitted[:magazine]
  end

  def test_nested_array_with_strings_that_should_be_hashes
    params = ActionController::Parameters.new({
      :book => {
        :genres => ["Tragedy"]
      }
    })

    permitted = params.permit :book => { :genres => :type }
    assert permitted[:book][:genres].empty?
  end

  def test_nested_array_with_strings_that_should_be_hashes_and_additional_values
    params = ActionController::Parameters.new({
      :book => {
        :title => "Romeo and Juliet",
        :genres => ["Tragedy"]
      }
    })

    permitted = params.permit :book => [ :title, { :genres => :type } ]
    assert_equal "Romeo and Juliet", permitted[:book][:title]
    assert permitted[:book][:genres].empty?
  end

  def test_nested_string_that_should_be_a_hash
    params = ActionController::Parameters.new({
      :book => {
        :genre => "Tragedy"
      }
    })

    permitted = params.permit :book => { :genre => :type }
    assert_nil permitted[:book][:genre]
  end

  def test_fields_for_style_nested_params
    params = ActionController::Parameters.new({
      :book => {
        :authors_attributes => {
          :'0' => { :name => 'William Shakespeare', :age_of_death => '52' },
          :'1' => { :name => 'Unattributed Assistant' },
          :'2' => { :name => %w(injected names)}
        }
      }
    })
    permitted = params.permit :book => { :authors_attributes => [ :name ] }

    refute_nil permitted[:book][:authors_attributes]['0']
    refute_nil permitted[:book][:authors_attributes]['1']
    assert permitted[:book][:authors_attributes]['2'].empty?
    assert_equal 'William Shakespeare', permitted[:book][:authors_attributes]['0'][:name]
    assert_equal 'Unattributed Assistant', permitted[:book][:authors_attributes]['1'][:name]

    assert_filtered_out permitted[:book][:authors_attributes]['0'], :age_of_death
  end

  def test_fields_for_style_nested_params_with_negative_numbers
    params = ActionController::Parameters.new({
      :book => {
        :authors_attributes => {
          :'-1' => { :name => 'William Shakespeare', :age_of_death => '52' },
          :'-2' => { :name => 'Unattributed Assistant' }
        }
      }
    })
    permitted = params.permit :book => { :authors_attributes => [:name] }

    refute_nil permitted[:book][:authors_attributes]['-1']
    refute_nil permitted[:book][:authors_attributes]['-2']
    assert_equal 'William Shakespeare', permitted[:book][:authors_attributes]['-1'][:name]
    assert_equal 'Unattributed Assistant', permitted[:book][:authors_attributes]['-2'][:name]

    assert_filtered_out permitted[:book][:authors_attributes]['-1'], :age_of_death
  end

  def test_fields_for_style_nested_params_with_nested_arrays
    params = ActionController::Parameters.new({
      :book => {
        :authors_attributes => {
          :'0' => ['William Shakespeare', '52'],
          :'1' => ['Unattributed Assistant']
        }
      }
    })
    permitted = params.permit :book => { :authors_attributes => { :'0' => [], :'1' => [] } }

    refute_nil permitted[:book][:authors_attributes]['0']
    refute_nil permitted[:book][:authors_attributes]['1']
    assert_nil permitted[:book][:authors_attributes]['2']
    assert_equal 'William Shakespeare', permitted[:book][:authors_attributes]['0'][0]
    assert_equal 'Unattributed Assistant', permitted[:book][:authors_attributes]['1'][0]
  end

  def test_nested_number_as_key
    params = ActionController::Parameters.new({
      :product => {
        :properties => {
          '0' => "prop0",
          '1' => "prop1"
        }
      }
    })
    params = params.require(:product).permit(:properties => ["0"])
    refute_nil        params[:properties]["0"]
    assert_nil            params[:properties]["1"]
    assert_equal "prop0", params[:properties]["0"]
  end

  def test_fetch_with_a_default_value_of_a_hash_does_not_mutate_the_object
    params = ActionController::Parameters.new({})
    params.fetch :foo, {}
    assert_nil params[:foo]
  end

  def test_hashes_in_array_values_get_wrapped
    params = ActionController::Parameters.new(:foo => [{}, {}])
    params[:foo].each do |hash|
      assert !hash.permitted?
    end
  end

  def test_permit_with_deeply_nested_structures
    params = ActionController::Parameters.new({
      :user => {
        :profile => {
          :settings => {
            :notifications => {
              :email => true,
              :sms => false
            }
          }
        }
      }
    })

    permitted = params.permit(:user => { :profile => { :settings => { :notifications => [:email, :sms] } } })

    assert permitted.permitted?
    assert_equal true, permitted[:user][:profile][:settings][:notifications][:email]
    assert_equal false, permitted[:user][:profile][:settings][:notifications][:sms]
  end

  def test_permit_with_mixed_array_and_hash
    params = ActionController::Parameters.new({
      :posts => [
        { :title => 'Post 1', :tags => ['ruby', 'rails'] },
        { :title => 'Post 2', :tags => ['js', 'react'] }
      ]
    })

    permitted = params.permit(:posts => [:title, { :tags => [] }])

    assert permitted.permitted?
    assert_equal 'Post 1', permitted[:posts][0][:title]
    assert_equal ['ruby', 'rails'], permitted[:posts][0][:tags]
    assert_equal 'Post 2', permitted[:posts][1][:title]
    assert_equal ['js', 'react'], permitted[:posts][1][:tags]
  end

  def test_permit_with_empty_nested_hash
    params = ActionController::Parameters.new({
      :user => {
        :profile => {}
      }
    })

    permitted = params.permit(:user => { :profile => {} })

    assert permitted.permitted?
    assert_instance_of ActionController::Parameters, permitted[:user][:profile]
    assert permitted[:user][:profile].permitted?
    assert_empty permitted[:user][:profile]
  end

  def test_permit_with_symbol_keys_in_nested_structure
    params = ActionController::Parameters.new({
      user: {
        profile: {
          name: 'John',
          'age' => 30
        }
      }
    })

    permitted = params.permit(user: { profile: [:name, :age] })

    assert permitted.permitted?
    assert_equal 'John', permitted[:user][:profile][:name]
    assert_equal 30, permitted[:user][:profile][:age]
  end

  def test_permit_filters_unknown_nested_keys
    params = ActionController::Parameters.new({
      :user => {
        :name => 'John',
        :secret => 'hidden'
      }
    })

    permitted = params.permit(:user => [:name])

    assert permitted.permitted?
    assert_equal 'John', permitted[:user][:name]
    assert_filtered_out permitted[:user], :secret
  end

  def test_permit_with_multiple_levels_of_arrays
    params = ActionController::Parameters.new({
      :matrix => [
        [1, 2, 3],
        [4, 5, 6]
      ]
    })

    permitted = params.permit(:matrix => [])

    assert permitted.permitted?
    # Nested arrays are not permitted by default, so matrix should be filtered out
    assert_filtered_out permitted, :matrix
  end

  def test_permit_with_complex_mixed_structure
    params = ActionController::Parameters.new({
      :company => {
        :name => 'ACME',
        :employees => [
          { :name => 'Alice', :skills => ['Ruby', 'Rails'] },
          { :name => 'Bob', :skills => ['JS', 'React'] }
        ],
        :offices => {
          :headquarters => { :city => 'NYC', :country => 'USA' },
          :branch => { :city => 'LA', :country => 'USA' }
        }
      }
    })

    permitted = params.permit(:company => [
      :name,
      { :employees => [:name, { :skills => [] }] },
      { :offices => { :headquarters => [:city, :country], :branch => [:city, :country] } }
    ])

    assert permitted.permitted?
    assert_equal 'ACME', permitted[:company][:name]
    assert_equal 'Alice', permitted[:company][:employees][0][:name]
    assert_equal ['Ruby', 'Rails'], permitted[:company][:employees][0][:skills]
    assert_equal 'NYC', permitted[:company][:offices][:headquarters][:city]
    assert_equal 'USA', permitted[:company][:offices][:headquarters][:country]
  end
end
