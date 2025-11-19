# frozen_string_literal: true

require 'test_helper'

class CoreParametersTest < Minitest::Test
  def setup
    # Ensure no action on unpermitted parameters for testing
    StrongParameters::Core::Parameters.action_on_unpermitted_parameters = nil

    @params = StrongParameters::Core::Parameters.new(
      name: 'John',
      email: 'john@example.com',
      age: 30,
      admin: true,
      profile: {
        bio: 'Developer',
        location: 'NYC'
      },
      tags: ['ruby', 'rails'],
      scores: [95, 87, 92]
    )
  end

  # Test initialization
  def test_initialization_with_nil
    params = StrongParameters::Core::Parameters.new(nil)
    assert_equal({}, params.to_h)
    assert !params.permitted?
  end

  def test_initialization_with_empty_hash
    params = StrongParameters::Core::Parameters.new({})
    assert_equal({}, params.to_h)
    assert !params.permitted?
  end

  def test_initialization_with_hash
    params = StrongParameters::Core::Parameters.new(key: 'value')
    assert_equal 'value', params[:key]
    assert !params.permitted?
  end

  def test_initialization_normalizes_keys
    params = StrongParameters::Core::Parameters.new('name' => 'John', :email => 'test@example.com')
    assert_equal 'John', params[:name]
    assert_equal 'test@example.com', params[:email]
    assert_equal ['name', 'email'], params.keys
  end

  def test_initialization_with_nested_hashes
    params = StrongParameters::Core::Parameters.new(
      user: { profile: { name: 'John' } }
    )
    assert params[:user].is_a?(StrongParameters::Core::Parameters)
    assert params[:user][:profile].is_a?(StrongParameters::Core::Parameters)
    assert_equal 'John', params[:user][:profile][:name]
  end

   def test_initialization_with_arrays_of_hashes
     params = StrongParameters::Core::Parameters.new(
       users: [{ name: 'John' }, { name: 'Jane' }]
     )
     assert params[:users].is_a?(Array)
     assert params[:users][0].is_a?(StrongParameters::Core::Parameters)
     assert params[:users][1].is_a?(StrongParameters::Core::Parameters)
     assert_equal 'John', params[:users][0][:name]
     assert_equal 'Jane', params[:users][1][:name]
   end

   def test_initialization_with_deeply_nested_structure
     params = StrongParameters::Core::Parameters.new(
       user: {
         profile: {
           settings: {
             notifications: {
               email: true,
               sms: false
             }
           }
         }
       }
     )

     assert params[:user].is_a?(StrongParameters::Core::Parameters)
     assert params[:user][:profile].is_a?(StrongParameters::Core::Parameters)
     assert params[:user][:profile][:settings].is_a?(StrongParameters::Core::Parameters)
     assert params[:user][:profile][:settings][:notifications].is_a?(StrongParameters::Core::Parameters)
     assert_equal true, params[:user][:profile][:settings][:notifications][:email]
     assert_equal false, params[:user][:profile][:settings][:notifications][:sms]
   end

   def test_initialization_with_large_hash
     large_hash = {}
     1000.times { |i| large_hash["key#{i}"] = "value#{i}" }

     params = StrongParameters::Core::Parameters.new(large_hash)
     assert_equal 1000, params.size
     assert_equal 'value0', params[:key0]
     assert_equal 'value999', params[:key999]
   end

   def test_initialization_with_mixed_key_types
     params = StrongParameters::Core::Parameters.new(
       'string_key' => 'string_value',
       :symbol_key => 'symbol_value',
       123 => 'numeric_key_value'
     )

     assert_equal 'string_value', params['string_key']
     assert_equal 'symbol_value', params[:symbol_key]
     assert_equal 'numeric_key_value', params['123']
   end

   def test_initialization_with_frozen_hash
     frozen_hash = { name: 'John', age: 30 }.freeze
     params = StrongParameters::Core::Parameters.new(frozen_hash)

     assert_equal 'John', params[:name]
     assert_equal 30, params[:age]
   end

   def test_initialization_with_empty_nested_hashes
     params = StrongParameters::Core::Parameters.new(
       user: {},
       profile: { settings: {} }
     )

     assert params[:user].is_a?(StrongParameters::Core::Parameters)
     assert params[:user].empty?
     assert params[:profile][:settings].is_a?(StrongParameters::Core::Parameters)
     assert params[:profile][:settings].empty?
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

  def test_permit_bang_on_nested_parameters
    @params.permit!
    assert @params[:profile].permitted?
  end

  def test_permit_bang_on_array_of_parameters
    params = StrongParameters::Core::Parameters.new(
      users: [{ name: 'John' }, { name: 'Jane' }]
    )
    params.permit!
    assert params[:users][0].permitted?
    assert params[:users][1].permitted?
  end

  # Test require method
  def test_require_returns_value_when_present
    params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
    result = params.require(:user)
    assert_equal 'John', result[:name]
  end

  def test_require_raises_when_key_missing
    error = assert_raises(StrongParameters::Core::ParameterMissing) do
      @params.require(:nonexistent)
    end
    assert_equal 'nonexistent', error.param
    assert_match(/param is missing or the value is empty: nonexistent/, error.message)
    assert_match(/Available keys: name, email, age, admin, profile, tags, scores/, error.message)
  end

  def test_require_raises_with_suggestions
    params = StrongParameters::Core::Parameters.new(usr: { name: 'John' }, usrname: 'test')
    error = assert_raises(StrongParameters::Core::ParameterMissing) do
      params.require(:user)
    end
    assert_match(/Did you mean\? usr, usrname/, error.message)
  end

  def test_parameter_missing_with_no_similar_keys
    params = StrongParameters::Core::Parameters.new(xyz: 'value', abc: 'other')
    error = assert_raises(StrongParameters::Core::ParameterMissing) do
      params.require(:user)
    end
    assert_match(/param is missing or the value is empty: user/, error.message)
    assert_match(/Available keys: xyz, abc/, error.message)
    refute_match(/Did you mean\?/, error.message)
  end

  def test_parameter_missing_with_many_similar_keys
    params = StrongParameters::Core::Parameters.new(
      usr: 'value',
      user_name: 'value',
      user_email: 'value',
      username: 'value',
      usr_profile: 'value'
    )
    error = assert_raises(StrongParameters::Core::ParameterMissing) do
      params.require(:user)
    end
    # Should limit to 3 suggestions
    assert_match(/Did you mean\? usr, user_name, user_email/, error.message)
  end

  def test_require_raises_when_value_empty
    params = StrongParameters::Core::Parameters.new(user: nil)
    assert_raises(StrongParameters::Core::ParameterMissing) do
      params.require(:user)
    end
  end

  def test_require_raises_when_value_empty_string
    params = StrongParameters::Core::Parameters.new(user: '')
    assert_raises(StrongParameters::Core::ParameterMissing) do
      params.require(:user)
    end
  end

  def test_require_raises_when_value_empty_array
    params = StrongParameters::Core::Parameters.new(user: [])
    assert_raises(StrongParameters::Core::ParameterMissing) do
      params.require(:user)
    end
  end

  def test_require_returns_false_when_present
    params = StrongParameters::Core::Parameters.new(active: false)
    assert_equal false, params.require(:active)
  end

  def test_require_returns_zero_when_present
    params = StrongParameters::Core::Parameters.new(count: 0)
    assert_equal 0, params.require(:count)
  end

  def test_require_raises_when_value_empty_hash
    params = StrongParameters::Core::Parameters.new(user: {})
    assert_raises(StrongParameters::Core::ParameterMissing) do
      params.require(:user)
    end
  end

   def test_require_accepts_string_key
     params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
     result = params.require('user')
     assert_equal 'John', result[:name]
   end

   def test_require_sets_required_key_on_result
     params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
     result = params.require(:user)
     assert_equal :user, result.required_key
   end

   def test_required_alias_works
     params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
     result = params.required(:user)
     assert_equal 'John', result[:name]
   end

   def test_require_with_numeric_key
     params = StrongParameters::Core::Parameters.new('123' => { name: 'John' })
     result = params.require(123)
     assert_equal 'John', result[:name]
   end

   def test_require_with_false_value
     params = StrongParameters::Core::Parameters.new(active: false)
     result = params.require(:active)
     assert_equal false, result
   end

   def test_require_with_zero_value
     params = StrongParameters::Core::Parameters.new(count: 0)
     result = params.require(:count)
     assert_equal 0, result
   end

   def test_require_with_nested_require
     params = StrongParameters::Core::Parameters.new(
       company: {
         employees: [
           { name: 'Alice' },
           { name: 'Bob' }
         ]
       }
     )

     company = params.require(:company)
     employees = company.require(:employees)
     assert employees.is_a?(Array)
     assert_equal 'Alice', employees[0][:name]
     assert_equal 'Bob', employees[1][:name]
   end

   def test_require_preserves_required_key_through_multiple_calls
     params = StrongParameters::Core::Parameters.new(
       organization: {
         department: {
           team: { name: 'Dev Team' }
         }
       }
     )

     org = params.require(:organization)
     dept = org.require(:department)
     team = dept.require(:team)

     assert_equal :organization, org.required_key
     assert_equal :organization, dept.required_key  # Inherits from parent
     assert_equal :organization, team.required_key
   end

   def test_require_with_array_value
     params = StrongParameters::Core::Parameters.new(tags: ['ruby', 'rails'])
     result = params.require(:tags)
     assert_equal ['ruby', 'rails'], result
   end

   def test_require_with_empty_array
     params = StrongParameters::Core::Parameters.new(items: [])
     assert_raises(StrongParameters::Core::ParameterMissing) do
       params.require(:items)
     end
   end

  # Test permit method
  def test_permit_with_single_key
    permitted = @params.permit(:name)
    assert_equal 'John', permitted[:name]
    assert_nil permitted[:email]
    assert permitted.permitted?
  end

  def test_permit_with_multiple_keys
    permitted = @params.permit(:name, :email, :age)
    assert_equal 'John', permitted[:name]
    assert_equal 'john@example.com', permitted[:email]
    assert_equal 30, permitted[:age]
    assert_nil permitted[:admin]
    assert permitted.permitted?
  end

  def test_permit_with_string_keys
    permitted = @params.permit('name', 'email')
    assert_equal 'John', permitted[:name]
    assert_equal 'john@example.com', permitted[:email]
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

  def test_permit_with_nested_hash
    permitted = @params.permit(profile: [:bio, :location])
    assert_equal 'Developer', permitted[:profile][:bio]
    assert_equal 'NYC', permitted[:profile][:location]
    assert permitted[:profile].permitted?
  end

  def test_permit_with_array_of_scalars
    permitted = @params.permit(tags: [])
    assert_equal ['ruby', 'rails'], permitted[:tags]
    assert permitted.permitted?
  end

  def test_permit_with_array_of_scalars_explicit
    permitted = @params.permit(scores: [])
    assert_equal [95, 87, 92], permitted[:scores]
    assert permitted.permitted?
  end

   def test_permit_with_complex_nested_structure
     params = StrongParameters::Core::Parameters.new(
       user: {
         name: 'John',
         profile: {
           bio: 'Developer',
           skills: ['ruby', 'rails']
         },
         addresses: [
           { city: 'NYC', zip: '10001' },
           { city: 'LA', zip: '90210' }
         ]
       }
     )

     permitted = params.permit(
       user: [
         :name,
         profile: [:bio, skills: []],
         addresses: [:city, :zip]
       ]
     )

     assert_equal 'John', permitted[:user][:name]
     assert_equal 'Developer', permitted[:user][:profile][:bio]
     assert_equal ['ruby', 'rails'], permitted[:user][:profile][:skills]
     assert_equal 'NYC', permitted[:user][:addresses][0][:city]
     assert_equal '10001', permitted[:user][:addresses][0][:zip]
     assert_equal 'LA', permitted[:user][:addresses][1][:city]
     assert_equal '90210', permitted[:user][:addresses][1][:zip]
    end

    def test_permit_with_extremely_nested_structure
      params = StrongParameters::Core::Parameters.new(
        organization: {
          departments: [
            {
              name: 'Engineering',
              teams: [
                {
                  name: 'Backend',
                  members: [
                    { name: 'Alice', role: 'senior' },
                    { name: 'Bob', role: 'junior' }
                  ]
                },
                {
                  name: 'Frontend',
                  members: [
                    { name: 'Charlie', role: 'lead' }
                  ]
                }
              ]
            },
            {
              name: 'Sales',
              teams: []
            }
          ]
        }
      )

      permitted = params.permit(
        organization: {
          departments: [
            :name,
            teams: [
              :name,
              members: [:name, :role]
            ]
          ]
        }
      )

      assert_equal 'Engineering', permitted[:organization][:departments][0][:name]
      assert_equal 'Backend', permitted[:organization][:departments][0][:teams][0][:name]
      assert_equal 'Alice', permitted[:organization][:departments][0][:teams][0][:members][0][:name]
      assert_equal 'senior', permitted[:organization][:departments][0][:teams][0][:members][0][:role]
      assert_equal 'Sales', permitted[:organization][:departments][1][:name]
      assert_equal [], permitted[:organization][:departments][1][:teams]
    end

    def test_permit_with_mixed_array_and_hash_filters
      params = StrongParameters::Core::Parameters.new(
        posts: [
          { title: 'Post 1', tags: ['ruby', 'rails'], metadata: { published: true } },
          { title: 'Post 2', tags: ['js'], metadata: { published: false } }
        ],
        categories: ['tech', 'news']
      )

      permitted = params.permit(
        posts: [:title, tags: [], metadata: [:published]],
        categories: []
      )

      assert_equal 'Post 1', permitted[:posts][0][:title]
      assert_equal ['ruby', 'rails'], permitted[:posts][0][:tags]
      assert_equal true, permitted[:posts][0][:metadata][:published]
      assert_equal 'Post 2', permitted[:posts][1][:title]
      assert_equal ['js'], permitted[:posts][1][:tags]
      assert_equal false, permitted[:posts][1][:metadata][:published]
      assert_equal ['tech', 'news'], permitted[:categories]
    end

    def test_permit_with_fields_for_style_arrays
      params = StrongParameters::Core::Parameters.new(
        '0' => { name: 'John', age: '30', secret: 'hidden' },
        '1' => { name: 'Jane', age: '25', secret: 'also_hidden' },
        '2' => { name: 'Bob', age: '35' }
      )

      permitted = params.permit(
        '0' => [:name, :age],
        '1' => [:name, :age],
        '2' => [:name, :age]
      )

      assert_equal 'John', permitted['0'][:name]
      assert_equal '30', permitted['0'][:age]
      assert_nil permitted['0'][:secret]
      assert_equal 'Jane', permitted['1'][:name]
      assert_equal '25', permitted['1'][:age]
      assert_nil permitted['1'][:secret]
      assert_equal 'Bob', permitted['2'][:name]
      assert_equal '35', permitted['2'][:age]
    end

    def test_permit_with_negative_indexed_fields_for
      params = StrongParameters::Core::Parameters.new(
        '-1' => { name: 'John' },
        '0' => { name: 'Jane' }
      )

      permitted = params.permit(
        '-1' => [:name],
        '0' => [:name]
      )

      assert_equal 'John', permitted['-1'][:name]
      assert_equal 'Jane', permitted['0'][:name]
    end

    def test_permit_with_nil_values
     params = StrongParameters::Core::Parameters.new(name: 'John', age: nil, active: false)
     permitted = params.permit(:name, :age, :active)
     assert_equal 'John', permitted[:name]
     assert_nil permitted[:age]
     assert_equal false, permitted[:active]
   end

   def test_permit_with_empty_arrays
     params = StrongParameters::Core::Parameters.new(tags: [], scores: [1, 2, 3])
     permitted = params.permit(tags: [], scores: [])
     assert_equal [], permitted[:tags]
     assert_equal [1, 2, 3], permitted[:scores]
   end

   def test_permit_with_mixed_array_types
     params = StrongParameters::Core::Parameters.new(items: ['string', 42, true, nil])
     permitted = params.permit(items: [])
     assert_equal ['string', 42, true, nil], permitted[:items]
   end

   def test_permit_with_invalid_array_elements
     params = StrongParameters::Core::Parameters.new(items: ['valid', {}])
     permitted = params.permit(items: [])
     # Should not permit array with invalid elements
     assert_nil permitted[:items]
   end

   def test_permit_with_deeply_nested_empty_hashes
     params = StrongParameters::Core::Parameters.new(user: { profile: {} })
     permitted = params.permit(user: { profile: {} })
     assert_equal({}, permitted[:user][:profile].to_h)
   end

   def test_permit_with_duplicate_keys_in_filters
     params = StrongParameters::Core::Parameters.new(name: 'John', age: 30)
     permitted = params.permit(:name, :name, :age)
     assert_equal 'John', permitted[:name]
     assert_equal 30, permitted[:age]
   end

  def test_permit_with_mixed_filters_and_unpermitted_keys
    StrongParameters::Core::Parameters.action_on_unpermitted_parameters = :raise

    params = StrongParameters::Core::Parameters.new(
      user: {
        name: 'John',
        email: 'john@example.com',
        admin: true,
        profile: {
          bio: 'Developer',
          secret: 'hidden'
        }
      },
      extra: 'value'
    )

    assert_raises(StrongParameters::Core::UnpermittedParameters) do
      params.permit(
        user: [:name, :email, profile: [:bio]],  # admin and secret not permitted
        extra: []  # extra not permitted
      )
    end
  end

  def test_permit_with_fields_for_style_and_multi_param
    params = StrongParameters::Core::Parameters.new(
      'posts' => {
        '0' => { title: 'First Post', content: 'Content 1' },
        '1' => { title: 'Second Post', content: 'Content 2' }
      },
      'event_date(1i)' => '2023',
      'event_date(2i)' => '12',
      'event_date(3i)' => '25'
    )

    permitted = params.permit(
      {posts: [:title, :content]},
      :event_date
    )

    assert_equal 'First Post', permitted[:posts]['0'][:title]
    assert_equal 'Content 2', permitted[:posts]['1'][:content]
    assert_equal '2023', permitted['event_date(1i)']
    assert_equal '12', permitted['event_date(2i)']
    assert_equal '25', permitted['event_date(3i)']
  end

  # Test transform_params method
  def test_transform_params_with_inference
    # Mock the ParamsRegistry
    StrongParameters::Core::ParamsRegistry.register(:user, Class.new(StrongParameters::Core::ApplicationParams) do
      def self.permitted_attributes(action: nil)
        [:name, :email]
      end
    end)

    params = StrongParameters::Core::Parameters.new(user: { name: 'John', email: 'john@example.com', admin: true })
    user_params = params.require(:user)
    permitted = user_params.transform_params

    assert_equal 'John', permitted[:name]
    assert_equal 'john@example.com', permitted[:email]
    assert_nil permitted[:admin]
    assert permitted.permitted?
  end

  def test_transform_params_with_explicit_class
    user_params_class = Class.new(StrongParameters::Core::ApplicationParams) do
      def self.permitted_attributes(action: nil)
        [:name, :age]
      end
    end

    params = StrongParameters::Core::Parameters.new(user: { name: 'John', age: 30, admin: true })
    user_params = params.require(:user)
    permitted = user_params.transform_params(user_params_class)

    assert_equal 'John', permitted[:name]
    assert_equal 30, permitted[:age]
    assert_nil permitted[:admin]
  end

  def test_transform_params_with_action
    user_params_class = Class.new(StrongParameters::Core::ApplicationParams) do
      def self.permitted_attributes(action: nil)
        case action
        when :create
          [:name, :email]
        when :update
          [:name, :age]
        else
          []
        end
      end
    end

    params = StrongParameters::Core::Parameters.new(user: { name: 'John', email: 'john@example.com', age: 30 })
    user_params = params.require(:user)

    create_permitted = user_params.transform_params(user_params_class, action: :create)
    assert_equal 'John', create_permitted[:name]
    assert_equal 'john@example.com', create_permitted[:email]
    assert_nil create_permitted[:age]

    update_permitted = user_params.transform_params(user_params_class, action: :update)
    assert_equal 'John', update_permitted[:name]
    assert_equal 30, update_permitted[:age]
    assert_nil update_permitted[:email]
  end

  def test_transform_params_with_additional_attrs
    user_params_class = Class.new(StrongParameters::Core::ApplicationParams) do
      def self.permitted_attributes(action: nil)
        [:name]
      end
    end

    params = StrongParameters::Core::Parameters.new(user: { name: 'John', token: 'abc123', admin: true })
    user_params = params.require(:user)
    permitted = user_params.transform_params(user_params_class, additional_attrs: [:token])

    assert_equal 'John', permitted[:name]
    assert_equal 'abc123', permitted[:token]
    assert_nil permitted[:admin]
  end

  def test_transform_params_with_metadata
    user_params_class = Class.new(StrongParameters::Core::ApplicationParams) do
      allow :name
      allow :admin_override
      metadata :current_user

      def self.apply_transformations(params, options)
        current_user = options[:current_user]
        if current_user&.admin?
          params.merge('admin_override' => true)
        else
          params
        end
      end
    end

    params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
    user_params = params.require(:user)

    # Mock current_user
    current_user = Object.new
    def current_user.admin?; true; end

    permitted = user_params.transform_params(user_params_class, current_user: current_user)
    assert_equal 'John', permitted[:name]
    assert_equal true, permitted[:admin_override]
  end

  def test_transform_params_with_invalid_metadata
    user_params_class = Class.new(StrongParameters::Core::ApplicationParams) do
      def self.metadata_allowed?(key)
        false
      end
    end

    params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
    user_params = params.require(:user)

    assert_raises(ArgumentError) do
      user_params.transform_params(user_params_class, invalid_key: 'value')
    end
  end

  def test_transform_params_with_nil_class
    params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
    user_params = params.require(:user)
    permitted = user_params.transform_params(nil)

    assert_equal({}, permitted.to_h)
    assert permitted.permitted?
  end

  def test_transform_params_without_required_key
    params = StrongParameters::Core::Parameters.new(name: 'John')
    permitted = params.transform_params

    assert_equal({}, permitted.to_h)
    assert permitted.permitted?
  end

  def test_transform_params_with_unregistered_params_class
    # Ensure no registration for :user
    StrongParameters::Core::ParamsRegistry.clear!

    params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
    user_params = params.require(:user)
    permitted = user_params.transform_params

    assert_equal({}, permitted.to_h)
    assert permitted.permitted?
  end

  def test_transform_params_with_nil_params_class
    params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
    user_params = params.require(:user)
    permitted = user_params.transform_params(nil)

    assert_equal({}, permitted.to_h)
    assert permitted.permitted?
  end

  # Test hash access methods
  def test_bracket_accessor_with_symbol
    assert_equal 'John', @params[:name]
  end

  def test_bracket_accessor_with_string
    assert_equal 'John', @params['name']
  end

  def test_bracket_accessor_returns_nil_for_missing_key
    assert_nil @params[:nonexistent]
  end

  def test_bracket_accessor_converts_hash_to_parameters
    profile = @params[:profile]
    assert profile.is_a?(StrongParameters::Core::Parameters)
    assert_equal 'Developer', profile[:bio]
  end

  def test_bracket_equals_sets_value
    @params[:new_key] = 'new_value'
    assert_equal 'new_value', @params[:new_key]
  end

  def test_bracket_equals_normalizes_key
    @params['new_key'] = 'new_value'
    assert_equal 'new_value', @params[:new_key]
  end

  def test_fetch_returns_value_when_present
    assert_equal 'John', @params.fetch(:name)
  end

  def test_fetch_raises_when_key_missing
    assert_raises(StrongParameters::Core::ParameterMissing) do
      @params.fetch(:nonexistent)
    end
  end

  def test_fetch_with_default_value
    result = @params.fetch(:nonexistent, 'default')
    assert_equal 'default', result
  end

  def test_fetch_with_block
    result = @params.fetch(:nonexistent) { 'from block' }
    assert_equal 'from block', result
  end

  def test_fetch_converts_hash_to_parameters
    profile = @params.fetch(:profile)
    assert profile.is_a?(StrongParameters::Core::Parameters)
  end

  def test_has_key_with_symbol
    assert @params.has_key?(:name)
  end

  def test_has_key_with_string
    assert @params.has_key?('name')
  end

  def test_has_key_returns_false_for_missing
    assert !@params.has_key?(:nonexistent)
  end

  def test_key_alias_works
    assert @params.key?(:name)
  end

  def test_include_alias_works
    assert @params.include?(:name)
  end

  def test_delete_removes_key
    @params.delete(:name)
    assert_nil @params[:name]
  end

  def test_delete_returns_value
    result = @params.delete(:name)
    assert_equal 'John', result
  end

   def test_delete_normalizes_key
     result = @params.delete('name')
     assert_equal 'John', result
   end

   def test_bracket_accessor_with_numeric_key
     params = StrongParameters::Core::Parameters.new('123' => 'numeric')
     assert_equal 'numeric', params[123]
     assert_equal 'numeric', params['123']
   end

   def test_bracket_accessor_with_nil_key
     params = StrongParameters::Core::Parameters.new(nil => 'nil_value')
     assert_equal 'nil_value', params[nil]
     assert_equal 'nil_value', params['']
   end

   def test_bracket_accessor_with_boolean_key
     params = StrongParameters::Core::Parameters.new(true => 'true_value', false => 'false_value')
     assert_equal 'true_value', params[true]
     assert_equal 'false_value', params[false]
   end

   def test_bracket_equals_with_numeric_key
     params = StrongParameters::Core::Parameters.new
     params[123] = 'numeric_value'
     assert_equal 'numeric_value', params['123']
     assert_equal 'numeric_value', params[123]
   end

   def test_bracket_equals_with_nil_key
     params = StrongParameters::Core::Parameters.new
     params[nil] = 'nil_value'
     assert_equal 'nil_value', params['']
   end

   def test_fetch_with_numeric_key
     params = StrongParameters::Core::Parameters.new('42' => 'answer')
     assert_equal 'answer', params.fetch(42)
   end

   def test_fetch_with_default_proc
     params = StrongParameters::Core::Parameters.new
     result = params.fetch(:missing) { |key| "default_for_#{key}" }
     assert_equal 'default_for_missing', result
   end

   def test_has_key_with_numeric_key
     params = StrongParameters::Core::Parameters.new('42' => 'answer')
     assert params.has_key?(42)
     assert params.has_key?('42')
   end

   def test_has_key_with_nil_key
     params = StrongParameters::Core::Parameters.new(nil => 'value')
     assert params.has_key?(nil)
     assert params.has_key?('')
   end

   def test_delete_with_numeric_key
     params = StrongParameters::Core::Parameters.new('42' => 'answer')
     result = params.delete(42)
     assert_equal 'answer', result
     assert_nil params['42']
   end

   def test_delete_with_block
     params = StrongParameters::Core::Parameters.new(name: 'John')
     result = params.delete(:missing) { 'not found' }
     assert_equal 'not found', result
   end

   def test_bracket_accessor_converts_nested_arrays
     params = StrongParameters::Core::Parameters.new(
       items: [
         { name: 'item1' },
         { name: 'item2' }
       ]
     )

     items = params[:items]
     assert items.is_a?(Array)
     assert items[0].is_a?(StrongParameters::Core::Parameters)
     assert_equal 'item1', items[0][:name]
   end

   def test_fetch_converts_nested_arrays
     params = StrongParameters::Core::Parameters.new(
       items: [
         { name: 'item1' }
       ]
     )

     items = params.fetch(:items)
     assert items.is_a?(Array)
     assert items[0].is_a?(StrongParameters::Core::Parameters)
   end

  def test_slice_returns_subset
    sliced = @params.slice(:name, :email)
    assert_equal 'John', sliced[:name]
    assert_equal 'john@example.com', sliced[:email]
    assert_nil sliced[:age]
  end

  def test_slice_preserves_permitted_flag
    @params.permit!
    sliced = @params.slice(:name)
    assert sliced.permitted?
  end

  def test_slice_preserves_required_key
    params = StrongParameters::Core::Parameters.new(user: { name: 'John', email: 'john@example.com' })
    user_params = params.require(:user)
    sliced = user_params.slice(:name)
    assert_equal :user, sliced.required_key
  end

  def test_slice_returns_new_instance
    sliced = @params.slice(:name)
    refute_equal @params.object_id, sliced.object_id
  end

  def test_except_excludes_keys
    excepted = @params.except(:name, :email)
    assert_nil excepted[:name]
    assert_nil excepted[:email]
    assert_equal 30, excepted[:age]
  end

  def test_except_returns_new_instance
    excepted = @params.except(:name)
    refute_equal @params.object_id, excepted.object_id
  end

  def test_dup_creates_new_instance
    duped = @params.dup
    refute_equal @params.object_id, duped.object_id
  end

  def test_dup_preserves_data
    duped = @params.dup
    assert_equal 'John', duped[:name]
    assert_equal 'john@example.com', duped[:email]
    assert_equal 30, duped[:age]
  end

  def test_dup_preserves_permitted_flag
    @params.permit!
    duped = @params.dup
    assert duped.permitted?
  end

  def test_dup_preserves_required_key
    params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
    user_params = params.require(:user)
    duped = user_params.dup
    assert_equal :user, duped.required_key
  end

  def test_dup_creates_shallow_copy
    duped = @params.dup
    duped[:new_key] = 'new_value'
    assert_nil @params[:new_key]
  end

   def test_dup_with_nested_parameters
     duped = @params.dup
     duped[:profile][:new_field] = 'new_value'
     assert_nil @params[:profile][:new_field]
   end

   def test_slice_with_nonexistent_keys
     sliced = @params.slice(:name, :nonexistent)
     assert_equal 'John', sliced[:name]
     assert_nil sliced[:nonexistent]
   end

   def test_slice_with_empty_keys
     sliced = @params.slice
     assert_equal({}, sliced.to_h)
     assert !sliced.permitted?
   end

   def test_slice_with_mixed_key_types
     params = StrongParameters::Core::Parameters.new('name' => 'John', :age => 30, 'email' => 'test@example.com')
     sliced = params.slice('name', :age)
     assert_equal 'John', sliced[:name]
     assert_equal 30, sliced[:age]
     assert_nil sliced[:email]
   end

   def test_except_with_no_keys
     excepted = @params.except
     assert_equal @params.to_h, excepted.to_h
   end

    def test_except_with_all_keys
      excepted = @params.except(*@params.keys)
      assert_equal({}, excepted.to_h)
    end

    def test_except_preserves_permitted_flag
      @params.permit!
      excepted = @params.except(:name)
      assert excepted.permitted?
    end

    def test_slice_with_nested_parameters
      params = StrongParameters::Core::Parameters.new(
        user: { name: 'John', email: 'john@example.com', profile: { bio: 'Developer' } },
        admin: true
      )

      sliced = params.slice(:user)
      assert_equal 'John', sliced[:user][:name]
      assert_equal 'john@example.com', sliced[:user][:email]
      assert_equal 'Developer', sliced[:user][:profile][:bio]
      assert_nil sliced[:admin]
    end

    def test_except_with_nested_parameters
      params = StrongParameters::Core::Parameters.new(
        user: { name: 'John', email: 'john@example.com', profile: { bio: 'Developer' } },
        admin: true
      )

      excepted = params.except(:admin)
      assert_equal 'John', excepted[:user][:name]
      assert_equal 'john@example.com', excepted[:user][:email]
      assert_equal 'Developer', excepted[:user][:profile][:bio]
      assert_nil excepted[:admin]
    end

    def test_slice_with_array_of_parameters
      params = StrongParameters::Core::Parameters.new(
        users: [
          { name: 'John', age: 30 },
          { name: 'Jane', age: 25 }
        ],
        total: 2
      )

      sliced = params.slice(:users)
      assert_equal 'John', sliced[:users][0][:name]
      assert_equal 30, sliced[:users][0][:age]
      assert_equal 'Jane', sliced[:users][1][:name]
      assert_equal 25, sliced[:users][1][:age]
      assert_nil sliced[:total]
    end

    def test_except_with_array_of_parameters
      params = StrongParameters::Core::Parameters.new(
        users: [
          { name: 'John', age: 30 },
          { name: 'Jane', age: 25 }
        ],
        total: 2
      )

      excepted = params.except(:total)
      assert_equal 'John', excepted[:users][0][:name]
      assert_equal 30, excepted[:users][0][:age]
      assert_equal 'Jane', excepted[:users][1][:name]
      assert_equal 25, excepted[:users][1][:age]
      assert_nil excepted[:total]
    end

    def test_slice_preserves_required_key_on_nested
      params = StrongParameters::Core::Parameters.new(
        company: {
          employees: [
            { name: 'Alice' },
            { name: 'Bob' }
          ]
        }
      )

      company = params.require(:company)
      sliced = company.slice(:employees)
      assert_equal :company, sliced.required_key
    end

    def test_except_preserves_required_key
      params = StrongParameters::Core::Parameters.new(user: { name: 'John', email: 'john@example.com', admin: true })
      user_params = params.require(:user)
      excepted = user_params.except(:admin)
      assert_equal :user, excepted.required_key
    end

    def test_slice_with_duplicate_keys
      params = StrongParameters::Core::Parameters.new(name: 'John', age: 30, name_dup: 'Jane')
      sliced = params.slice(:name, :name_dup)
      assert_equal 'John', sliced[:name]
      assert_equal 'Jane', sliced[:name_dup]
    end

    def test_except_with_duplicate_keys
      params = StrongParameters::Core::Parameters.new(name: 'John', age: 30, name_dup: 'Jane')
      excepted = params.except(:age)
      assert_equal 'John', excepted[:name]
      assert_equal 'Jane', excepted[:name_dup]
    end

   def test_dup_with_empty_params
     params = StrongParameters::Core::Parameters.new
     duped = params.dup
     assert_equal({}, duped.to_h)
     assert !duped.permitted?
   end

   def test_dup_independence_after_modification
     duped = @params.dup
     duped[:new_key] = 'new_value'
     duped.delete(:name)
     assert_nil @params[:new_key]
     assert_equal 'John', @params[:name]
   end

  # Test conversion methods
  def test_to_h_returns_hash
    hash = @params.to_h
    assert hash.is_a?(Hash)
  end

  def test_to_h_with_permitted_params
    permitted = @params.permit(:name, :email)
    hash = permitted.to_h
    assert_equal 'John', hash['name']
    assert_equal 'john@example.com', hash['email']
  end

  def test_to_h_converts_nested_parameters
    hash = @params.to_h
    assert hash['profile'].is_a?(Hash)
    assert_equal 'Developer', hash['profile']['bio']
  end

  def test_to_unsafe_h_alias
    assert_equal @params.to_h, @params.to_unsafe_h
  end

   def test_to_hash_alias
     assert_equal @params.to_h, @params.to_hash
   end

   def test_to_h_with_deeply_nested_parameters
     params = StrongParameters::Core::Parameters.new(
       user: {
         profile: {
           settings: {
             theme: 'dark',
             notifications: {
               email: true,
               sms: false
             }
           }
         }
       }
     )
     hash = params.to_h
     assert hash.is_a?(Hash)
     assert_equal 'dark', hash['user']['profile']['settings']['theme']
     assert_equal true, hash['user']['profile']['settings']['notifications']['email']
   end

   def test_to_h_with_arrays_of_parameters
     params = StrongParameters::Core::Parameters.new(
       users: [
         { name: 'John', age: 30 },
         { name: 'Jane', age: 25 }
       ]
     )
     hash = params.to_h
     assert hash['users'].is_a?(Array)
     assert hash['users'][0].is_a?(Hash)
     assert_equal 'John', hash['users'][0]['name']
     assert_equal 25, hash['users'][1]['age']
   end

    def test_to_h_with_mixed_types
      params = StrongParameters::Core::Parameters.new(
        name: 'John',
        age: 30,
        active: true,
        score: 95.5,
        tags: ['ruby', 'rails'],
        metadata: { created_at: Time.now }
      )
      hash = params.to_h
      assert_equal 'John', hash['name']
      assert_equal 30, hash['age']
      assert_equal true, hash['active']
      assert_equal 95.5, hash['score']
      assert_equal ['ruby', 'rails'], hash['tags']
      assert hash['metadata'].is_a?(Hash)
    end

    def test_to_h_with_file_objects
      file = StringIO.new('content')
      params = StrongParameters::Core::Parameters.new(
        name: 'John',
        avatar: file
      )
      hash = params.to_h
      assert_equal 'John', hash['name']
      assert_equal file, hash['avatar']
    end

    def test_to_h_with_big_decimal
      bd = BigDecimal('1.23')
      params = StrongParameters::Core::Parameters.new(price: bd)
      hash = params.to_h
      assert_equal bd, hash['price']
    end

    def test_to_h_with_date_objects
      date = Date.today
      time = Time.now
      datetime = DateTime.now

      params = StrongParameters::Core::Parameters.new(
        birth_date: date,
        created_at: time,
        updated_at: datetime
      )

      hash = params.to_h
      assert_equal date, hash['birth_date']
      assert_equal time, hash['created_at']
      assert_equal datetime, hash['updated_at']
    end

    def test_to_h_with_permitted_nested_parameters
      params = StrongParameters::Core::Parameters.new(
        user: { name: 'John', email: 'john@example.com', admin: true }
      )

      permitted = params.permit(user: [:name, :email])
      hash = permitted.to_h

      assert hash['user'].is_a?(Hash)
      assert_equal 'John', hash['user']['name']
      assert_equal 'john@example.com', hash['user']['email']
      assert_nil hash['user']['admin']
    end

    def test_to_h_with_complex_mixed_structure
      params = StrongParameters::Core::Parameters.new(
        company: {
          name: 'ACME Corp',
          founded: Date.new(2000, 1, 1),
          employees: [
            { name: 'Alice', salary: BigDecimal('50000.00'), active: true },
            { name: 'Bob', salary: BigDecimal('60000.00'), active: false }
          ],
          metadata: {
            industry: 'Tech',
            locations: ['NYC', 'LA', 'London']
          }
        },
        report_generated_at: Time.now
      )

      hash = params.to_h

      assert_equal 'ACME Corp', hash['company']['name']
      assert hash['company']['founded'].is_a?(Date)
      assert hash['company']['employees'].is_a?(Array)
      assert hash['company']['employees'][0].is_a?(Hash)
      assert_equal 'Alice', hash['company']['employees'][0]['name']
      assert hash['company']['employees'][0]['salary'].is_a?(BigDecimal)
      assert_equal true, hash['company']['employees'][0]['active']
      assert_equal 'Tech', hash['company']['metadata']['industry']
      assert_equal ['NYC', 'LA', 'London'], hash['company']['metadata']['locations']
      assert hash['report_generated_at'].is_a?(Time)
    end

    def test_to_h_preserves_array_structure
      params = StrongParameters::Core::Parameters.new(
        matrix: [
          [1, 2, 3],
          [4, 5, 6],
          [7, 8, 9]
        ]
      )

      hash = params.to_h
      assert_equal [[1, 2, 3], [4, 5, 6], [7, 8, 9]], hash['matrix']
    end

    def test_to_h_with_empty_parameters
      params = StrongParameters::Core::Parameters.new
      hash = params.to_h
      assert_equal({}, hash)
    end

   def test_to_unsafe_h_with_permitted_params
     permitted = @params.permit(:name, :email)
     assert_equal permitted.to_h, permitted.to_unsafe_h
   end

   def test_to_h_preserves_key_types
     params = StrongParameters::Core::Parameters.new('name' => 'John', :age => 30)
     hash = params.to_h
     assert_equal 'John', hash['name']
     assert_equal 30, hash['age']
   end

  # Test filtering logic
  def test_permitted_scalar_with_string
    assert @params.send(:permitted_scalar?, 'test')
  end

  def test_permitted_scalar_with_symbol
    assert @params.send(:permitted_scalar?, :test)
  end

  def test_permitted_scalar_with_nil
    assert @params.send(:permitted_scalar?, nil)
  end

  def test_permitted_scalar_with_numeric
    assert @params.send(:permitted_scalar?, 42)
    assert @params.send(:permitted_scalar?, 3.14)
    assert @params.send(:permitted_scalar?, BigDecimal('1.0'))
  end

  def test_permitted_scalar_with_boolean
    assert @params.send(:permitted_scalar?, true)
    assert @params.send(:permitted_scalar?, false)
  end

  def test_permitted_scalar_with_date_time
    assert @params.send(:permitted_scalar?, Date.today)
    assert @params.send(:permitted_scalar?, Time.now)
    assert @params.send(:permitted_scalar?, DateTime.now)
  end

  def test_permitted_scalar_with_file
    file = StringIO.new('content')
    assert @params.send(:permitted_scalar?, file)
    assert @params.send(:permitted_scalar?, File.open('/dev/null'))
  end

  def test_permitted_scalar_with_non_permitted
    assert !@params.send(:permitted_scalar?, [])
    assert !@params.send(:permitted_scalar?, {})
    assert !@params.send(:permitted_scalar?, Object.new)
  end

  def test_array_of_permitted_scalars_with_valid_array
    assert @params.send(:array_of_permitted_scalars?, ['a', 'b', 1, 2])
  end

  def test_array_of_permitted_scalars_with_invalid_array
    assert !@params.send(:array_of_permitted_scalars?, ['a', {}])
  end

  def test_array_of_permitted_scalars_with_non_array
    assert_nil @params.send(:array_of_permitted_scalars?, 'not array')
  end

  # Test private methods
  def test_normalize_key
    params = StrongParameters::Core::Parameters.new
    assert_equal 'test_key', params.send(:normalize_key, :test_key)
    assert_equal 'test_key', params.send(:normalize_key, 'test_key')
  end

  def test_deep_normalize_keys
    params = StrongParameters::Core::Parameters.new
    hash = { 'key1' => 'value1', :key2 => { 'nested' => 'value2' } }
    normalized = params.send(:deep_normalize_keys, hash)
    assert_equal 'value1', normalized['key1']
    assert_equal 'value2', normalized['key2']['nested']
  end

  def test_convert_value_with_hash
    params = StrongParameters::Core::Parameters.new
    hash = { a: 1 }
    converted = params.send(:convert_value, hash)
    assert converted.is_a?(StrongParameters::Core::Parameters)
    assert_equal 1, converted[:a]
  end

  def test_convert_value_with_array
    params = StrongParameters::Core::Parameters.new
    array = [{ a: 1 }, { b: 2 }]
    converted = params.send(:convert_value, array)
    assert converted[0].is_a?(StrongParameters::Core::Parameters)
    assert_equal 1, converted[0][:a]
  end

  def test_wrap_array
    params = StrongParameters::Core::Parameters.new
    assert_equal [1], params.send(:wrap_array, 1)
    assert_equal [1, 2], params.send(:wrap_array, [1, 2])
  end

   def test_fields_for_style?
     params = StrongParameters::Core::Parameters.new
     assert params.send(:fields_for_style?, { '0' => { name: 'John' }, '1' => { name: 'Jane' } })
     assert !params.send(:fields_for_style?, { name: 'John', age: 30 })
   end

   def test_fields_for_style_with_negative_indices
     params = StrongParameters::Core::Parameters.new
     assert params.send(:fields_for_style?, { '-1' => { name: 'John' }, '0' => { name: 'Jane' } })
   end

   def test_fields_for_style_with_non_numeric_keys
     params = StrongParameters::Core::Parameters.new
     assert !params.send(:fields_for_style?, { 'a' => { name: 'John' }, 'b' => { name: 'Jane' } })
   end

   def test_fields_for_style_with_mixed_keys
     params = StrongParameters::Core::Parameters.new
     assert !params.send(:fields_for_style?, { '0' => { name: 'John' }, 'name' => 'Jane' })
   end

   def test_convert_value_with_nil
     params = StrongParameters::Core::Parameters.new
     assert_nil params.send(:convert_value, nil)
   end

   def test_convert_value_with_scalar
     params = StrongParameters::Core::Parameters.new
     assert_equal 'string', params.send(:convert_value, 'string')
     assert_equal 42, params.send(:convert_value, 42)
   end

   def test_convert_value_with_nested_array
     params = StrongParameters::Core::Parameters.new
     array = [{ a: 1 }, { b: 2 }]
     converted = params.send(:convert_value, array)
     assert converted[0].is_a?(StrongParameters::Core::Parameters)
     assert_equal 1, converted[0][:a]
   end

   def test_wrap_array_with_array
     params = StrongParameters::Core::Parameters.new
     assert_equal [1, 2, 3], params.send(:wrap_array, [1, 2, 3])
   end

   def test_wrap_array_with_non_array
     params = StrongParameters::Core::Parameters.new
     assert_equal ['string'], params.send(:wrap_array, 'string')
     assert_equal [42], params.send(:wrap_array, 42)
   end

   def test_unpermitted_keys_excludes_never_unpermitted
     params = StrongParameters::Core::Parameters.new(name: 'John', controller: 'users', action: 'create', admin: true)
     permitted_params = StrongParameters::Core::Parameters.new(name: 'John')
     unpermitted = params.send(:unpermitted_keys, permitted_params)
     assert_equal ['admin'], unpermitted
     assert !unpermitted.include?('controller')
     assert !unpermitted.include?('action')
   end

    def test_unpermitted_keys_with_no_permitted
      params = StrongParameters::Core::Parameters.new(name: 'John', admin: true)
      permitted_params = StrongParameters::Core::Parameters.new
      unpermitted = params.send(:unpermitted_keys, permitted_params)
      assert_equal ['name', 'admin'], unpermitted
    end

    def test_normalize_key_with_various_types
      params = StrongParameters::Core::Parameters.new
      assert_equal '123', params.send(:normalize_key, 123)
      assert_equal 'true', params.send(:normalize_key, true)
      assert_equal 'false', params.send(:normalize_key, false)
      assert_equal '', params.send(:normalize_key, nil)
      assert_equal 'symbol', params.send(:normalize_key, :symbol)
      assert_equal 'string', params.send(:normalize_key, 'string')
    end

    def test_deep_normalize_keys_with_mixed_types
      params = StrongParameters::Core::Parameters.new
      hash = {
        'string' => 'value',
        :symbol => 'value',
        123 => 'value',
        nil => 'value',
        nested: {
          'inner_string' => 'value',
          :inner_symbol => 'value'
        }
      }

      normalized = params.send(:deep_normalize_keys, hash)
      assert_equal 'value', normalized['string']
      assert_equal 'value', normalized['symbol']
      assert_equal 'value', normalized['123']
      assert_equal 'value', normalized['']
      assert_equal 'value', normalized['nested']['inner_string']
      assert_equal 'value', normalized['nested']['inner_symbol']
    end

    def test_convert_value_with_deeply_nested_hash
      params = StrongParameters::Core::Parameters.new
      hash = { a: { b: { c: 'value' } } }
      converted = params.send(:convert_value, hash)

      assert converted.is_a?(StrongParameters::Core::Parameters)
      assert converted[:a].is_a?(StrongParameters::Core::Parameters)
      assert converted[:a][:b].is_a?(StrongParameters::Core::Parameters)
      assert_equal 'value', converted[:a][:b][:c]
    end

    def test_convert_value_with_mixed_array_and_hash
      params = StrongParameters::Core::Parameters.new
      mixed = [
        { name: 'John' },
        'string',
        42,
        { nested: { value: true } }
      ]

      converted = params.send(:convert_value, mixed)
      assert converted[0].is_a?(StrongParameters::Core::Parameters)
      assert_equal 'John', converted[0][:name]
      assert_equal 'string', converted[1]
      assert_equal 42, converted[2]
      assert converted[3].is_a?(StrongParameters::Core::Parameters)
      assert_equal true, converted[3][:nested][:value]
    end

    def test_wrap_array_with_various_inputs
      params = StrongParameters::Core::Parameters.new
      assert_equal [nil], params.send(:wrap_array, nil)
      assert_equal ['string'], params.send(:wrap_array, 'string')
      assert_equal [42], params.send(:wrap_array, 42)
      assert_equal [true], params.send(:wrap_array, true)
      assert_equal [:symbol], params.send(:wrap_array, :symbol)
      assert_equal([1, 2, 3], params.send(:wrap_array, [1, 2, 3]))
    end

    def test_fields_for_style_with_various_patterns
      params = StrongParameters::Core::Parameters.new

      # Valid fields_for patterns
      assert params.send(:fields_for_style?, { '0' => {}, '1' => {} })
      assert params.send(:fields_for_style?, { '-1' => {}, '0' => {}, '1' => {} })
      assert params.send(:fields_for_style?, { '10' => {}, '20' => {} })

      # Invalid patterns
      assert !params.send(:fields_for_style?, { name: 'John' })
      assert !params.send(:fields_for_style?, { '0' => {}, name: 'John' })
      assert !params.send(:fields_for_style?, { 'a' => {}, 'b' => {} })
      assert !params.send(:fields_for_style?, { '0' => 'not_hash' })
      assert !params.send(:fields_for_style?, {})
    end

    def test_unpermitted_keys_with_controller_action
      params = StrongParameters::Core::Parameters.new(
        name: 'John',
        admin: true,
        controller: 'users',
        action: 'create'
      )

      permitted_params = StrongParameters::Core::Parameters.new(name: 'John')
      unpermitted = params.send(:unpermitted_keys, permitted_params)

      assert_equal ['admin'], unpermitted
      assert !unpermitted.include?('controller')
      assert !unpermitted.include?('action')
    end

    def test_validate_metadata_keys_with_empty_metadata
      params_class = Class.new(StrongParameters::Core::ApplicationParams)
      params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
      user_params = params.require(:user)

      # Should not raise
      user_params.send(:validate_metadata_keys!, params_class, [])
    end

    def test_validate_metadata_keys_allows_current_user_always
      params_class = Class.new(StrongParameters::Core::ApplicationParams) do
        def self.metadata_allowed?(key)
          false  # Explicitly disallow everything
        end
      end

      params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
      user_params = params.require(:user)

      # Should not raise because :current_user is always allowed
      user_params.send(:validate_metadata_keys!, params_class, [:current_user])
    end

  # Test unpermitted parameters handling
  def test_unpermitted_parameters_with_log_action
    StrongParameters::Core::Parameters.action_on_unpermitted_parameters = :log
    StrongParameters::Core::Parameters.unpermitted_notification_handler = proc { |keys| @logged_keys = keys }

    params = StrongParameters::Core::Parameters.new(name: 'John', admin: true)
    params.permit(:name)

    assert_equal ['admin'], @logged_keys
  end

  def test_unpermitted_parameters_with_raise_action
    StrongParameters::Core::Parameters.action_on_unpermitted_parameters = :raise

    params = StrongParameters::Core::Parameters.new(name: 'John', admin: true)

    assert_raises(StrongParameters::Core::UnpermittedParameters) do
      params.permit(:name)
    end
  end

   def test_unpermitted_parameters_with_nil_action
     StrongParameters::Core::Parameters.action_on_unpermitted_parameters = nil

     params = StrongParameters::Core::Parameters.new(name: 'John', admin: true)
     permitted = params.permit(:name)

     assert_equal 'John', permitted[:name]
   end

   def test_unpermitted_notification_handler_called_with_correct_keys
     called_with = nil
     StrongParameters::Core::Parameters.action_on_unpermitted_parameters = :log
     StrongParameters::Core::Parameters.unpermitted_notification_handler = proc { |keys| called_with = keys }

     params = StrongParameters::Core::Parameters.new(name: 'John', admin: true, secret: 'hidden')
     params.permit(:name)

     assert_equal ['admin', 'secret'], called_with
   end

   def test_unpermitted_notification_handler_not_called_when_no_unpermitted
     called = false
     StrongParameters::Core::Parameters.action_on_unpermitted_parameters = :log
     StrongParameters::Core::Parameters.unpermitted_notification_handler = proc { called = true }

     params = StrongParameters::Core::Parameters.new(name: 'John')
     params.permit(:name)

     assert !called
   end

   def test_unpermitted_notification_handler_with_nil_handler
     StrongParameters::Core::Parameters.action_on_unpermitted_parameters = :log
     StrongParameters::Core::Parameters.unpermitted_notification_handler = nil

     params = StrongParameters::Core::Parameters.new(name: 'John', admin: true)
     # Should not raise or error
     permitted = params.permit(:name)
     assert_equal 'John', permitted[:name]
   end

   def test_class_attributes_initially_nil
     original_action = StrongParameters::Core::Parameters.action_on_unpermitted_parameters
     original_handler = StrongParameters::Core::Parameters.unpermitted_notification_handler

     begin
       StrongParameters::Core::Parameters.action_on_unpermitted_parameters = nil
       StrongParameters::Core::Parameters.unpermitted_notification_handler = nil

       assert_nil StrongParameters::Core::Parameters.action_on_unpermitted_parameters
       assert_nil StrongParameters::Core::Parameters.unpermitted_notification_handler
     ensure
       StrongParameters::Core::Parameters.action_on_unpermitted_parameters = original_action
       StrongParameters::Core::Parameters.unpermitted_notification_handler = original_handler
     end
   end

   def test_unpermitted_parameters_ignores_controller_and_action
     StrongParameters::Core::Parameters.action_on_unpermitted_parameters = :raise

     params = StrongParameters::Core::Parameters.new(
       name: 'John',
       controller: 'users',
       action: 'create'
     )

     # Should not raise because controller and action are never unpermitted
     permitted = params.permit(:name)
     assert_equal 'John', permitted[:name]
   end

   def test_unpermitted_parameters_with_nested_unpermitted
     StrongParameters::Core::Parameters.action_on_unpermitted_parameters = :raise

     params = StrongParameters::Core::Parameters.new(
       user: {
         name: 'John',
         profile: {
           bio: 'Developer',
           secret: 'hidden'
         }
       },
       admin: true
     )

     assert_raises(StrongParameters::Core::UnpermittedParameters) do
       params.permit(user: [profile: [:bio]])  # secret and admin not permitted
     end
   end

   def test_unpermitted_parameters_log_with_custom_handler
     logged_keys = nil
     StrongParameters::Core::Parameters.action_on_unpermitted_parameters = :log
     StrongParameters::Core::Parameters.unpermitted_notification_handler = proc { |keys| logged_keys = keys }

     params = StrongParameters::Core::Parameters.new(
       name: 'John',
       admin: true,
       controller: 'users',  # Should be ignored
       action: 'create'      # Should be ignored
     )

     permitted = params.permit(:name)
     assert_equal 'John', permitted[:name]
     assert_equal ['admin'], logged_keys
   end

   def test_unpermitted_parameters_with_multiple_unpermitted_keys
     StrongParameters::Core::Parameters.action_on_unpermitted_parameters = :log
     logged_keys = nil
     StrongParameters::Core::Parameters.unpermitted_notification_handler = proc { |keys| logged_keys = keys }

     params = StrongParameters::Core::Parameters.new(
       name: 'John',
       admin: true,
       super_admin: true,
       secret_token: 'abc123'
     )

      permitted = params.permit(:name)
      assert_equal ['admin', 'super_admin', 'secret_token'], logged_keys
   end

   def test_unpermitted_parameters_with_no_unpermitted_keys
     called = false
     StrongParameters::Core::Parameters.action_on_unpermitted_parameters = :log
     StrongParameters::Core::Parameters.unpermitted_notification_handler = proc { called = true }

     params = StrongParameters::Core::Parameters.new(
       name: 'John',
       controller: 'users',
       action: 'create'
     )

     permitted = params.permit(:name, :controller, :action)
     assert_equal 'John', permitted[:name]
     assert !called  # Handler should not be called
   end

   def test_unpermitted_parameters_handler_exception_does_not_prevent_permit
     StrongParameters::Core::Parameters.action_on_unpermitted_parameters = :log
     StrongParameters::Core::Parameters.unpermitted_notification_handler = proc { raise 'Handler error' }

     params = StrongParameters::Core::Parameters.new(name: 'John', admin: true)

     # Even if handler raises, permit should still work
     permitted = params.permit(:name)
     assert_equal 'John', permitted[:name]
   end

   def test_unpermitted_parameters_with_permitted_but_unpermitted_in_nested
     StrongParameters::Core::Parameters.action_on_unpermitted_parameters = :raise

     params = StrongParameters::Core::Parameters.new(
       user: {
         name: 'John',
         emails: [
           { address: 'john@example.com', primary: true },
           { address: 'john@work.com', primary: false, secret: 'hidden' }
         ]
       }
     )

     assert_raises(StrongParameters::Core::UnpermittedParameters) do
       params.permit(user: [emails: [:address, :primary]])  # secret not permitted
     end
   end

  # Test exceptions
  def test_parameter_missing_exception_stores_param
    error = assert_raises(StrongParameters::Core::ParameterMissing) do
      @params.require(:missing)
    end

    assert_equal 'missing', error.param
  end

   def test_unpermitted_parameters_exception_stores_params
     error = StrongParameters::Core::UnpermittedParameters.new(['field1', 'field2'])
     assert_equal ['field1', 'field2'], error.params
   end

   def test_parameter_missing_with_empty_available_keys
     params = StrongParameters::Core::Parameters.new({})
     error = assert_raises(StrongParameters::Core::ParameterMissing) do
       params.require(:missing)
     end
     assert_equal 'missing', error.param
     assert_match(/param is missing or the value is empty: missing/, error.message)
     refute_match(/Available keys:/, error.message)
     refute_match(/Did you mean\?/, error.message)
   end

   def test_parameter_missing_with_numeric_keys
     params = StrongParameters::Core::Parameters.new('0' => 'first', '1' => 'second')
     error = assert_raises(StrongParameters::Core::ParameterMissing) do
       params.require(:missing)
     end
     assert_match(/Available keys: 0, 1/, error.message)
   end

   def test_parameter_missing_with_special_characters_in_keys
     params = StrongParameters::Core::Parameters.new('user-name' => 'John', 'user_name' => 'Jane')
     error = assert_raises(StrongParameters::Core::ParameterMissing) do
       params.require(:user)
     end
     assert_match(/Did you mean\? user-name, user_name/, error.message)
   end

   def test_parameter_missing_find_similar_keys_case_insensitive
     params = StrongParameters::Core::Parameters.new('User' => 'John', 'USER' => 'Jane')
     error = assert_raises(StrongParameters::Core::ParameterMissing) do
       params.require(:user)
     end
     assert_match(/Did you mean\? User, USER/, error.message)
   end

   def test_unpermitted_parameters_with_empty_keys
     error = StrongParameters::Core::UnpermittedParameters.new([])
     assert_equal [], error.params
     assert_equal "found unpermitted parameters: ", error.message
   end

   def test_unpermitted_parameters_with_single_key
      error = StrongParameters::Core::UnpermittedParameters.new(['admin'])
      assert_equal ['admin'], error.params
      assert_equal "found unpermitted parameters: admin", error.message
    end

    def test_parameter_missing_with_no_available_keys
      params = StrongParameters::Core::Parameters.new({})
      error = assert_raises(StrongParameters::Core::ParameterMissing) do
        params.require(:user)
      end

      assert_equal 'user', error.param
      assert_match(/param is missing or the value is empty: user/, error.message)
      refute_match(/Available keys:/, error.message)
      refute_match(/Did you mean\?/, error.message)
    end

    def test_parameter_missing_with_many_available_keys
      params = StrongParameters::Core::Parameters.new(
        usr: 'value',
        user_name: 'value',
        user_email: 'value',
        username: 'value',
        usr_profile: 'value',
        other_key: 'value',
        another_key: 'value'
      )

      error = assert_raises(StrongParameters::Core::ParameterMissing) do
        params.require(:user)
      end

      assert_match(/Available keys: usr, user_name, user_email, username, usr_profile, other_key, another_key/, error.message)
      # Should suggest up to 3 similar keys
      assert_match(/Did you mean\? usr, user_name, user_email/, error.message)
    end

    def test_parameter_missing_with_exact_match_suggestion
      params = StrongParameters::Core::Parameters.new(userr: 'value', usr: 'value')
      error = assert_raises(StrongParameters::Core::ParameterMissing) do
        params.require(:user)
      end

      assert_match(/Did you mean\? userr, usr/, error.message)
    end

    def test_parameter_missing_with_case_insensitive_suggestions
      params = StrongParameters::Core::Parameters.new(User: 'value', USER: 'value', user_name: 'value')
      error = assert_raises(StrongParameters::Core::ParameterMissing) do
        params.require(:user)
      end

      assert_match(/Did you mean\? User, USER, user_name/, error.message)
    end

    def test_parameter_missing_with_numeric_keys_only
      params = StrongParameters::Core::Parameters.new('0' => 'first', '1' => 'second', '2' => 'third')
      error = assert_raises(StrongParameters::Core::ParameterMissing) do
        params.require(:user)
      end

      assert_match(/Available keys: 0, 1, 2/, error.message)
      refute_match(/Did you mean\?/, error.message)  # Numeric keys shouldn't suggest
    end

    def test_parameter_missing_with_mixed_key_types
      params = StrongParameters::Core::Parameters.new(
        'string_key' => 'value',
        :symbol_key => 'value',
        42 => 'value'
      )

      error = assert_raises(StrongParameters::Core::ParameterMissing) do
        params.require(:user)
      end

      # Keys are normalized to strings
      assert_match(/Available keys: string_key, symbol_key, 42/, error.message)
    end

    def test_parameter_missing_with_very_long_key_list
      # Create many keys to test display
      keys = {}
      20.times { |i| keys["key#{i}"] = "value#{i}" }
      params = StrongParameters::Core::Parameters.new(keys)

      error = assert_raises(StrongParameters::Core::ParameterMissing) do
        params.require(:user)
      end

      assert_match(/Available keys: key0, key1, key2, key3, key4, key5, key6, key7, key8, key9, key10, key11, key12, key13, key14, key15, key16, key17, key18, key19/, error.message)
    end

    def test_unpermitted_parameters_with_multiple_keys_sorted
      error = StrongParameters::Core::UnpermittedParameters.new(['zebra', 'alpha', 'beta'])
      assert_equal ['zebra', 'alpha', 'beta'], error.params
      assert_equal "found unpermitted parameters: zebra, alpha, beta", error.message
    end

    def test_unpermitted_parameters_with_special_characters
      error = StrongParameters::Core::UnpermittedParameters.new(['user-name', 'user_name', 'user.name'])
      assert_equal ['user-name', 'user_name', 'user.name'], error.params
      assert_equal "found unpermitted parameters: user-name, user_name, user.name", error.message
    end

  # Test metadata validation
  def test_validate_metadata_keys_with_allowed_keys
    params_class = Class.new(StrongParameters::Core::ApplicationParams) do
      def self.metadata_allowed?(key)
        key == :current_user
      end
    end

    params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
    user_params = params.require(:user)

    # Should not raise
    user_params.send(:validate_metadata_keys!, params_class, [:current_user])
  end

  def test_validate_metadata_keys_with_disallowed_keys
    params_class = Class.new(StrongParameters::Core::ApplicationParams) do
      def self.metadata_allowed?(key)
        false
      end
    end

    params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
    user_params = params.require(:user)

    error = assert_raises(ArgumentError) do
      user_params.send(:validate_metadata_keys!, params_class, [:invalid_key])
    end

    assert_match(/Metadata key\(s\) :invalid_key not allowed/, error.message)
    assert_match(/To fix this, declare them in your params class/, error.message)
  end

  def test_validate_metadata_keys_allows_current_user_implicitly
    params_class = Class.new(StrongParameters::Core::ApplicationParams) do
      def self.metadata_allowed?(key)
        false  # Even if metadata_allowed? returns false for current_user
      end
    end

    params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
    user_params = params.require(:user)

    # Should not raise because :current_user is always allowed
    user_params.send(:validate_metadata_keys!, params_class, [:current_user])
  end

  # Test required_key initialization
  def test_required_key_initially_nil
    params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
    assert_nil params.required_key
  end

  # Test multi-parameter attributes (like Rails date/time selects)
  def test_permit_multi_parameter_attributes
    params = StrongParameters::Core::Parameters.new(
      'birth_date(1i)' => '1990',
      'birth_date(2i)' => '01',
      'birth_date(3i)' => '15'
    )

    permitted = params.permit(:birth_date)
    assert_equal '1990', permitted['birth_date(1i)']
    assert_equal '01', permitted['birth_date(2i)']
    assert_equal '15', permitted['birth_date(3i)']
  end

  # Test fields_for style parameters (numeric keys for arrays)
  def test_permit_fields_for_style_parameters
    params = StrongParameters::Core::Parameters.new(
      '0' => { name: 'John', age: '30' },
      '1' => { name: 'Jane', age: '25' }
    )

    permitted = params.permit('0' => [:name, :age], '1' => [:name, :age])
    assert_equal 'John', permitted['0'][:name]
    assert_equal '30', permitted['0'][:age]
    assert_equal 'Jane', permitted['1'][:name]
    assert_equal '25', permitted['1'][:age]
  end

  # Test edge cases
  def test_permit_with_empty_filters
    permitted = @params.permit
    assert_equal({}, permitted.to_h)
    assert permitted.permitted?
  end

  def test_permit_with_nonexistent_keys
    permitted = @params.permit(:nonexistent)
    assert_equal({}, permitted.to_h)
    assert permitted.permitted?
  end

  def test_require_with_nonexistent_key_in_nested_params
    params = StrongParameters::Core::Parameters.new(user: { profile: { name: 'John' } })
    user_params = params.require(:user)
    profile_params = user_params.require(:profile)

    assert_equal 'John', profile_params[:name]
  end

  def test_require_with_complex_nested_structure
    params = StrongParameters::Core::Parameters.new(
      company: {
        employees: [
          { name: 'Alice', role: 'dev' },
          { name: 'Bob', role: 'qa' }
        ],
        address: {
          street: '123 Main St',
          city: 'NYC'
        }
      }
    )

    company_params = params.require(:company)
    assert company_params.is_a?(StrongParameters::Core::Parameters)

    employees = company_params[:employees]
    assert employees.is_a?(Array)
    assert employees[0].is_a?(StrongParameters::Core::Parameters)
    assert_equal 'Alice', employees[0][:name]

    address = company_params.require(:address)
    assert_equal '123 Main St', address[:street]
  end

  def test_require_preserves_required_key_through_nesting
    params = StrongParameters::Core::Parameters.new(user: { profile: { settings: { theme: 'dark' } } })
    user_params = params.require(:user)
    profile_params = user_params.require(:profile)
    settings_params = profile_params.require(:settings)

    assert_equal :user, user_params.required_key
    assert_equal :user, profile_params.required_key  # Should inherit from parent
    assert_equal :user, settings_params.required_key
  end

   def test_transform_params_with_empty_transformations
     params_class = Class.new(StrongParameters::Core::ApplicationParams) do
       def self.permitted_attributes(action: nil)
         [:name]
       end

       def self.apply_transformations(params, options)
         params
       end
     end

     params = StrongParameters::Core::Parameters.new(user: { name: 'John', extra: 'value' })
     user_params = params.require(:user)
     permitted = user_params.transform_params(params_class)

     assert_equal 'John', permitted[:name]
     assert_nil permitted[:extra]
   end

   def test_transform_params_with_nil_permitted_attributes
     params_class = Class.new(StrongParameters::Core::ApplicationParams) do
       def self.permitted_attributes(action: nil)
         nil
       end
     end

     params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
     user_params = params.require(:user)
     permitted = user_params.transform_params(params_class)

     assert_equal({}, permitted.to_h)
     assert permitted.permitted?
   end

   def test_transform_params_with_empty_permitted_attributes
     params_class = Class.new(StrongParameters::Core::ApplicationParams) do
       def self.permitted_attributes(action: nil)
         []
       end
     end

     params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
     user_params = params.require(:user)
     permitted = user_params.transform_params(params_class)

     assert_equal({}, permitted.to_h)
     assert permitted.permitted?
   end

   def test_transform_params_with_transformation_returning_nil
     params_class = Class.new(StrongParameters::Core::ApplicationParams) do
       def self.permitted_attributes(action: nil)
         [:name]
       end

       def self.apply_transformations(params, options)
         nil
       end
     end

     params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
     user_params = params.require(:user)

     permitted = user_params.transform_params(params_class)
     assert_equal({}, permitted.to_h)
     assert permitted.permitted?
   end

   def test_transform_params_with_transformation_returning_non_hash
     params_class = Class.new(StrongParameters::Core::ApplicationParams) do
       def self.permitted_attributes(action: nil)
         [:name]
       end

       def self.apply_transformations(params, options)
         'not a hash'
       end
     end

     params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
     user_params = params.require(:user)

     assert_raises(TypeError) do
       user_params.transform_params(params_class)
     end
   end

   def test_transform_params_with_additional_attrs_empty
     user_params_class = Class.new(StrongParameters::Core::ApplicationParams) do
       def self.permitted_attributes(action: nil)
         [:name]
       end
     end

     params = StrongParameters::Core::Parameters.new(user: { name: 'John', token: 'abc123' })
     user_params = params.require(:user)
     permitted = user_params.transform_params(user_params_class, additional_attrs: [])

     assert_equal 'John', permitted[:name]
     assert_nil permitted[:token]
   end

    def test_transform_params_with_additional_attrs_overriding
      user_params_class = Class.new(StrongParameters::Core::ApplicationParams) do
        def self.permitted_attributes(action: nil)
          [:name]
        end
      end

      params = StrongParameters::Core::Parameters.new(user: { name: 'John', token: 'abc123' })
      user_params = params.require(:user)
      permitted = user_params.transform_params(user_params_class, additional_attrs: [:name, :token])

      assert_equal 'John', permitted[:name]
      assert_equal 'abc123', permitted[:token]
    end

    def test_transform_params_with_unknown_action
      user_params_class = Class.new(StrongParameters::Core::ApplicationParams) do
        def self.permitted_attributes(action: nil)
          case action
          when :create
            [:name, :email]
          when :update
            [:name]
          else
            []  # Unknown action returns empty
          end
        end
      end

      params = StrongParameters::Core::Parameters.new(user: { name: 'John', email: 'john@example.com' })
      user_params = params.require(:user)
      permitted = user_params.transform_params(user_params_class, action: :unknown)

      assert_equal({}, permitted.to_h)
      assert permitted.permitted?
    end

    def test_transform_params_with_nil_action
      user_params_class = Class.new(StrongParameters::Core::ApplicationParams) do
        def self.permitted_attributes(action: nil)
          if action.nil?
            [:name]
          else
            [:email]
          end
        end
      end

      params = StrongParameters::Core::Parameters.new(user: { name: 'John', email: 'john@example.com' })
      user_params = params.require(:user)

      # With nil action
      permitted_nil = user_params.transform_params(user_params_class, action: nil)
      assert_equal 'John', permitted_nil[:name]
      assert_nil permitted_nil[:email]

      # With unspecified action (defaults to nil)
      permitted_default = user_params.transform_params(user_params_class)
      assert_equal 'John', permitted_default[:name]
      assert_nil permitted_default[:email]
    end

    def test_transform_params_with_complex_transformations
      user_params_class = Class.new(StrongParameters::Core::ApplicationParams) do
        allow :name
        allow :email
        allow :age
        allow :full_name

        def self.apply_transformations(params, options)
          # Normalize email to lowercase
          if params['email']
            params = params.merge('email' => params['email'].downcase)
          end

          # Add computed field
          full_name = "#{params['name']} (#{params['age']})"
          params.merge('full_name' => full_name)
        end
      end

      params = StrongParameters::Core::Parameters.new(user: { name: 'John', email: 'JOHN@EXAMPLE.COM', age: 30, admin: true })
      user_params = params.require(:user)
      permitted = user_params.transform_params(user_params_class)

      assert_equal 'John', permitted[:name]
      assert_equal 'john@example.com', permitted[:email]
      assert_equal 30, permitted[:age]
      assert_equal 'John (30)', permitted[:full_name]
      assert_nil permitted[:admin]
    end

    def test_transform_params_with_transformation_error
      user_params_class = Class.new(StrongParameters::Core::ApplicationParams) do
        def self.permitted_attributes(action: nil)
          [:name]
        end

        def self.apply_transformations(params, options)
          raise StandardError, 'Transformation failed'
        end
      end

      params = StrongParameters::Core::Parameters.new(user: { name: 'John' })
      user_params = params.require(:user)

      assert_raises(StandardError, 'Transformation failed') do
        user_params.transform_params(user_params_class)
      end
    end

    def test_transform_params_with_empty_params_class
      empty_params_class = Class.new(StrongParameters::Core::ApplicationParams) do
        def self.permitted_attributes(action: nil)
          []
        end

        def self.apply_transformations(params, options)
          {}
        end
      end

      params = StrongParameters::Core::Parameters.new(user: { name: 'John', email: 'john@example.com' })
      user_params = params.require(:user)
      permitted = user_params.transform_params(empty_params_class)

      assert_equal({}, permitted.to_h)
      assert permitted.permitted?
    end
end