module ResourceTable
  class Engine < ::Rails::Engine
    isolate_namespace ResourceTable

    initializer "resource_table.table_helper" do
      ActiveSupport.on_load(:action_view) do
        require "resource_table/helpers/table_helper"
        include ResourceTable::Helpers::TableHelper
      end
    end

    initializer "resource_table.field_types" do
      ResourceTable.register_field_types!
    end
  end
end
