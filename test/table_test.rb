require "test_helper"

class TableTest < ActiveSupport::TestCase
  # Named so it resolves no model: BaseResource#fields only auto-detects
  # columns/associations when .model_class resolves (see model_class_name's
  # suffix-stripped safe_constantize). Naming this "BookResource" — as the
  # nearby "a label comes from..." test deliberately does, to reach the real
  # Book model — would auto-detect Book's whole schema, and the coded field
  # list would stop being just what each test explicitly declares.
  def resource(&block)
    Class.new(ResourceCore::BaseResource) do
      def self.name = "StubResource"
      class_eval(&block) if block
    end
  end

  test "the coded default is every field not excluded, in declaration order" do
    klass = resource do
      field :title
      field :synopsis, index: false
      field :pages
    end
    table = ResourceTable::Table.new(resource_class: klass)

    assert_equal %i[title pages], table.columns.map(&:name)
  end

  test "index: { default: false } is pickable but not visible" do
    klass = resource do
      field :title
      field :isbn, index: { default: false }
    end
    table = ResourceTable::Table.new(resource_class: klass)

    assert_equal %i[title], table.columns.map(&:name)
    assert_equal %i[title isbn], table.pickable.map(&:name)
  end

  test "index: false is neither visible nor pickable" do
    klass = resource do
      field :title
      field :synopsis, index: false
    end
    table = ResourceTable::Table.new(resource_class: klass)

    assert_equal %i[title], table.pickable.map(&:name)
  end

  test "a stored layout wins over the coded default, order included" do
    klass = resource do
      field :title
      field :pages
      field :isbn
    end
    layout = { "visible" => %w[isbn title] }
    table = ResourceTable::Table.new(resource_class: klass, layout: layout)

    assert_equal %i[isbn title], table.columns.map(&:name)
  end

  test "a stored layout naming a field that no longer exists drops it" do
    klass = resource { field :title }
    layout = { "visible" => %w[title removed_column] }
    table = ResourceTable::Table.new(resource_class: klass, layout: layout)

    assert_equal %i[title], table.columns.map(&:name)
  end

  test "a stored layout naming only unknown fields falls back to the coded default" do
    klass = resource { field :title }
    layout = { "visible" => %w[gone] }
    table = ResourceTable::Table.new(resource_class: klass, layout: layout)

    assert_equal %i[title], table.columns.map(&:name),
                 "an empty resolved layout must not render a table with no columns"
  end

  test "a stored layout may not resurrect an index: false field" do
    klass = resource do
      field :title
      field :synopsis, index: false
    end
    layout = { "visible" => %w[title synopsis] }
    table = ResourceTable::Table.new(resource_class: klass, layout: layout)

    assert_equal %i[title], table.columns.map(&:name)
  end

  test "width precedence is persisted, then declared, then nil" do
    klass = resource do
      field :title, index: { width: 200 }
      field :pages
      field :isbn,  index: { width: 90 }
    end
    layout = { "widths" => { "isbn" => 300 } }
    table = ResourceTable::Table.new(resource_class: klass, layout: layout)
    by_name = table.columns.index_by(&:name)

    assert_equal 200, by_name[:title].width
    assert_nil   by_name[:pages].width
    assert_equal 300, by_name[:isbn].width
  end

  test "a column with neither a declared nor a persisted width autosizes" do
    klass = resource do
      field :title, index: { width: 200 }
      field :pages
    end
    table = ResourceTable::Table.new(resource_class: klass)
    by_name = table.columns.index_by(&:name)

    refute by_name[:title].autosize?
    assert by_name[:pages].autosize?
  end

  test "the flex column never autosizes" do
    klass = resource { field :synopsis, index: { flex: true } }
    table = ResourceTable::Table.new(resource_class: klass)

    assert table.columns.first.flex?
    refute table.columns.first.autosize?
  end

  test "a label comes from index:, then the field label, then the model" do
    klass = Class.new(ResourceCore::BaseResource) do
      def self.name = "BookResource"
      field :title, index: { label: "Titel" }
      field :isbn
    end
    table = ResourceTable::Table.new(resource_class: klass)
    by_name = table.columns.index_by(&:name)

    assert_equal "Titel", by_name[:title].label
    assert_equal "ISBN number", by_name[:isbn].label
  end

  test "sortable: true sorts on the column's own name" do
    column = ResourceTable::Column.new(name: :title, spec: { index: { sortable: true } })

    assert column.sortable?
    assert_equal "title", column.sort_expression
  end

  test "sortable: a string is the expression to order by" do
    column = ResourceTable::Column.new(name: :department, spec: { index: { sortable: "departments.name" } })

    assert column.sortable?
    assert_equal "departments.name", column.sort_expression
  end

  test "sortable: a symbol is the expression to order by" do
    column = ResourceTable::Column.new(name: :department, spec: { index: { sortable: :department_name } })

    assert column.sortable?
    assert_equal "department_name", column.sort_expression
  end

  test "a field with no sortable is not sortable" do
    refute ResourceTable::Column.new(name: :title, spec: {}).sortable?
    refute ResourceTable::Column.new(name: :title, spec: { index: { sortable: false } }).sortable?
  end

  test "sortable: a blank string is not sortable" do
    refute ResourceTable::Column.new(name: :title, spec: { index: { sortable: "" } }).sortable?
  end

  test "sortable: a whitespace-only string is not sortable" do
    refute ResourceTable::Column.new(name: :title, spec: { index: { sortable: "   " } }).sortable?
  end

  test "value_spec merges the index format over the field format" do
    column = ResourceTable::Column.new(name: :price, spec: { format: :plain, index: { format: :currency } })

    assert_equal :currency, column.value_spec[:format]
  end
end
