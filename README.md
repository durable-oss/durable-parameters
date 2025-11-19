![Build Status](https://travis-ci.org/durableprogramming/durable_parameters.svg?branch=master)](https://travis-ci.org/durableprogramming/durable_parameters)
[![Gem Version](https://badge.fury.io/rb/durable_parameters.svg)](http://badge.fury.io/rb/durable_parameters)

# Durable Parameters

**A customized and opinionated fork of [strong_parameters](https://github.com/rails/strong_parameters)**

Durable Parameters provides a robust, flexible approach to parameter filtering for Ruby web applications. It prevents mass-assignment vulnerabilities by requiring explicit whitelisting of attributes.

This fork extends the original strong_parameters gem with additional features including declarative params classes, parameter transformations, action-specific permissions, and enhanced framework support.

**Framework Support:**
- **Rails** - Full integration with ActionController and ActiveModel
- **Sinatra** - Lightweight integration for Sinatra applications
- **Hanami** - Support for both Hanami 1.x and 2.x
- **Rage** - Integration with the Rage framework
- **Standalone** - Can be used without any framework

## Key Features

- **Explicit Whitelisting**: Parameters must be explicitly permitted before mass assignment
- **Required Parameters**: Mark parameters as required with automatic 400 Bad Request responses
- **Declarative Params Classes**: Define permitted attributes in reusable, centralized classes
- **Action-Specific Permissions**: Configure different permissions for create, update, etc.
- **Metadata Support**: Pass contextual information (user, IP address, etc.) to params classes
- **Nested Parameters**: Full support for complex nested parameter structures
- **Performance Optimized**: Caching and efficient algorithms for production use

## Installation

Add to your Gemfile:

``` ruby
gem 'durable_parameters'
```

Then run `bundle install`.

## Quick Start

### Rails

``` ruby
class PeopleController < ActionController::Base
  # This will raise an ActiveModel::ForbiddenAttributes exception because it's using mass assignment
  # without an explicit permit step.
  def create
    Person.create(params[:person])
  end

  # This will pass with flying colors as long as there's a person key in the parameters, otherwise
  # it'll raise an ActionController::ParameterMissing exception, which will get caught by
  # ActionController::Base and turned into that 400 Bad Request reply.
  def update
    person = current_account.people.find(params[:id])
    person.update_attributes!(person_params)
    redirect_to person
  end

  private
    # Using a private method to encapsulate the permissible parameters is just a good pattern
    # since you'll be able to reuse the same permit list between create and update. Also, you
    # can specialize this method with per-user checking of permissible attributes.
    def person_params
      params.require(:person).permit(:name, :age)
    end
end
```

### Sinatra

``` ruby
require 'sinatra/base'
require 'strong_parameters/adapters/sinatra'

class MyApp < Sinatra::Base
  register StrongParameters::Adapters::Sinatra

  post '/users' do
    user_params = strong_params.require(:user).permit(:name, :email)
    User.create(user_params.to_h)
    redirect '/users'
  end
end
```

### Hanami (2.x)

``` ruby
require 'strong_parameters/adapters/hanami'

module MyApp
  module Actions
    module Users
      class Create < MyApp::Action
        include StrongParameters::Adapters::Hanami::Action

        def handle(request, response)
          user_params = strong_params(request.params).require(:user).permit(:name, :email)
          # ... use user_params
        end
      end
    end
  end
end
```

### Hanami (1.x)

``` ruby
require 'strong_parameters/adapters/hanami'

module Web
  module Controllers
    module Users
      class Create
        include Web::Action
        include StrongParameters::Adapters::Hanami::Action

        def call(params)
          user_params = strong_params.require(:user).permit(:name, :email)
          # ... use user_params
        end
      end
    end
  end
end
```

### Rage

``` ruby
require 'strong_parameters/adapters/rage'

class UsersController < RageController::API
  def create
    user_params = params.require(:user).permit(:name, :email)
    User.create(user_params.to_h)
    render json: { success: true }
  end
end
```

### Standalone (No Framework)

``` ruby
require 'strong_parameters/core'

# Use the core Parameters class directly
raw_params = { user: { name: 'John', email: 'john@example.com', admin: true } }
params = StrongParameters::Core::Parameters.new(raw_params)

# Require and permit parameters
user_params = params.require(:user).permit(:name, :email)
# => {"name"=>"John", "email"=>"john@example.com"}

# The :admin parameter was filtered out
```

## Permitted Scalar Values

Given

``` ruby
params.permit(:id)
```

the key `:id` will pass the whitelisting if it appears in `params` and it has a permitted scalar value associated. Otherwise the key is going to be filtered out, so arrays, hashes, or any other objects cannot be injected.

The permitted scalar types are `String`, `Symbol`, `NilClass`, `Numeric`, `TrueClass`, `FalseClass`, `Date`, `Time`, `DateTime`, `StringIO`, `IO`, `ActionDispatch::Http::UploadedFile` and `Rack::Test::UploadedFile`.

To declare that the value in `params` must be an array of permitted scalar values map the key to an empty array:

``` ruby
params.permit(:id => [])
```

To whitelist an entire hash of parameters, the `permit!` method can be used

``` ruby
params.require(:log_entry).permit!
```

This will mark the `:log_entry` parameters hash and any subhash of it permitted.  Extreme care should be taken when using `permit!` as it will allow all current and future model attributes to be mass-assigned.

## Nested Parameters

You can also use permit on nested parameters, like:

``` ruby
params.permit(:name, {:emails => []}, :friends => [ :name, { :family => [ :name ], :hobbies => [] }])
```

This declaration whitelists the `name`, `emails` and `friends` attributes. It is expected that `emails` will be an array of permitted scalar values and that `friends` will be an array of resources with specific attributes : they should have a `name` attribute (any permitted scalar values allowed), a `hobbies` attribute as an array of permitted scalar values, and a `family` attribute which is restricted to having a `name` (any permitted scalar values allowed, too).

Thanks to Nick Kallen for the permit idea!

## Require Multiple Parameters

If you want to make sure that multiple keys are present in a params hash, you can call the method twice:

``` ruby
params.require(:token)
params.require(:post).permit(:title)
```

## Handling of Unpermitted Keys

By default parameter keys that are not explicitly permitted will be logged in the development and test environment. In other environments these parameters will simply be filtered out and ignored.

Additionally, this behaviour can be changed by changing the `config.action_controller.action_on_unpermitted_parameters` property in your environment files. If set to `:log` the unpermitted attributes will be logged, if set to `:raise` an exception will be raised.

## Use Outside of Controllers

While Strong Parameters will enforce permitted and required values in your application controllers, keep in mind
that you will need to sanitize untrusted data used for mass assignment when in use outside of controllers.

For example, if you retrieve JSON data from a third party API call and pass the unchecked parsed result on to
`Model.create`, undesired mass assignments could take place.  You can alleviate this risk by slicing the hash data,
or wrapping the data in a new instance of `ActionController::Parameters` and declaring permissions the same as
you would in a controller.  For example:

``` ruby
raw_parameters = { :email => "john@example.com", :name => "John", :admin => true }
parameters = ActionController::Parameters.new(raw_parameters)
user = User.create(parameters.permit(:name, :email))
```

## Declarative Parameter Permissions with `app/params/`

This enhanced version of Strong Parameters adds a powerful declarative DSL for defining parameter permissions. Instead of inline `permit()` calls scattered throughout your controllers, you can centralize permission logic in reusable params classes.

### Why Use Declarative Params?

**Before (repetitive and error-prone):**
``` ruby
class UsersController < ApplicationController
  def create
    user = User.create(params.require(:user).permit(:name, :email, :bio))
    # ...
  end

  def update
    user = User.find(params[:id])
    user.update_attributes!(params.require(:user).permit(:name, :email, :bio))
    # ...
  end
end
```

**After (DRY and maintainable):**
``` ruby
# app/params/user_params.rb
class UserParams < ApplicationParams
  allow :name
  allow :email
  allow :bio
  deny :is_admin  # Explicitly document what's not allowed
end

# app/controllers/users_controller.rb
class UsersController < ApplicationController
  def create
    user = User.create(params.require(:user).transform_params)
    # ...
  end

  def update
    user = User.find(params[:id])
    user.update_attributes!(params.require(:user).transform_params)
    # ...
  end
end
```

### Basic Usage

**Step 1:** Create a params class in `app/params/account_params.rb`:

``` ruby
class AccountParams < ApplicationParams
  # Explicitly allow attributes
  allow :first_name
  allow :last_name
  allow :email

  # Explicitly deny sensitive attributes (optional but recommended for documentation)
  deny :is_admin
  deny :role
end
```

**Step 2:** Use `transform_params` in your controller:

``` ruby
class AccountsController < ApplicationController
  def update
    account = Account.find(params[:id])
    # Automatically infers AccountParams from :account key
    # Permits: :first_name, :last_name, :email
    # Denies: :is_admin, :role, and any other attributes
    account.update_attributes!(params.require(:account).transform_params)
    redirect_to account
  end
end
```

### Multiple Params Classes

You can define multiple params classes for different use cases:

``` ruby
# app/params/account_params.rb
class AccountParams < ApplicationParams
  allow :first_name
  allow :last_name
  allow :email
end

# app/params/admin_account_params.rb
class AdminAccountParams < ApplicationParams
  allow :first_name
  allow :last_name
  allow :email
  allow :is_admin  # Admins can modify admin status
  allow :role
end
```

Then explicitly specify which to use:

``` ruby
class AccountsController < ApplicationController
  def update
    account = Account.find(params[:id])

    # Regular users use AccountParams
    if current_user.admin?
      account.update_attributes!(params.require(:account).transform_params(AdminAccountParams))
    else
      account.update_attributes!(params.require(:account).transform_params)
    end

    redirect_to account
  end
end
```

### Passing Metadata for Transformation

`transform_params` accepts metadata that can be used by custom params classes for advanced transformation logic. This enables context-aware parameter processing.

#### Current User

`current_user` is always accepted and doesn't need to be declared:

``` ruby
class AccountsController < ApplicationController
  def update
    account = Account.find(params[:id])
    # current_user is always allowed
    account.update_attributes!(
      params.require(:account).transform_params(current_user: current_user)
    )
    redirect_to account
  end
end
```

#### Declaring Additional Metadata

To pass other metadata keys, you must explicitly declare them in your params class using the `metadata` DSL:

``` ruby
class AccountParams < ApplicationParams
  allow :first_name
  allow :last_name
  allow :email

  # Declare which metadata keys this params class accepts
  metadata :ip_address, :role
end
```

Now you can pass these declared metadata keys:

``` ruby
class AccountsController < ApplicationController
  def update
    account = Account.find(params[:id])
    account.update_attributes!(
      params.require(:account).transform_params(
        current_user: current_user,  # Always allowed
        ip_address: request.ip,       # Must be declared
        role: current_user.role       # Must be declared
      )
    )
    redirect_to account
  end
end
```

**Important:** If you try to pass metadata that hasn't been declared, `transform_params` will raise an `ArgumentError` with a helpful message telling you which metadata key to declare.

**Note:** Metadata is validated and can be used by transformations for dynamic parameter processing.

### Parameter Transformations

You can define transformations that modify parameter values before they are filtered. Transformations receive the current value and metadata (like `current_user`, `action`, etc.), allowing for context-aware processing:

``` ruby
class UserParams < ApplicationParams
  allow :email
  allow :role
  allow :username

  metadata :current_user  # Declare metadata that transformations can access

  # Normalize email to lowercase
  transform :email do |value, metadata|
    value&.downcase&.strip
  end

  # Enforce role based on current user's permissions
  transform :role do |value, metadata|
    if metadata[:current_user]&.admin?
      value  # Admins can set any role
    else
      'user'  # Non-admins always get 'user' role
    end
  end

  # Sanitize username
  transform :username do |value, metadata|
    value&.strip&.gsub(/\s+/, '_')
  end
end
```

Using transformations in your controller:

``` ruby
class UsersController < ApplicationController
  def create
    user = User.create(
      params.require(:user).transform_params(current_user: current_user)
    )
    redirect_to user
  end
end
```

**How it works:**
1. Transformations are applied first, modifying parameter values
2. Then filtering occurs based on allowed/denied attributes
3. Action-specific permissions are respected
4. Metadata must be declared (except `current_user` which is always allowed)

### Action-Specific Permissions

Different actions often need different permissions. For example, you might want to allow setting a `published` flag only when creating or updating, but not when doing other operations. Use `:only` and `:except` options for fine-grained control:

``` ruby
class PostParams < ApplicationParams
  # Always allowed
  allow :title
  allow :body

  # Only allowed for create and update actions
  allow :published, only: [:create, :update]

  # Allowed for all actions except create
  allow :view_count, except: :create

  # Only allowed for a single action
  allow :featured, only: :publish
end
```

Specify the action in your controller:

``` ruby
class PostsController < ApplicationController
  def create
    # Permits: :title, :body, :published
    # Denies: :view_count (except: :create)
    post = Post.create(params.require(:post).transform_params(action: :create))
    redirect_to post
  end

  def update
    post = Post.find(params[:id])
    # Permits: :title, :body, :published, :view_count
    post.update_attributes!(params.require(:post).transform_params(action: :update))
    redirect_to post
  end

  def publish
    post = Post.find(params[:id])
    # Permits: :title, :body, :view_count, :featured
    # Denies: :published (not in only: :publish)
    post.update_attributes!(params.require(:post).transform_params(action: :publish))
    redirect_to post
  end
end
```

**Benefits:**
- Single source of truth for all action permissions
- Clear documentation of what's allowed where
- Prevents accidental exposure of sensitive fields in specific contexts

### Flags

You can set custom flags on your params classes for application-specific logic:

``` ruby
class AccountParams < ApplicationParams
  allow :name
  allow :description

  flag :require_approval, true
  flag :audit_changes, true
end
```

Check flags programmatically:

``` ruby
AccountParams.flag?(:require_approval) # => true
```

### Additional Attributes

You can permit additional attributes beyond those defined in the params class:

``` ruby
# In your controller
params.require(:user).transform_params(additional_attrs: [:temporary_token])
```

### Inheritance

Params classes support inheritance, allowing you to build on existing definitions:

``` ruby
class ApplicationParams < ActionController::ApplicationParams
  # Common attributes for all models
  allow :created_at
  allow :updated_at
end

class UserParams < ApplicationParams
  # Inherits :created_at and :updated_at
  allow :name
  allow :email
end
```

### Checking Permissions

You can query the params classes directly to check permissions:

``` ruby
UserParams.allowed?(:email)      # => true
UserParams.denied?(:is_admin)    # => true
UserParams.permitted_attributes  # => [:name, :email, :created_at, :updated_at]
```

### Registry

All params classes are automatically registered and can be looked up:

``` ruby
ActionController::ParamsRegistry.lookup(:user)  # => UserParams
ActionController::ParamsRegistry.registered?(:user)  # => true
ActionController::ParamsRegistry.permitted_attributes_for(:user)  # => [:name, :email, ...]
```

## Architecture

This gem is built with a modular architecture that separates core functionality from framework-specific integrations:

### Core Module (`StrongParameters::Core`)

The core module provides framework-agnostic classes:
- **`Parameters`** - Hash-based parameter filtering and whitelisting
- **`ApplicationParams`** - Declarative DSL for defining parameter permissions
- **`ParamsRegistry`** - Registry for looking up params classes
- **`ForbiddenAttributesProtection`** - Mass assignment protection

The core has zero dependencies and can be used standalone.

### Framework Adapters

Each adapter extends the core with framework-specific features:

- **Rails Adapter** (`StrongParameters::Adapters::Rails`)
  - Integrates with ActionController and ActiveModel
  - Provides HashWithIndifferentAccess behavior
  - Supports uploaded files (ActionDispatch, Rack)
  - Auto-loads params classes from `app/params/`

- **Sinatra Adapter** (`StrongParameters::Adapters::Sinatra`)
  - Provides `strong_params` helper method
  - Automatic error handling (400 Bad Request)
  - Logging support in development mode

- **Hanami Adapter** (`StrongParameters::Adapters::Hanami`)
  - Supports both Hanami 1.x and 2.x
  - Provides `strong_params` helper for actions
  - Integrates with Hanami's error handling

- **Rage Adapter** (`StrongParameters::Adapters::Rage`)
  - Rails-compatible API for Rage framework
  - Automatic controller integration
  - Error handling via `rescue_from`


Note that these adapters are still WIP, so please open a bug report with any bugs you find.

### Auto-Detection

The gem automatically detects which framework is loaded and activates the appropriate adapter. You can also manually require specific adapters.

## More Examples

Head over to the [Rails guide about Action Controller](http://guides.rubyonrails.org/action_controller_overview.html#more-examples).

## Framework-Specific Setup

### Rails Setup

To activate strong parameters protection in Rails models:

``` ruby
class Post < ActiveRecord::Base
  include ActiveModel::ForbiddenAttributesProtection
end
```

Alternatively, protect all Active Record resources globally in an initializer:

``` ruby
# config/initializers/durable_parameters.rb
ActiveRecord::Base.send(:include, ActiveModel::ForbiddenAttributesProtection)
```

For Rails 3.2, disable the default whitelisting in `config/application.rb`:

``` ruby
config.active_record.whitelist_attributes = false
```

This allows you to remove `attr_accessible` and use strong parameters throughout your code.

### Sinatra Setup

Automatic setup when you register the adapter:

``` ruby
class MyApp < Sinatra::Base
  register StrongParameters::Adapters::Sinatra
end
```

Or include in Sinatra classic style:

``` ruby
require 'sinatra'
require 'strong_parameters/adapters/sinatra'
```

### Hanami Setup

Setup is automatic when you include the Action module:

``` ruby
# Hanami 2.x - include in your actions
include StrongParameters::Adapters::Hanami::Action

# Or setup globally in config/app.rb
StrongParameters::Adapters::Hanami.setup!(Hanami.app)
```

### Rage Setup

Setup happens automatically when the adapter is loaded:

``` ruby
require 'strong_parameters/adapters/rage'
# Controllers will automatically have strong parameters support
```

### Standalone Setup

No setup required - just use the core classes:

``` ruby
require 'strong_parameters/core'

# Define params classes
class UserParams < StrongParameters::Core::ApplicationParams
  allow :name
  allow :email
end

# Register params classes
StrongParameters::Core::ParamsRegistry.register(:user, UserParams)

# Use parameters
params = StrongParameters::Core::Parameters.new(raw_hash)
```

## Migration Path to Rails 4

In order to have an idiomatic Rails 4 application, Rails 3 applications may
use this gem to introduce strong parameters in preparation for their upgrade.

The following is a way to do that gradually:

### 1 Depend on `durable_parameters`

Add this gem to the application `Gemfile`:

``` ruby
gem 'durable_parameters'
```

and run `bundle install`.

After this change, the `params` object in requests is of type
`ActionController::Parameters`. That is a subclass of
`ActiveSupport::HashWithIndifferentAccess` and therefore everything should
work as before. The test suite should be green, and the application can be
deployed.

### 2 Compute a Topological Sort of Active Record Models

We are going to work model by model, and the natural order to do that
systematically is topological. That is, if post has many comments, first you
do `Post`, and later you do `Comment`.

Reason is that order plays well with nested attributes. You can mass-assign
`ActionController::Parameters` to `Post`, and if that includes
`comments_attributes` and the `Comment` model is not yet done, it will work.
But if `Comment` is done first, then the mass-assigning to `Post` won't permit
its attributes and won't work.

This script prints a topological sort of the Active Record models to standard
output:

```ruby
require 'tsort'
require 'set'

class Graph < Hash
  include TSort

  alias tsort_each_node each_key

  def tsort_each_child(node, &block)
    fetch(node).each(&block)
  end
end

def children(model)
  Set.new.tap do |children|
    model.reflect_on_all_associations.each do |association|
      next unless [:has_many, :has_one].include?(association.macro)
      next if association.options[:through]

      children << association.klass
    end
  end
end

Dir.glob('app/models/**/*.rb') do |model|
  load model
end

graph = Graph.new
ActiveRecord::Base.descendants.each do |model|
  graph[model] = children(model) unless model.abstract_class?
end

graph.tsort.reverse_each do |klass|
  puts klass.name
end
```

Execute it with `rails runner`.

### 3 Protect Every Active Record Model, One at a Time

Once the dependency is in place and the topological listing computed, you can
work model by model. Do one model, deploy. Do another model, deploy. Etc.

For each model:

#### 3.1 Add Protection

Remove any `attr_accessible` or `attr_protected` declarations and include
`ActiveModel::ForbiddenAttributesProtection`:

``` ruby
class Post < ActiveRecord::Base
  include ActiveModel::ForbiddenAttributesProtection
end
```

#### 3.2 (Optional) Check the Suite is Red

If the application performs any mass-assignment into that model, the test
suite should not pass. Expect the test suite to raise
`ActiveModel::ForbiddenAttributes` in those spots.

If the test suite is green, either it lacks coverage (fix it), or there is no
mass-assignment going on (ready to deploy).

#### 3.3 Whitelisting

Go to every controller whose actions trigger mass-assignment on that model via
`params` and sanitize the input data using `require` and `permit`, as
explained above.

#### 3.4 Deploy

Once everything is whitelisted and the suite is green, this particular model
can be pushed.

Ready to work on the next model.

### 4 Add Protection Globally

Once all models are done, remove their inclusion of the protecting module:

``` ruby
class Post < ActiveRecord::Base
  # REMOVE THIS LINE IN EVERY PERSISTENT MODEL
  include ActiveModel::ForbiddenAttributesProtection
end
```

and add it globally in an initializer:

``` ruby
# config/initializers/durable_parameters.rb
ActiveRecord::Base.class_eval do
  include ActiveModel::ForbiddenAttributesProtection
end
```

