require "bundler/setup"

APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)
load "rails/tasks/engine.rake"

require "bundler/gem_tasks"

# `test/` exists as a directory, which shadows an unqualified `test` task
# with a no-op file task unless one is defined explicitly. `app:test` (from
# rails/tasks/engine.rake, loaded above) is the real test runner.
task test: "app:test"

# rails/tasks/engine.rake exposes most db:* tasks at the top level (each one
# delegating to the namespaced app:db:* task it wraps), but not db:prepare.
# CI calls `bin/rails db:prepare`, which without this falls through to Rake
# and finds nothing, since only app:db:prepare exists.
namespace :db do
  task prepare: [ :load_app, "app:db:prepare" ]
end
