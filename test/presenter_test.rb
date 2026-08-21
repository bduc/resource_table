require "test_helper"

class PresenterTest < ActiveSupport::TestCase
  # A view context stand-in: capture is the only thing Presenter asks of it,
  # plus whatever a cell_ method chooses to delegate.
  class FakeView
    def capture(*args, &block) = block.call(*args).to_s
    def shout(text) = text.to_s.upcase
  end

  class BookPresenter < ResourceTable::Presenter
    resource ResourceCore::BaseResource

    def cell_title(book) = "presenter: #{book.title}"
    def cell_shouted(book) = shout(book.title)
  end

  def column(name, spec = {})
    ResourceTable::Column.new(name: name, spec: spec)
  end

  def book(title: "Dune")
    Book.new(title: title, pages: 412)
  end

  test "falls back to Value.display when nothing overrides" do
    presenter = ResourceTable::Presenter.new(view_context: FakeView.new)

    assert_equal "412", presenter.cell(column(:pages), book)
  end

  test "a presenter method wins over Value.display" do
    presenter = BookPresenter.new(view_context: FakeView.new)

    assert_equal "presenter: Dune", presenter.cell(column(:title), book)
  end

  test "a block wins over a presenter method" do
    presenter = BookPresenter.new(
      view_context: FakeView.new,
      blocks: { title: ->(b) { "block: #{b.title}" } }
    )

    assert_equal "block: Dune", presenter.cell(column(:title), book)
  end

  test "a block wins over Value.display" do
    presenter = ResourceTable::Presenter.new(
      view_context: FakeView.new,
      blocks: { pages: ->(b) { "#{b.pages} pp." } }
    )

    assert_equal "412 pp.", presenter.cell(column(:pages), book)
  end

  test "a cell method may call view helpers" do
    presenter = BookPresenter.new(view_context: FakeView.new)

    assert_equal "DUNE", presenter.cell(column(:shouted), book)
  end

  test "lookup uses method_defined?, not respond_to?" do
    # The presenter delegates missing methods to the view, so respond_to? would
    # consult the view too — and a view helper named cell_<column> would be
    # silently treated as a cell override.
    view = FakeView.new
    def view.cell_pages(_record) = "from the view, wrongly"
    presenter = ResourceTable::Presenter.new(view_context: view)

    assert_equal "412", presenter.cell(column(:pages), book)
  end

  test "options are available to cell methods" do
    klass = Class.new(ResourceTable::Presenter) do
      def cell_level(_record) = options[:global_tab] ? "AV" : "afdeling"
    end

    assert_equal "AV", klass.new(view_context: FakeView.new, global_tab: "av").cell(column(:level), book)
    assert_equal "afdeling", klass.new(view_context: FakeView.new).cell(column(:level), book)
  end

  test "resource is declared on the class and inherited" do
    assert_equal ResourceCore::BaseResource, BookPresenter.resource
    assert_equal ResourceCore::BaseResource, Class.new(BookPresenter).resource
    assert_nil ResourceTable::Presenter.resource
  end

  test "the builder collects cell and actions blocks" do
    builder = ResourceTable::Builder.new
    builder.cell(:title) { |b| b.title }
    builder.actions { |b| "edit #{b.title}" }

    assert_equal [ :title ], builder.cell_blocks.keys
    assert_respond_to builder.actions_block, :call
  end

  test "the builder symbolizes cell names" do
    builder = ResourceTable::Builder.new
    builder.cell("title") { |b| b.title }

    assert_equal [ :title ], builder.cell_blocks.keys
  end

  test "overridden? is true when a call-site block exists for the column" do
    presenter = ResourceTable::Presenter.new(
      view_context: FakeView.new,
      blocks: { title: ->(b) { b.title } }
    )

    assert presenter.overridden?(column(:title))
  end

  test "overridden? is true when a cell_<name> method exists" do
    presenter = BookPresenter.new(view_context: FakeView.new)

    assert presenter.overridden?(column(:title))
  end

  test "overridden? is false when neither a block nor a cell_<name> method exists" do
    presenter = ResourceTable::Presenter.new(view_context: FakeView.new)

    refute presenter.overridden?(column(:pages))
  end

  test "overridden? uses method_defined?, not respond_to?, for the same reason cell does" do
    # A view helper named cell_<column> must not be mistaken for an override —
    # the presenter delegates missing methods to the view, so respond_to?
    # would consult it too.
    view = FakeView.new
    def view.cell_pages(_record) = "from the view, wrongly"
    presenter = ResourceTable::Presenter.new(view_context: view)

    refute presenter.overridden?(column(:pages))
  end

  test "record_url returns nil, not raise, when the view context has no url_for" do
    presenter = ResourceTable::Presenter.new(view_context: FakeView.new)

    assert_nil presenter.record_url(book)
  end
end
