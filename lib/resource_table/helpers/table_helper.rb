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
      #
      # table: lets a caller that already built a Table (typically a
      # controller reading table.sort.order_clause before querying) hand it
      # straight to the view. Without it, that controller's Table and this
      # method's own would be two separate objects — built from two separate
      # layout-store reads — that have to agree on the same request. Passing
      # one in skips both: no second Table is constructed, and the store is
      # never read here.
      def resource_table_for(collection, resource: nil, presenter: nil, key: nil,
                             layout: nil, view: :index, table: nil, **options, &block)
        presenter_class = presenter || ResourceTable::Presenter
        resource_class  = resource || presenter_class.resource || table&.resource_class

        unless resource_class
          raise ArgumentError,
                "resource_table_for needs resource: <a ResourceCore::BaseResource subclass>, " \
                "or a presenter: declaring one with `resource MyResource`"
        end

        key ||= ResourceTable.layout_key(resource_class, view)

        table ||= begin
          layout = resource_table_layout(key) if layout.nil?
          ResourceTable::Table.new(resource_class: resource_class, layout: layout, params: params)
        end

        builder = ResourceTable::Builder.new
        block&.call(builder)

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
