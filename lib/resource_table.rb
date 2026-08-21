require "resource_core"
require "resource_table/version"
require "resource_table/configuration"
require "resource_table/engine"

module ResourceTable
  class << self
    def config
      @config ||= Configuration.new
    end

    def configure
      yield config
    end

    def layout_store
      config.layout_store
    end

    # The layout key for a resource: <ResourceName>/index. There is only one
    # view worth keying on today — layout_resource_class below only ever
    # accepts the literal "index" segment — so this takes no view argument.
    # A real second view would mean widening that validator too, not just
    # generating a different string here.
    def layout_key(resource_class)
      "#{resource_class.name}/index"
    end

    # The resource class named by a layout key, or nil if the key does not
    # name one. The single place a key is resolved to a constant — callers
    # that need the class (the controller) and callers that only need a yes/no
    # (layout_key_valid? below) both go through here, so the two cannot drift
    # apart the way two separate resolutions of the same string could.
    def layout_resource_class(key)
      return nil unless key.is_a?(String)

      resource_name, view = key.split("/", 2)
      return nil unless view == "index"
      return nil unless resource_name&.match?(/\A[A-Z][A-Za-z0-9]*#{Regexp.escape(ResourceCore.config.resource_class_suffix)}\z/)

      klass = resource_name.safe_constantize
      return nil if klass.nil? || !klass.is_a?(Class)
      # Module#<= yields nil for an unrelated class; coerce so we always return a Class or nil.
      klass <= ResourceCore::BaseResource ? klass : nil
    end

    # Whether a key names a resource that actually exists. An unvalidated key
    # lets a request write arbitrary rows into a user's settings table.
    def layout_key_valid?(key)
      !layout_resource_class(key).nil?
    end
  end
end

require "resource_table/column"
require "resource_table/sort"
require "resource_table/table"
require "resource_table/builder"
require "resource_table/presenter"
require "resource_table/stores"
require "resource_table/stores/settings_table"
require "resource_table/stores/json_column"
require "resource_table/registration"
