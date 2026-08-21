module ResourceTable
  class Engine < ::Rails::Engine
    isolate_namespace ResourceTable

    # The module is required unconditionally, at boot, not from inside the
    # on_load(:action_view) block below: defining
    # ResourceTable::Helpers::TableHelper has no dependency on ActionView::Base
    # (autoload :Base in action_view.rb — it isn't loaded just because
    # "action_view" is required). A previous version required it from inside
    # the hook, so the constant only came to exist the first time something
    # actually referenced ActionView::Base. In a real request that happens
    # early for unrelated reasons, but Rails::TestUnit::Runner.load_tests
    # requires every test file — including one that does
    # `include ResourceTable::Helpers::TableHelper` in its class body — before
    # any test runs and triggers that reference, so the constant did not exist
    # yet and every such file raised NameError at load time.
    initializer "resource_table.table_helper" do
      require "resource_table/helpers/table_helper"

      ActiveSupport.on_load(:action_view) do
        include ResourceTable::Helpers::TableHelper
      end
    end

    initializer "resource_table.field_types" do
      ResourceTable.register_field_types!
    end
  end
end
