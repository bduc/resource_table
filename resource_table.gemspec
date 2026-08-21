require_relative "lib/resource_table/version"

Gem::Specification.new do |spec|
  spec.name        = "resource_table"
  spec.version     = ResourceTable::VERSION
  spec.authors     = [ "mira" ]
  spec.summary     = "Resizable, reorderable, sortable Rails tables driven by resource_core field specs."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.2"
  spec.files       = Dir["{app,lib}/**/*", "README.md"]

  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "resource_core"
end
