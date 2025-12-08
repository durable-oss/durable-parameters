# frozen_string_literal: true

require "test_helper"

class VersionTest < Minitest::Test
  def test_version_constant_exists
    assert defined?(DurableParameters::VERSION)
  end

  def test_version_is_string
    assert_kind_of String, DurableParameters::VERSION
  end

  def test_version_format
    # Version should follow semantic versioning: MAJOR.MINOR.PATCH
    assert_match(/\A\d+\.\d+\.\d+\z/, DurableParameters::VERSION)
  end

  def test_version_not_empty
    refute_empty DurableParameters::VERSION
  end

  def test_version_parts
    parts = DurableParameters::VERSION.split(".")
    assert_equal 3, parts.length
    parts.each do |part|
      assert_match(/\A\d+\z/, part)
    end
  end

  def test_version_major_minor_patch
    major, minor, patch = DurableParameters::VERSION.split(".").map(&:to_i)
    assert major >= 0
    assert minor >= 0
    assert patch >= 0
  end

  def test_version_frozen
    assert DurableParameters::VERSION.frozen?
  end

  def test_version_constant_not_nil
    refute_nil DurableParameters::VERSION
  end

  def test_version_matches_gemspec
    gemspec_path = File.expand_path("../../durable-parameters.gemspec", __dir__)
    if File.exist?(gemspec_path)
      gemspec_content = File.read(gemspec_path)
      # Extract version from gemspec
      if gemspec_content =~ /version\s*=\s*["']([^"']+)["']/
        gemspec_version = $1
        assert_equal gemspec_version, DurableParameters::VERSION,
          "VERSION constant should match gemspec version"
      end
    end
  end
end
