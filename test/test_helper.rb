ENV["RAILS_ENV"] = "test"

require_relative "dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [ File.expand_path("dummy/db/migrate", __dir__) ]
require "rails/test_help"

class ActiveSupport::TestCase
  # Registration is global. Without this, a type registered by one test is
  # still there for the next, and tests pass in isolation but not together.
  teardown do
    ResourceCore::Registry.reset!
    ResourceTable.register_field_types!
  end
end
