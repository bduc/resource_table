require "test_helper"

class TableHelperTest < ActionView::TestCase
  include ResourceTable::Helpers::TableHelper

  # model_class_name is set explicitly rather than left to derive from
  # `name` ("TableHelperTest::BookResource"), because stripping the
  # configured suffix from that nested name would look for a
  # "TableHelperTest::Book" constant, which does not exist — fields would
  # come back empty and the table would render no columns at all. Pointing
  # it at the real Book model means #fields auto-detects Book's actual
  # schema (title, pages, and everything else on the table), which is
  # exactly what "renders from a resource alone" and the presenter tests
  # below rely on. See "the resource resolves real fields" below, which
  # pins this rather than assuming it silently keeps working.
  class BookResource < ResourceCore::BaseResource
    self.model_class_name = "Book"
    field :title, index: { sortable: true }
    field :pages
  end

  class BookPresenter < ResourceTable::Presenter
    resource BookResource
    def cell_pages(book) = "#{book.pages} pp."
  end

  # A second resource, distinct from the one BookPresenter declares, so
  # "an explicit resource wins over a presenter's declared resource" can
  # actually distinguish the two resolution orders. Without this, every
  # other test in the file passes `resource:` alone or `presenter:` alone,
  # never both with conflicting resources — so `resource || presenter.resource`
  # and `presenter.resource || resource` produce identical output everywhere
  # else in this file.
  class OtherResource < ResourceCore::BaseResource
    self.model_class_name = "Book"
    field :title
  end

  class MemoryStore
    def initialize(layouts = {}) = @layouts = layouts
    def read(_owner, key) = @layouts[key]
    def write(_owner, key, layout) = @layouts[key] = layout
  end

  setup do
    @author = Author.create!(name: "Herbert")
    ResourceTable.configure do |c|
      c.layout_store = MemoryStore.new
      c.owner_method = :current_author
    end

    # title is sortable, so every render below reaches _head.html.erb's
    # url_for(request.query_parameters.merge(sort:, dir:, page:)) — no
    # :controller/:action in that hash. On a real index page url_for
    # recalls both from the current request's path_parameters for free;
    # there is no real request here, so this stands in for "rendered from
    # some index action" the same way rendering_test.rb does. Without it
    # every test in this file raises ActionController::UrlGenerationError,
    # not just the ones that care about sorting.
    request.path_parameters = { controller: "books", action: "index" }
  end

  teardown { ResourceTable.configure { |c| c.layout_store = nil; c.owner_method = :current_user } }

  def current_author = @author

  def books = [ Book.new(title: "Dune", pages: 412) ]

  test "the resource resolves real fields from the Book model" do
    # Guards the setup this whole file depends on: if model_class_name ever
    # stopped resolving (e.g. a rename), #fields would quietly go empty and
    # every test below would pass for the wrong reason — no columns to find
    # "Dune" or "412 pp." in, but no columns to fail on either.
    assert_includes BookResource.fields.keys, :title
    assert_includes BookResource.fields.keys, :pages
    assert BookResource.fields[:title][:index][:sortable]
  end

  test "renders from a resource alone" do
    render_result = resource_table_for(books, resource: BookResource)

    assert_includes render_result, "Dune"
    assert_includes render_result, 'data-controller="table-layout"'
  end

  test "infers the resource from a presenter that declares one" do
    render_result = resource_table_for(books, presenter: BookPresenter)

    assert_includes render_result, "412 pp."
  end

  test "raises when neither a resource nor a declaring presenter is given" do
    error = assert_raises(ArgumentError) { resource_table_for(books) }

    assert_match(/resource:/, error.message)
  end

  test "an explicit resource wins over a presenter's declared resource" do
    render_result = resource_table_for(books, resource: OtherResource, presenter: BookPresenter)

    assert_includes render_result, 'data-table-layout-key-value="TableHelperTest::OtherResource/index"'
  end

  test "derives the layout key from the resource" do
    render_result = resource_table_for(books, resource: BookResource)

    assert_includes render_result, 'data-table-layout-key-value="TableHelperTest::BookResource/index"'
  end

  test "an explicit key wins" do
    render_result = resource_table_for(books, resource: BookResource, key: "Custom/index")

    assert_includes render_result, 'data-table-layout-key-value="Custom/index"'
  end

  test "reads the stored layout for the configured owner" do
    ResourceTable.config.layout_store =
      MemoryStore.new("TableHelperTest::BookResource/index" => { "visible" => %w[pages] })

    render_result = resource_table_for(books, resource: BookResource)

    assert_includes render_result, 'data-column="pages"'
    refute_includes render_result, 'data-column="title"'
  end

  test "passes options through to the presenter" do
    klass = Class.new(ResourceTable::Presenter) do
      def cell_title(_book) = options[:global_tab].to_s
    end
    render_result = resource_table_for(books, resource: BookResource, presenter: klass, global_tab: "av")

    assert_includes render_result, "av"
  end

  test "yields a builder whose blocks reach the cells" do
    render_result = resource_table_for(books, resource: BookResource) do |t|
      t.cell(:title) { |b| "block #{b.title}" }
    end

    assert_includes render_result, "block Dune"
  end

  test "an actions block renders the pinned column" do
    render_result = resource_table_for(books, resource: BookResource) do |t|
      t.actions { |b| "edit #{b.title}" }
    end

    assert_includes render_result, "col-row-actions"
    assert_includes render_result, "edit Dune"
  end

  test "works with no store configured" do
    ResourceTable.config.layout_store = nil

    assert_includes resource_table_for(books, resource: BookResource), "Dune"
  end

  # --- table: -----------------------------------------------------------
  #
  # A caller (typically a controller building a Table up front to read
  # table.sort.order_clause before querying) may pass its own Table in, so
  # the view does not construct a second one — and read the layout store a
  # second time — for the same request.

  class RaisingStore
    def read(*) = raise "layout store should not be read when table: is given"
    def write(*) = raise "layout store should not be written by resource_table_for"
  end

  test "passing table: uses it instead of building one" do
    table = ResourceTable::Table.new(
      resource_class: BookResource,
      layout: { "visible" => %w[title] },
      params: {}
    )

    render_result = resource_table_for(books, resource: BookResource, table: table)

    assert_includes render_result, 'data-column="title"'
    refute_includes render_result, 'data-column="pages"'
  end

  test "passing table: performs no layout-store read" do
    ResourceTable.config.layout_store = RaisingStore.new
    table = ResourceTable::Table.new(resource_class: BookResource, layout: nil, params: {})

    render_result = resource_table_for(books, resource: BookResource, table: table)

    assert_includes render_result, "Dune"
  end

  # --- params ----------------------------------------------------------
  #
  # Table.new(params: params) receives ActionController::Parameters in
  # production; Sort.normalize handles that via #to_unsafe_h. Inside an
  # ActionView::TestCase, `params` delegates to the TestController's own
  # `params` (ActionController::Parameters.new — empty and *unpermitted*),
  # not a plain Hash, so every test above already exercises that path. This
  # one goes further: a genuinely non-empty, unpermitted Parameters object,
  # confirmed by #permitted? being false, carrying real sort/dir values that
  # must reach the rendered sort link — proving the helper does not
  # accidentally only work because the default happened to be empty.
  test "an unpermitted ActionController::Parameters with real values renders and sorts" do
    real_params = ActionController::Parameters.new(sort: "title", dir: "asc")
    refute real_params.permitted?
    controller.params = real_params

    render_result = resource_table_for(books, resource: BookResource)

    assert_includes render_result, "Dune"
    href = css_select("thead th[data-column='title'] a").first["href"]
    assert_includes href, "dir=desc"
  end

  # --- sort_path: ----------------------------------------------------------

  test "sort_path: reaches the sort link" do
    controller.params = ActionController::Parameters.new(sort: "title", dir: "asc")

    resource_table_for(books, resource: BookResource, sort_path: "/custom-books")

    href = css_select("thead th[data-column='title'] a").first["href"]
    assert_match %r{\A/custom-books\?}, href
  end

  test "omitting sort_path: falls back to url_for, unchanged" do
    controller.params = ActionController::Parameters.new(sort: "title", dir: "asc")

    resource_table_for(books, resource: BookResource)

    href = css_select("thead th[data-column='title'] a").first["href"]
    assert_match %r{\A/books\b}, href
  end

  # --- picker: / resource_table_picker_for ---------------------------------
  #
  # The picker used to be hardcoded into _table.html.erb, immediately after
  # the table's own scroll wrapper — a host had no way to place it anywhere
  # else (e.g. a card header, beside a "+" button). picker: lets a host opt
  # the inline picker out; resource_table_picker_for renders just the picker,
  # resolving resource:/presenter:/key:/layout:/table: through the exact same
  # private method resource_table_for uses, so the two agree on the same key
  # and, when table: is passed to both, the identical Table.

  test "picker: false suppresses the inline picker" do
    render_result = resource_table_for(books, resource: BookResource, picker: false)

    refute_includes render_result, "resource-table-picker"
  end

  test "picker: true (the default) still renders the inline picker" do
    render_result = resource_table_for(books, resource: BookResource)

    assert_includes render_result, "resource-table-picker"
  end

  test "resource_table_picker_for renders only the picker, not the table" do
    render_result = resource_table_picker_for(resource: BookResource)

    assert_includes render_result, "resource-table-picker"
    refute_includes render_result, "<table"
  end

  test "resource_table_picker_for resolves the resource from a presenter, like resource_table_for" do
    render_result = resource_table_picker_for(presenter: BookPresenter)

    assert_includes render_result, 'data-table-layout-picker-key-value="TableHelperTest::BookResource/index"'
  end

  test "resource_table_picker_for raises when neither a resource nor a declaring presenter is given" do
    error = assert_raises(ArgumentError) { resource_table_picker_for }

    assert_match(/resource:/, error.message)
  end

  test "resource_table_picker_for and resource_table_for derive the same key for the same resource" do
    table_result = resource_table_for(books, resource: BookResource)
    picker_result = resource_table_picker_for(resource: BookResource)

    assert_includes table_result, 'data-table-layout-key-value="TableHelperTest::BookResource/index"'
    assert_includes picker_result, 'data-table-layout-picker-key-value="TableHelperTest::BookResource/index"'
  end

  test "resource_table_picker_for passing table: uses it instead of building one" do
    table = ResourceTable::Table.new(
      resource_class: BookResource,
      layout: { "visible" => %w[title] },
      params: {}
    )

    resource_table_picker_for(resource: BookResource, table: table)

    assert css_select("input[type=checkbox][value='title']").first["checked"]
    refute css_select("input[type=checkbox][value='pages']").first["checked"]
  end

  test "resource_table_picker_for passing table: performs no layout-store read" do
    ResourceTable.config.layout_store = RaisingStore.new
    table = ResourceTable::Table.new(resource_class: BookResource, layout: nil, params: {})

    render_result = resource_table_picker_for(resource: BookResource, table: table)

    assert_includes render_result, "resource-table-picker"
  end

  test "resource_table_picker_for without table: reads the layout store" do
    ResourceTable.config.layout_store =
      MemoryStore.new("TableHelperTest::BookResource/index" => { "visible" => %w[pages] })

    resource_table_picker_for(resource: BookResource)

    assert css_select("input[type=checkbox][value='pages']").first["checked"]
    refute css_select("input[type=checkbox][value='title']").first["checked"]
  end

  test "resource_table_picker_for defaults the wrapper to dropdown-end" do
    resource_table_picker_for(resource: BookResource)

    assert_includes css_select(".resource-table-picker").first["class"], "dropdown-end"
  end

  test "resource_table_picker_for's class: overrides the wrapper's alignment" do
    resource_table_picker_for(resource: BookResource, class: "dropdown-start")

    wrapper_class = css_select(".resource-table-picker").first["class"]
    assert_includes wrapper_class, "dropdown-start"
    refute_includes wrapper_class, "dropdown-end"
  end
end
