# Contributing to Durable Parameters

Thank you for your interest in contributing to Durable Parameters! This document provides guidelines for contributing to this project.

## Getting Started

### Development Setup

1. **Fork and Clone**
   ```bash
   git fork https://github.com/durableprogramming/durable_parameters
   cd durable_parameters
   ```

2. **Install Dependencies**
   ```bash
   bundle install
   ```

3. **Run Tests**
   ```bash
   bundle exec rake test
   ```

4. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

### Development Workflow

1. Make your changes
2. Add tests for new functionality
3. Run the full test suite
4. Update documentation (README, YARD comments)
5. Commit with a clear, descriptive message
6. Push to your fork
7. Create a pull request

## Code Standards

### Ruby Style Guide

- Follow standard Ruby style conventions
- Use 2 spaces for indentation (no tabs)
- Keep lines under 100 characters where practical
- Use `snake_case` for methods and variables
- Use `PascalCase` for classes and modules
- Use `SCREAMING_SNAKE_CASE` for constants

### Code Organization

- **Single Responsibility**: Each class/module has one clear purpose
- **Composition over Inheritance**: Prefer mixins and composition
- **Immutable Objects**: Design core objects to be immutable where possible
- **Clear Interfaces**: Define explicit public APIs

### Documentation Standards

- **YARD Format**: Use YARD-compatible documentation comments
- **Complete Coverage**: Document all public methods and classes
- **Usage Examples**: Include practical code examples in documentation
- **Parameter Documentation**: Document all parameters, return values, and exceptions

Example:

```ruby
# Creates a color object from RGB values.
#
# @param r [Numeric] The red component (0.0-1.0 or 0-255)
# @param g [Numeric] The green component (0.0-1.0 or 0-255)
# @param b [Numeric] The blue component (0.0-1.0 or 0-255)
# @param alpha [Float] The alpha component (0.0-1.0), defaults to 1.0
# @return [Color] A new Color object
# @raise [ArgumentError] If parameters are out of valid range
#
# @example Create a red color
#   color = Color.from_rgb(1.0, 0.0, 0.0)
def from_rgb(r, g, b, alpha = 1.0)
  # Implementation
end
```

## Testing Requirements

### Test Coverage

- **Unit Tests**: Test all public methods and complex private methods
- **Integration Tests**: Test component interactions
- **Edge Cases**: Test error conditions and boundary values
- **Coverage Goal**: Maintain >90% code coverage

### Test Structure

```ruby
# test/durable_parameters/core/parameters_test.rb
require "test_helper"

class ParametersTest < Minitest::Test
  def test_initialization_with_valid_parameters
    params = StrongParameters::Core::Parameters.new(name: 'John')
    assert_equal 'John', params[:name]
  end

  def test_require_raises_when_parameter_missing
    params = StrongParameters::Core::Parameters.new({})
    assert_raises(StrongParameters::Core::ParameterMissing) do
      params.require(:user)
    end
  end
end
```

### Running Tests

```bash
# Run all tests
bundle exec rake test

# Run specific test file
bundle exec ruby test/durable_parameters/core/parameters_test.rb

# Run with coverage report
COVERAGE=true bundle exec rake test
```

## Pull Request Process

### Before Submitting

- [ ] All tests pass locally
- [ ] Code follows style guide
- [ ] Documentation is updated (README, YARD, CHANGELOG)
- [ ] No linting errors
- [ ] Commit messages are clear and descriptive

### PR Description

Your pull request description should include:

1. **Summary**: Clear description of what changes were made and why
2. **Related Issues**: Link to related issues (e.g., "Fixes #123")
3. **Breaking Changes**: Highlight any breaking changes
4. **Testing**: Describe how you tested the changes
5. **Screenshots**: Include for UI-related changes (if applicable)

Example:

```markdown
## Summary
Added support for nested array transformations in ApplicationParams.

## Related Issues
Fixes #45

## Changes
- Added `transform_nested` method to ApplicationParams
- Updated documentation with examples
- Added comprehensive test coverage

## Breaking Changes
None

## Testing
- Added unit tests in `test/core/application_params_test.rb`
- Verified with example application
- All existing tests pass
```

### Review Process

1. **Automated Checks**: CI must pass (tests, linting)
2. **Code Review**: Maintainers will review your code
3. **Address Feedback**: Make requested changes
4. **Approval**: At least one maintainer approval required
5. **Merge**: Maintainer will merge when ready

## Code Review Guidelines

### What Reviewers Look For

- **Correctness**: Code works as intended
- **Code Quality**: Clear, maintainable, follows conventions
- **Test Coverage**: Adequate tests for new functionality
- **Documentation**: Complete and accurate documentation
- **Performance**: No obvious performance issues
- **Security**: No security vulnerabilities introduced
- **Breaking Changes**: Properly documented and justified

### Providing Feedback

- Be constructive and respectful
- Explain the "why" behind suggestions
- Offer specific, actionable recommendations
- Recognize good work

### Receiving Feedback

- Feedback is about the code, not you personally
- Ask questions if something is unclear
- Be open to different perspectives
- Thank reviewers for their time

## Reporting Issues

### Bug Reports

When reporting a bug, please include:

1. **Clear Title**: Concise description of the issue
2. **Description**: Detailed explanation of the problem
3. **Steps to Reproduce**:
   ```
   1. Initialize Parameters with...
   2. Call permit with...
   3. Observe error...
   ```
4. **Expected Behavior**: What you expected to happen
5. **Actual Behavior**: What actually happened
6. **Environment**:
   - Ruby version
   - Durable Parameters version
   - Framework (Rails, Sinatra, etc.) and version
   - Operating system
7. **Error Messages**: Full error messages and stack traces
8. **Code Sample**: Minimal reproducible example

### Feature Requests

When requesting a feature, please include:

1. **Use Case**: Describe the problem you're trying to solve
2. **Proposed Solution**: Your idea for how to solve it
3. **Alternatives Considered**: Other approaches you've thought about
4. **Impact**: Who would benefit and how
5. **Implementation Ideas**: Any thoughts on implementation (optional)

## Architecture Overview

Understanding the architecture helps you contribute effectively:

### Core Module (`StrongParameters::Core`)

Framework-agnostic classes:
- **`Parameters`** - Hash-based parameter filtering
- **`ApplicationParams`** - Declarative DSL for permissions
- **`ParamsRegistry`** - Registry for params classes
- **`ForbiddenAttributesProtection`** - Mass assignment protection

### Framework Adapters

Extend core with framework-specific features:
- **Rails** - `StrongParameters::Adapters::Rails`
- **Sinatra** - `StrongParameters::Adapters::Sinatra`
- **Hanami** - `StrongParameters::Adapters::Hanami`
- **Rage** - `StrongParameters::Adapters::Rage`

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture documentation.

## Communication

### Questions?

- **Documentation**: [README.md](README.md) and [ARCHITECTURE.md](ARCHITECTURE.md)
- **Issues**: For bugs and feature requests
- **Email**: commercial@durableprogramming.com

### Code of Conduct

We are committed to providing a welcoming and inclusive environment:

- **Be Respectful**: Treat everyone with respect and kindness
- **Be Constructive**: Provide helpful, actionable feedback
- **Be Professional**: Keep discussions focused and productive
- **Be Inclusive**: Welcome and support people of all backgrounds

## Release Process

Maintainers follow this process for releases:

1. **Version Bump**: Update version in `lib/durable_parameters/version.rb`
2. **Changelog**: Update `CHANGELOG.md` with release notes
3. **Tag**: Create git tag for release
4. **Build**: `gem build durable_parameters.gemspec`
5. **Publish**: `gem push durable_parameters-X.Y.Z.gem`
6. **Announce**: Notify community of release

## License

By contributing to Durable Parameters, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to Durable Parameters! Your contributions help make this project better for everyone.

