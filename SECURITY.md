# Security Policy

## Supported Versions

Currently supported versions of Durable Parameters:

| Version | Supported          |
| ------- | ------------------ |
| 1.x     | :white_check_mark: |
| 0.x     | :x:                |

We recommend always using the latest stable version to ensure you have the latest security fixes and improvements.

## Reporting a Vulnerability

**Do not report security vulnerabilities through public GitHub issues.**

Security vulnerabilities should be reported privately to allow for coordinated disclosure and timely fixes. This protects users of the library while issues are being addressed.

### How to Report

Please report security vulnerabilities to:

**Email**: security@durableprogramming.com

### What to Include

When reporting a security vulnerability, please include as much of the following information as possible:

1. **Type of Vulnerability**:
   - Mass assignment bypass
   - Parameter injection
   - Authentication/authorization issue
   - Other (please describe)

2. **Description**:
   - Clear explanation of the vulnerability
   - Why it's a security concern
   - Potential impact

3. **Steps to Reproduce**:
   ```ruby
   # Include minimal code example demonstrating the vulnerability
   params = StrongParameters::Core::Parameters.new(...)
   # Steps that show the security issue
   ```

4. **Impact Assessment**:
   - Who is affected?
   - What can an attacker do?
   - What data or systems are at risk?

5. **Suggested Fix** (if any):
   - Ideas for how to address the vulnerability
   - Proposed code changes

6. **Your Contact Information**:
   - Name (or handle)
   - Email for follow-up questions
   - Whether you'd like public credit when disclosed

### What to Expect

When you report a security vulnerability, here's what you can expect:

1. **Acknowledgment**: Within 48 hours
   - We'll confirm receipt of your report
   - Assign a tracking number if needed

2. **Initial Assessment**: Within 5 business days
   - We'll evaluate the severity and impact
   - Provide our initial assessment
   - May ask clarifying questions

3. **Regular Updates**: Every 3-5 days
   - Status updates on investigation
   - Progress on developing a fix
   - Expected timeline for resolution

4. **Fix Development**: Timeline varies by severity
   - Critical: 1-7 days
   - High: 7-14 days
   - Medium: 14-30 days
   - Low: 30-90 days

5. **Coordinated Disclosure**:
   - We'll work with you on disclosure timing
   - Typically 30-90 days after fix is available
   - We'll credit you in the security advisory (if desired)

6. **Public Advisory**:
   - Published after fix is released
   - Describes the vulnerability and fix
   - Credits reporter (with permission)

## Security Best Practices

When using Durable Parameters in your applications, follow these security best practices:

### 1. Always Require and Permit

**Don't** pass raw params to models:
```ruby
# INSECURE - Don't do this!
User.create(params[:user])
```

**Do** explicitly permit parameters:
```ruby
# SECURE
User.create(params.require(:user).permit(:name, :email))
```

### 2. Use Declarative Params Classes

Centralize and document your parameter permissions:

```ruby
# app/params/user_params.rb
class UserParams < ApplicationParams
  allow :name
  allow :email

  # Explicitly document what's NOT allowed
  deny :is_admin
  deny :role
end

# In controller
User.create(params.require(:user).transform_params)
```

### 3. Configure Unpermitted Parameter Handling

In production, ensure unpermitted parameters trigger alerts:

```ruby
# config/application.rb (Rails)
config.action_controller.action_on_unpermitted_parameters = :raise

# Or for logging
config.action_controller.action_on_unpermitted_parameters = :log
```

### 4. Action-Specific Permissions

Different actions should have different permission levels:

```ruby
class PostParams < ApplicationParams
  allow :title
  allow :body

  # Only allow published flag when creating/updating
  allow :published, only: [:create, :update]

  # Never allow view_count on create
  allow :view_count, except: :create
end
```

### 5. Validate Sensitive Transformations

When using transformations with metadata, ensure proper validation:

```ruby
class UserParams < ApplicationParams
  allow :role

  metadata :current_user  # Always declare metadata

  transform :role do |value, metadata|
    # Ensure only admins can set privileged roles
    if ['admin', 'moderator'].include?(value)
      if metadata[:current_user]&.admin?
        value
      else
        'user'  # Downgrade to safe default
      end
    else
      value
    end
  end
end
```

### 6. Protect All Models

Enable forbidden attributes protection globally:

```ruby
# config/initializers/durable_parameters.rb
ActiveRecord::Base.class_eval do
  include ActiveModel::ForbiddenAttributesProtection
end
```

### 7. Regular Security Audits

- Review params classes regularly for overly permissive settings
- Audit logs for unpermitted parameter attempts
- Keep dependencies up to date
- Run security scanners (bundler-audit, brakeman)

```bash
# Check for vulnerable dependencies
bundle audit check --update

# Run Brakeman security scanner (Rails apps)
brakeman -z
```

### 8. Nested Parameters Security

Be especially careful with nested parameters:

```ruby
# app/params/account_params.rb
class AccountParams < ApplicationParams
  allow :name
  allow :email

  # Explicitly define what's allowed in nested attributes
  allow :addresses, nested: {
    allow: [:street, :city, :zip],
    deny: [:verified]  # Don't let users mark addresses as verified
  }
end
```

### 9. Input Validation

Strong Parameters prevents mass assignment, but you still need input validation:

```ruby
class User < ApplicationRecord
  # Strong Parameters prevents assignment
  # ActiveRecord validations ensure data integrity
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :age, numericality: { only_integer: true, greater_than: 0 }
end
```

### 10. Keep Dependencies Updated

Regularly update Durable Parameters and related gems:

```bash
bundle update durable_parameters
bundle exec rake test  # Verify everything works
```

## Known Security Considerations

### Mass Assignment Protection

Durable Parameters protects against mass assignment attacks by requiring explicit whitelisting. However:

- Protection only works if you actually use `permit()` or `transform_params()`
- `permit!()` disables protection (use with extreme caution)
- Raw hash access bypasses protection

### Parameter Pollution

When multiple parameters have the same name, behavior depends on the server:

```ruby
# URL: /users?role=user&role=admin
params[:role]  # May be "admin" or ["user", "admin"]
```

Always validate parameter types in your application code.

### Nested Attributes

Nested attributes can be complex attack vectors:

```ruby
# Be explicit about what's allowed at each nesting level
params.permit(:name, address: [:street, :city],
              phones: [:number, :type])
```

## Security Audits

### Last Audit

- **Date**: [To be scheduled]
- **Scope**: Full codebase review
- **Tools**: Brakeman, bundler-audit, manual review
- **Results**: [Link to results when available]

### Continuous Monitoring

- **Dependency Scanning**: Automated via GitHub Dependabot
- **Code Scanning**: Automated via GitHub Code Scanning
- **Test Coverage**: Monitored in CI/CD pipeline

## Responsible Disclosure

We believe in responsible disclosure of security vulnerabilities:

1. **Private Notification**: Report to us privately first
2. **Fix Development**: We work on a fix
3. **Coordinated Disclosure**: We agree on disclosure timing
4. **Public Advisory**: We publish details after fix is available
5. **Credit**: We credit reporters who want recognition

This process protects users while ensuring vulnerabilities are properly addressed.

## Security Hall of Fame

We recognize and thank security researchers who help make Durable Parameters more secure:

<!-- Security researchers will be listed here after coordinated disclosure -->

*No vulnerabilities reported yet. Be the first to help secure Durable Parameters!*

## Contact

For security-related questions:

- **Security Issues**: security@durableprogramming.com
- **General Questions**: commercial@durableprogramming.com
- **GitHub Issues**: For non-security bugs only

## Updates to This Policy

This security policy may be updated as needed. Check back regularly for the latest version.

---

**Remember**: Security is everyone's responsibility. If you see something, say something. Thank you for helping keep Durable Parameters and its users secure.
