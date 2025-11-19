# Base class for all param definitions
# Inherit from this in your app/params/*.rb files to define
# which attributes are permitted for mass assignment
#
# Example:
#   class UserParams < ApplicationParams
#     allow :first_name
#     allow :last_name
#     deny :is_admin
#   end
class ApplicationParams < ActionController::ApplicationParams
  # Add common permitted attributes here
  # For example:
  # allow :created_at
  # allow :updated_at
end
