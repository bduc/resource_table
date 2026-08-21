require "test_helper"

class RenderingTest < ActionView::TestCase
  # _head.html.erb builds a sort link with
  # url_for(request.query_parameters.merge(sort:, dir:, page:)) — no
  # :controller/:action in that hash. On a real index page url_for recalls
  # both from the current request's path_parameters for free; here there is
  # no real request, so this stands in for "rendered from some index
  # action" the way every other test in this file implicitly assumes.
  setup do
    request.path_parameters = { controller: "books", action: "index" }
  end

  # Named so it resolves no real model: BaseResource#fields only auto-detects
  # columns/associations when .model_class resolves (see table_test.rb's
  # "resource" helper for the same reasoning). Naming this "BookResource"
  # would auto-detect Book's whole schema — every column and association,
  # not just the four fields below — and every test that assumes column 0 is
  # "title" or that the colgroup has exactly as many <col>s as declared
  # fields would silently start exercising a much bigger table than the one
  # it declares.
  def resource
    @resource ||= Class.new(ResourceCore::BaseResource) do
      def self.name = "StubResource"
      field :title,    index: { sortable: true, width: 200 }
      field :pages,    index: { align: :right }
      field :synopsis, index: { flex: true }
      field :isbn,     index: { default: false }
    end
  end

  def render_table(params: {}, layout: nil, actions: nil, blocks: {})
    table = ResourceTable::Table.new(resource_class: resource, layout: layout, params: params)
    render partial: "resource_table/daisyui/table/table", locals: {
      table: table,
      collection: [ Book.new(title: "Dune", pages: 412, synopsis: "Sand.") ],
      presenter: ResourceTable::Presenter.new(view_context: view, blocks: blocks),
      actions: actions,
      key: "BookResource/index"
    }
  end

  test "the wrapper carries the controller and its values" do
    render_table
    wrapper = css_select("[data-controller='table-layout']").first

    assert wrapper, "the scroll wrapper must carry data-controller"
    assert_equal "BookResource/index", wrapper["data-table-layout-key-value"]
    assert wrapper["data-table-layout-url-value"].present?
  end

  test "the colgroup mirrors the header row one for one" do
    render_table
    cols = css_select("colgroup col")
    ths  = css_select("thead tr th")

    assert_equal ths.size, cols.size,
                 "colFor indexes into the full header children — a mismatch mis-maps every resize"
  end

  test "the colgroup mirrors the header row one for one when an actions column is present" do
    # Both parity tests above ran the no-actions path, so a dropped actions
    # <col> stayed green — exactly the mismatch colFor's own comment warns
    # about, since it indexes into the full header row by position.
    render_table(actions: ->(b) { "edit #{b.title}" })
    cols = css_select("colgroup col")
    ths  = css_select("thead tr th")

    assert_equal ths.size, cols.size
    assert_equal "col-row-actions", cols.last["class"].to_s
  end

  test "a data column carries data-column, a grip and a resizer" do
    render_table
    th = css_select("thead th[data-column='title']").first

    assert th
    assert_equal 1, css_select("thead th[data-column='title'] .th-grip[data-table-layout-target='handle']").size
    # Not just the attribute's presence: onResizeStart reads handle.dataset.column,
    # and colFor(undefined) happens to match the spacer <th> (the only other
    # element whose dataset.column is also undefined) — so a missing *value*
    # is exactly as broken as a missing attribute, and only asserting presence
    # would miss it.
    assert_equal 1,
      css_select("thead th[data-column='title'] .th-resizer[data-table-layout-target='resizer'][data-column='title']").size
  end

  test "the header row is the headerRow target" do
    render_table

    assert_equal 1, css_select("thead tr[data-table-layout-target='headerRow']").size
  end

  test "the dummy spacer is always present, flex, and carries no data-column" do
    render_table
    spacer = css_select("thead th.col-flex-spacer").first

    assert spacer, "the slack absorber must always be rendered"
    assert spacer.attributes.key?("data-flex")
    refute spacer.attributes.key?("data-column"),
           "a spacer with data-column would be draggable and resizable"
  end

  test "the spacer starts zero-width while a flex data column is filling" do
    render_table
    spacer_col = css_select("colgroup col.col-flex-spacer").first

    assert_match(/width:\s*0/, spacer_col["style"].to_s)
  end

  test "a declared width renders on the col, an undeclared one autosizes" do
    render_table

    assert_match(/width:\s*200px/, css_select("colgroup col")[0]["style"].to_s)
    assert css_select("thead th[data-column='pages']").first.attributes.key?("data-autosize")
    refute css_select("thead th[data-column='title']").first.attributes.key?("data-autosize")
  end

  test "the flex column is flagged and unsized" do
    render_table
    th = css_select("thead th[data-column='synopsis']").first

    assert th.attributes.key?("data-flex")
    refute th.attributes.key?("data-autosize"), "the slack absorber must not be measured"
  end

  test "a sortable header is a link, an unsortable one is not" do
    render_table

    assert_equal 1, css_select("thead th[data-column='title'] a").size
    assert_equal 0, css_select("thead th[data-column='pages'] a").size
  end

  test "the sort link carries the column and the next direction" do
    render_table(params: { "sort" => "title", "dir" => "asc" })
    href = css_select("thead th[data-column='title'] a").first["href"]

    assert_includes href, "sort=title"
    assert_includes href, "dir=desc"
  end

  test "the sort link preserves every other filter and resets the page to 1" do
    # A user on /leden?q=jansen&status=active&page=4 who clicks a sort header
    # must land on a *filtered* list at page 1 — _head.html.erb builds the
    # href from request.query_parameters, not from Table's own params.
    request.query_string = "q=jansen&status=active&page=4"

    render_table(params: { "sort" => "title", "dir" => "asc" })
    href = css_select("thead th[data-column='title'] a").first["href"]

    assert_includes href, "q=jansen"
    assert_includes href, "status=active"
    assert_includes href, "page=1"
    refute_includes href, "page=4"
  end

  test "cells render through the presenter" do
    render_table

    assert_includes css_select("tbody td")[0].text, "Dune"
  end

  test "a block override reaches the cell" do
    render_table(blocks: { title: ->(b) { "blocked #{b.title}" } })

    assert_includes rendered, "blocked Dune"
  end

  test "an actions column renders last, outside the layout system" do
    render_table(actions: ->(b) { "edit #{b.title}" })
    ths = css_select("thead tr th")

    assert_equal "col-row-actions", ths.last["class"].to_s.split.last
    refute ths.last.attributes.key?("data-column")
    assert_includes rendered, "edit Dune"
  end

  test "with no actions block there is no actions column" do
    render_table

    assert_equal 0, css_select("th.col-row-actions").size
    assert_equal css_select("thead tr th").size, css_select("colgroup col").size
  end

  test "each body row has as many <td>s as the header row has <th>s (no actions)" do
    # fitWidth indexes body cells by header index (tr.children[idx]); a
    # missing spacer <td> makes double-click autofit measure a neighbouring
    # column's content instead of its own.
    render_table
    ths = css_select("thead tr th")
    tds = css_select("tbody tr td")

    assert_equal ths.size, tds.size
  end

  test "each body row has as many <td>s as the header row has <th>s (with actions)" do
    render_table(actions: ->(b) { "edit #{b.title}" })
    ths = css_select("thead tr th")
    tds = css_select("tbody tr td")

    assert_equal ths.size, tds.size
  end

  test "alignment comes from the index spec" do
    render_table

    assert_includes css_select("tbody td")[1]["class"].to_s, "text-right"
  end

  test "the picker offers every pickable column and checks the visible ones" do
    render_table

    assert_equal 1, css_select("input[type=checkbox][value='isbn']").size
    assert_nil css_select("input[type=checkbox][value='isbn']").first["checked"]
    assert css_select("input[type=checkbox][value='title']").first["checked"]
  end

  test "an empty collection still renders the header" do
    table = ResourceTable::Table.new(resource_class: resource)
    render partial: "resource_table/daisyui/table/table", locals: {
      table: table, collection: [],
      presenter: ResourceTable::Presenter.new(view_context: view),
      actions: nil, key: "BookResource/index"
    }

    assert_equal 1, css_select("thead tr").size
    assert_equal 0, css_select("tbody tr td[data-column]").size
  end

  # --- _boolean.html.erb -----------------------------------------------
  #
  # Not exercised by any field above (none is `as: :boolean`), so this is
  # exercised on its own — otherwise the boolean specialisation would ship
  # in this task with no test ever having rendered it.

  test "a boolean cell renders a check when true and a dash when false" do
    stub = Class.new(ResourceCore::BaseResource) do
      def self.name = "StubResource"
      field :title
      field :out_of_print, as: :boolean, index: {}
    end
    table = ResourceTable::Table.new(resource_class: stub)
    render partial: "resource_table/daisyui/table/table", locals: {
      table: table,
      collection: [
        Book.new(title: "In print", out_of_print: false),
        Book.new(title: "Out of print", out_of_print: true)
      ],
      presenter: ResourceTable::Presenter.new(view_context: view),
      actions: nil, key: "StubResource/index"
    }
    cells = css_select("tbody td[data-column='out_of_print']")

    assert_equal 2, cells.size
    assert_includes cells[0].text, "–"
    assert_includes cells[1].text, "✓"
    assert_includes cells[0]["class"].to_s, "text-center"
  end

  test "a call-site block wins over the boolean cell's own markup" do
    stub = Class.new(ResourceCore::BaseResource) do
      def self.name = "StubResource"
      field :title
      field :out_of_print, as: :boolean, index: {}
    end
    table = ResourceTable::Table.new(resource_class: stub)
    render partial: "resource_table/daisyui/table/table", locals: {
      table: table,
      collection: [ Book.new(title: "In print", out_of_print: true) ],
      presenter: ResourceTable::Presenter.new(view_context: view, blocks: { out_of_print: ->(_b) { "whatever" } }),
      actions: nil, key: "StubResource/index"
    }
    cell = css_select("tbody td[data-column='out_of_print']").first

    assert_includes cell.text, "whatever"
    refute_includes cell.text, "✓"
  end

  test "a cell_<name> presenter method wins over the boolean cell's own markup" do
    stub = Class.new(ResourceCore::BaseResource) do
      def self.name = "StubResource"
      field :title
      field :out_of_print, as: :boolean, index: {}
    end
    presenter_class = Class.new(ResourceTable::Presenter) do
      def cell_out_of_print(_record) = "custom"
    end
    table = ResourceTable::Table.new(resource_class: stub)
    render partial: "resource_table/daisyui/table/table", locals: {
      table: table,
      collection: [ Book.new(title: "In print", out_of_print: true) ],
      presenter: presenter_class.new(view_context: view),
      actions: nil, key: "StubResource/index"
    }
    cell = css_select("tbody td[data-column='out_of_print']").first

    assert_includes cell.text, "custom"
    refute_includes cell.text, "✓"
  end

  test "a boolean cell honours align: right, and defaults to text-center otherwise" do
    stub = Class.new(ResourceCore::BaseResource) do
      def self.name = "StubResource"
      field :title
      field :out_of_print, as: :boolean, index: { align: :right }
    end
    table = ResourceTable::Table.new(resource_class: stub)
    render partial: "resource_table/daisyui/table/table", locals: {
      table: table,
      collection: [ Book.new(title: "In print", out_of_print: true) ],
      presenter: ResourceTable::Presenter.new(view_context: view),
      actions: nil, key: "StubResource/index"
    }
    cell = css_select("tbody td[data-column='out_of_print']").first

    assert_includes cell["class"].to_s, "text-right"
    refute_includes cell["class"].to_s, "text-center"
  end

  # --- _lookup_one.html.erb ----------------------------------------------
  #
  # Same gap: no field above is `as: :lookup_one`. Requires a route for the
  # associated model (Author) so url_for(associated) doesn't raise — added
  # to test/dummy/config/routes.rb for exactly this.

  test "a lookup_one cell links to the associated record via ResourceCore.lookup_label" do
    stub = Class.new(ResourceCore::BaseResource) do
      def self.name = "StubResource"
      field :title
      field :author, as: :lookup_one, index: {}
    end
    author = Author.create!(name: "N. K. Jemisin")
    linked = Book.create!(title: "The Fifth Season", author: author)
    table = ResourceTable::Table.new(resource_class: stub)
    render partial: "resource_table/daisyui/table/table", locals: {
      table: table, collection: [ linked ],
      presenter: ResourceTable::Presenter.new(view_context: view),
      actions: nil, key: "StubResource/index"
    }
    link = css_select("tbody td[data-column='author'] a").first

    assert link, "an associated record renders as a link"
    assert_equal "N. K. Jemisin", link.text
    assert_includes link["href"], "/authors/#{author.id}"
  end

  test "a lookup_one cell with nothing associated falls back to the presenter, no link" do
    stub = Class.new(ResourceCore::BaseResource) do
      def self.name = "StubResource"
      field :title
      field :publisher, as: :lookup_one, index: {}
    end
    unlinked = Book.new(title: "No publisher yet")
    table = ResourceTable::Table.new(resource_class: stub)
    render partial: "resource_table/daisyui/table/table", locals: {
      table: table, collection: [ unlinked ],
      presenter: ResourceTable::Presenter.new(view_context: view),
      actions: nil, key: "StubResource/index"
    }
    cell = css_select("tbody td[data-column='publisher']").first

    assert_equal 0, cell.css("a").size
  end

  test "a call-site block wins on a lookup_one cell whether or not the association is present" do
    # The bug: the specialised partial only deferred to the presenter when the
    # association was nil, so the same override behaved two ways down one
    # column. publisher is optional, so one row has it and one doesn't.
    stub = Class.new(ResourceCore::BaseResource) do
      def self.name = "StubResource"
      field :title
      field :publisher, as: :lookup_one, index: {}
    end
    publisher = Publisher.create!(name: "Ace Books")
    author = Author.create!(name: "Frank Herbert")
    linked = Book.create!(title: "Linked", author: author, publisher: publisher)
    unlinked = Book.create!(title: "Unlinked", author: author)
    table = ResourceTable::Table.new(resource_class: stub)
    render partial: "resource_table/daisyui/table/table", locals: {
      table: table, collection: [ linked, unlinked ],
      presenter: ResourceTable::Presenter.new(view_context: view, blocks: { publisher: ->(_b) { "whatever" } }),
      actions: nil, key: "StubResource/index"
    }
    cells = css_select("tbody td[data-column='publisher']")

    assert_equal 2, cells.size
    assert_includes cells[0].text, "whatever"
    assert_includes cells[1].text, "whatever"
    assert_equal 0, cells[0].css("a").size
  end

  test "a cell_<name> presenter method wins on a lookup_one cell whether or not the association is present" do
    stub = Class.new(ResourceCore::BaseResource) do
      def self.name = "StubResource"
      field :title
      field :publisher, as: :lookup_one, index: {}
    end
    presenter_class = Class.new(ResourceTable::Presenter) do
      def cell_publisher(_record) = "custom publisher"
    end
    publisher = Publisher.create!(name: "Ace Books")
    author = Author.create!(name: "Frank Herbert")
    linked = Book.create!(title: "Linked", author: author, publisher: publisher)
    unlinked = Book.create!(title: "Unlinked", author: author)
    table = ResourceTable::Table.new(resource_class: stub)
    render partial: "resource_table/daisyui/table/table", locals: {
      table: table, collection: [ linked, unlinked ],
      presenter: presenter_class.new(view_context: view),
      actions: nil, key: "StubResource/index"
    }
    cells = css_select("tbody td[data-column='publisher']")

    assert_equal 2, cells.size
    assert_includes cells[0].text, "custom publisher"
    assert_includes cells[1].text, "custom publisher"
    assert_equal 0, cells[0].css("a").size
  end

  test "a lookup_one cell falls back to plain text, and does not raise, when the associated model has no route" do
    # Publisher has no show route in the dummy app. url_for(associated) used
    # to be called unconditionally here, which raised
    # ActionController::UrlGenerationError and took down the whole page over
    # one cell.
    stub = Class.new(ResourceCore::BaseResource) do
      def self.name = "StubResource"
      field :title
      field :publisher, as: :lookup_one, index: {}
    end
    publisher = Publisher.create!(name: "Ace Books")
    linked = Book.create!(title: "Linked", author: Author.create!(name: "Frank Herbert"), publisher: publisher)
    table = ResourceTable::Table.new(resource_class: stub)
    render partial: "resource_table/daisyui/table/table", locals: {
      table: table, collection: [ linked ],
      presenter: ResourceTable::Presenter.new(view_context: view),
      actions: nil, key: "StubResource/index"
    }
    cell = css_select("tbody td[data-column='publisher']").first

    assert_includes cell.text, "Ace Books"
    assert_equal 0, cell.css("a").size
  end

  test "a lookup_one cell honours align: right" do
    stub = Class.new(ResourceCore::BaseResource) do
      def self.name = "StubResource"
      field :title
      field :author, as: :lookup_one, index: { align: :right }
    end
    author = Author.create!(name: "N. K. Jemisin")
    linked = Book.create!(title: "The Fifth Season", author: author)
    table = ResourceTable::Table.new(resource_class: stub)
    render partial: "resource_table/daisyui/table/table", locals: {
      table: table, collection: [ linked ],
      presenter: ResourceTable::Presenter.new(view_context: view),
      actions: nil, key: "StubResource/index"
    }
    cell = css_select("tbody td[data-column='author']").first

    assert_includes cell["class"].to_s, "text-right"
  end

  # --- _cell.html.erb's link: :self ---------------------------------------
  #
  # The brief's own 17 tests never declare `link:`, so this branch (and the
  # url_for(record) it depends on) would otherwise ship unexercised. A
  # minimal `resources :books, only: [:show]` route was added to the dummy
  # app so url_for(record) resolves for a persisted Book.

  test "link: :self wraps the cell content in a link to the record" do
    stub = Class.new(ResourceCore::BaseResource) do
      def self.name = "StubResource"
      field :title, index: { link: :self }
    end
    author = Author.create!(name: "Frank Herbert")
    book = Book.create!(title: "Dune", author: author)
    table = ResourceTable::Table.new(resource_class: stub)
    render partial: "resource_table/daisyui/table/table", locals: {
      table: table, collection: [ book ],
      presenter: ResourceTable::Presenter.new(view_context: view),
      actions: nil, key: "StubResource/index"
    }
    link = css_select("tbody td[data-column='title'] a").first

    assert link
    assert_equal "Dune", link.text
    assert_includes link["href"], "/books/#{book.id}"
  end

  test "without link: the cell renders plain text, never an anchor" do
    render_table

    assert_equal 0, css_select("tbody td[data-column='title'] a").size
  end

  test "link: :self falls back to plain text, and does not raise, when the record has no route" do
    # Same exposure as _lookup_one: url_for(record) used to be called
    # unconditionally here too. Publisher has no route in the dummy app.
    stub = Class.new(ResourceCore::BaseResource) do
      def self.name = "StubResource"
      field :name, index: { link: :self }
    end
    publisher = Publisher.create!(name: "Ace Books")
    table = ResourceTable::Table.new(resource_class: stub)
    render partial: "resource_table/daisyui/table/table", locals: {
      table: table, collection: [ publisher ],
      presenter: ResourceTable::Presenter.new(view_context: view),
      actions: nil, key: "StubResource/index"
    }
    cell = css_select("tbody td[data-column='name']").first

    assert_includes cell.text, "Ace Books"
    assert_equal 0, cell.css("a").size
  end
end
