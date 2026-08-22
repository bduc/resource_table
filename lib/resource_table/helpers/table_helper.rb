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
      #
      # sort_path: the base path _head.html.erb builds sort links against.
      # Without it, _head falls back to url_for(request.query_parameters.merge(...)),
      # which resolves a route from the *current* controller/action + params —
      # ambiguous whenever more than one route maps to the same controller
      # action (e.g. a bare `root "members#index"` declared ahead of
      # `resources :members` makes it flip between "/" and "/leden" as a user
      # alternates sorting and paging). Worse, it is wrong outright when the
      # table is re-rendered inside a turbo_stream response written by some
      # other action — url_for then resolves against *that* action's route
      # (a board-membership delete once produced a 404 sort link). Passing an
      # explicit path sidesteps route resolution entirely.
      #
      # picker: renders the "columns" picker immediately after the table
      # (unchanged, historical placement) when true — the default, so no
      # existing caller silently loses it. Pass false to render the table
      # without it, and call resource_table_picker_for separately to place
      # the picker wherever the host's own layout wants (e.g. a card header,
      # beside a "+" button) instead of directly below the last row.
      #
      # wrapper_class: appended to the scroll wrapper's class list
      # ("overflow-x-auto resource-table-scroll"), never replacing it — a
      # host that needs that box to also scroll vertically inside a bounded
      # parent (mira's /leden) can add e.g. "overflow-y-auto min-h-0" here
      # without every other caller (the board tables) losing the defaults.
      def resource_table_for(collection, resource: nil, presenter: nil, key: nil,
                             layout: nil, table: nil, sort_path: nil, picker: true,
                             wrapper_class: nil, **options, &block)
        resource_class, presenter_class, key, table =
          resolve_table_context(resource: resource, presenter: presenter, key: key, layout: layout, table: table)

        builder = ResourceTable::Builder.new
        block&.call(builder)

        render partial: "resource_table/daisyui/table/table", locals: {
          table: table,
          collection: collection,
          presenter: presenter_class.new(
            view_context: self, blocks: builder.cell_blocks, **options
          ),
          actions: builder.actions_block,
          key: key,
          sort_path: sort_path,
          picker: picker,
          wrapper_class: wrapper_class
        }
      end

      # Renders only the "columns" picker — the ☰ dropdown that toggles which
      # columns of a resource_table are visible — so a host can place it
      # wherever its own layout wants (typically a card header, beside the
      # table's own "+" button) independently of where resource_table_for
      # renders the table. Pair with picker: false on resource_table_for.
      #
      # Resolves resource:/presenter:/key:/layout:/table: exactly as
      # resource_table_for does — both go through the same private
      # #resolve_table_context — so the two agree on the same key and, when
      # the same table: is passed to both, render against the identical
      # Table object.
      #
      # IMPORTANT: called *without* table:, this helper performs its own
      # layout-store read. A caller that also calls resource_table_for for
      # the same collection should build one Table up front and pass that
      # same table: to both, or the picker reads the store a second time for
      # the same request.
      #
      # class: is merged onto the dropdown wrapper's class list in place of
      # the default, and defaults to "dropdown-end" — a picker living at a
      # right edge (a card header) needs its menu right-anchored to the
      # trigger, or it overflows the viewport off the right; a picker placed
      # elsewhere may need a different alignment (see _picker.html.erb).
      def resource_table_picker_for(resource: nil, presenter: nil, key: nil, layout: nil, table: nil, **options)
        _resource_class, _presenter_class, key, table =
          resolve_table_context(resource: resource, presenter: presenter, key: key, layout: layout, table: table)

        render partial: "resource_table/daisyui/table/picker",
               locals: { table: table, key: key }.merge(options)
      end

      private

      # Shared by resource_table_for and resource_table_picker_for: resource:
      # / presenter: / key: / layout: / table: all resolve the same way for
      # both, so this is the one place that resolution lives rather than two
      # copies drifting apart.
      def resolve_table_context(resource:, presenter:, key:, layout:, table:)
        presenter_class = presenter || ResourceTable::Presenter
        resource_class  = resource || presenter_class.resource || table&.resource_class

        unless resource_class
          raise ArgumentError,
                "resource_table_for/resource_table_picker_for needs resource: " \
                "<a ResourceCore::BaseResource subclass>, or a presenter: declaring " \
                "one with `resource MyResource`"
        end

        key ||= ResourceTable.layout_key(resource_class)

        table ||= begin
          layout = resource_table_layout(key) if layout.nil?
          ResourceTable::Table.new(resource_class: resource_class, layout: layout, params: params)
        end

        [ resource_class, presenter_class, key, table ]
      end

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
