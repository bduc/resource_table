module ResourceTable
  module Helpers
    module TableHelper
      # Renders a collection as a resizable, reorderable, sortable table.
      #
      #   <%= resource_table_for @members, presenter: MemberTablePresenter do |t| %>
      #     <% t.cell(:niveau) { |r| governable_type_label(r.governable_type) } %>
      #     <% t.actions { |r| link_to "✎", edit_path(r) } %>
      #   <% end %>
      #
      # Anything not consumed here is handed to the presenter as options, which
      # is how a call-site-varying cell (`global_tab`) reaches a cell_ method.
      def resource_table_for(collection, resource: nil, presenter: nil, key: nil,
                             layout: nil, view: :index, **options, &block)
        presenter_class = presenter || ResourceTable::Presenter
        resource_class  = resource || presenter_class.resource

        unless resource_class
          raise ArgumentError,
                "resource_table_for needs resource: <a ResourceCore::BaseResource subclass>, " \
                "or a presenter: declaring one with `resource MyResource`"
        end

        key ||= ResourceTable.layout_key(resource_class, view)
        layout = resource_table_layout(key) if layout.nil?

        builder = ResourceTable::Builder.new
        block&.call(builder)

        table = ResourceTable::Table.new(
          resource_class: resource_class,
          layout: layout,
          params: params
        )

        render partial: "resource_table/daisyui/table/table", locals: {
          table: table,
          collection: collection,
          presenter: presenter_class.new(
            view_context: self, blocks: builder.cell_blocks, **options
          ),
          actions: builder.actions_block,
          key: key
        }
      end

      private

      def resource_table_layout(key)
        store = ResourceTable.layout_store
        return nil unless store

        store.read(resource_table_owner, key)
      end

      def resource_table_owner
        method = ResourceTable.config.owner_method
        respond_to?(method, true) ? send(method) : nil
      end
    end
  end
end
