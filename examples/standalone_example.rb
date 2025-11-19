#!/usr/bin/env ruby
# frozen_string_literal: true

# Example of using Strong Parameters without any web framework

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'strong_parameters/core'

# Define a params class for users
class UserParams < StrongParameters::Core::ApplicationParams
  allow :name
  allow :email
  allow :bio
  deny :is_admin  # Explicitly deny admin flag
  deny :role
end

# Register the params class
StrongParameters::Core::ParamsRegistry.register(:user, UserParams)

# Example 1: Basic usage with require and permit
puts "=" * 80
puts "Example 1: Basic parameter filtering"
puts "=" * 80

raw_params = {
  'user' => {
    'name' => 'John Doe',
    'email' => 'john@example.com',
    'bio' => 'Software developer',
    'is_admin' => true,  # This will be filtered out
    'role' => 'admin'     # This will be filtered out
  }
}

params = StrongParameters::Core::Parameters.new(raw_params)
user_params = params.require('user').permit(:name, :email, :bio)

puts "Raw params: #{raw_params.inspect}"
puts "Filtered params: #{user_params.to_h.inspect}"
puts "Permitted? #{user_params.permitted?}"
puts

# Example 2: Using transform_params with a params class
puts "=" * 80
puts "Example 2: Using transform_params with params class"
puts "=" * 80

params2 = StrongParameters::Core::Parameters.new(raw_params)
user_params2 = params2.require('user').transform_params

puts "Raw params: #{raw_params.inspect}"
puts "Filtered params: #{user_params2.to_h.inspect}"
puts "Permitted? #{user_params2.permitted?}"
puts

# Example 3: Nested parameters
puts "=" * 80
puts "Example 3: Nested parameters"
puts "=" * 80

nested_params = {
  'user' => {
    'name' => 'Jane Doe',
    'email' => 'jane@example.com',
    'address' => {
      'street' => '123 Main St',
      'city' => 'Springfield',
      'secret' => 'should be filtered'
    }
  }
}

params3 = StrongParameters::Core::Parameters.new(nested_params)
user_params3 = params3.require('user').permit(:name, :email, address: [:street, :city])

puts "Raw params: #{nested_params.inspect}"
puts "Filtered params: #{user_params3.to_h.inspect}"
puts

# Example 4: Array parameters
puts "=" * 80
puts "Example 4: Array parameters"
puts "=" * 80

array_params = {
  'user' => {
    'name' => 'Bob Smith',
    'email' => 'bob@example.com',
    'tags' => ['ruby', 'rails', 'sinatra']
  }
}

params4 = StrongParameters::Core::Parameters.new(array_params)
user_params4 = params4.require('user').permit(:name, :email, tags: [])

puts "Raw params: #{array_params.inspect}"
puts "Filtered params: #{user_params4.to_h.inspect}"
puts

# Example 5: Error handling
puts "=" * 80
puts "Example 5: Error handling - ParameterMissing"
puts "=" * 80

begin
  params5 = StrongParameters::Core::Parameters.new({})
  params5.require('user')
rescue StrongParameters::Core::ParameterMissing => e
  puts "Caught ParameterMissing exception: #{e.message}"
  puts "Missing param: #{e.param}"
end
puts

# Example 6: ForbiddenAttributes protection
puts "=" * 80
puts "Example 6: ForbiddenAttributes protection"
puts "=" * 80

class SimpleModel
  include StrongParameters::Core::ForbiddenAttributesProtection

  attr_accessor :name, :email

  def initialize(attributes = {})
    assign_attributes(attributes)
  end

  def assign_attributes(attributes)
    attributes = sanitize_for_mass_assignment(attributes)
    @name = attributes['name'] || attributes[:name]
    @email = attributes['email'] || attributes[:email]
  end
end

# This will work - params are permitted
permitted_params = params.require('user').permit(:name, :email)
model1 = SimpleModel.new(permitted_params)
puts "Model created with permitted params: name=#{model1.name}, email=#{model1.email}"

# This will raise ForbiddenAttributes - params are not permitted
begin
  unpermitted_params = StrongParameters::Core::Parameters.new(raw_params['user'])
  model2 = SimpleModel.new(unpermitted_params)
rescue StrongParameters::Core::ForbiddenAttributes => e
  puts "Caught ForbiddenAttributes exception: #{e.message}"
end
puts

puts "=" * 80
puts "All examples completed!"
puts "=" * 80
