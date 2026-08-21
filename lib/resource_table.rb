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

    # The layout key for a resource: resource plus view name, so one layout is
    # shared by every page rendering the same table.
    def layout_key(resource_class, view = :index)
      "#{resource_class.name}/#{view}"
    end

    # Whether a key names a resource that actually exists. An unvalidated key
    # lets a request write arbitrary rows into a user's settings table.
    def layout_key_valid?(key)
      return false unless key.is_a?(String)

      resource_name, view = key.split("/", 2)
      return false unless view == "index"
      return false unless resource_name&.match?(/\A[A-Z][A-Za-z0-9]*#{Regexp.escape(ResourceCore.config.resource_class_suffix)}\z/)

      klass = resource_name.safe_constantize
      return false if klass.nil? || !klass.is_a?(Class)
      # Module#<= yields nil for an unrelated class; coerce so the predicate always answers a boolean.
      (klass <= ResourceCore::BaseResource) || false
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
