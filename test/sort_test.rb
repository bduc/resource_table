require "test_helper"

class SortTest < ActiveSupport::TestCase
  def columns
    [
      ResourceTable::Column.new(name: :title,      spec: { index: { sortable: true } }),
      ResourceTable::Column.new(name: :department, spec: { index: { sortable: "departments.name" } }),
      ResourceTable::Column.new(name: :synopsis,   spec: {})
    ]
  end

  # --- the test that matters most -------------------------------------------

  test "an undeclared sort param is rejected, not passed through" do
    sort = ResourceTable::Sort.from_params({ "sort" => "synopsis" }, columns)

    refute sort.active?, "a column with no `sortable:` must not be sortable by URL"
    assert_nil sort.order_clause
  end

  test "a sort param naming no column at all is rejected" do
    sort = ResourceTable::Sort.from_params({ "sort" => "password_digest" }, columns)

    refute sort.active?
    assert_nil sort.order_clause
  end

  test "SQL in the sort param never reaches the order clause" do
    injection = "title; DROP TABLE members --"
    sort = ResourceTable::Sort.from_params({ "sort" => injection }, columns)

    refute sort.active?
    assert_nil sort.order_clause
  end

  test "SQL in the direction param never reaches the order clause" do
    sort = ResourceTable::Sort.from_params(
      { "sort" => "title", "dir" => "asc; DROP TABLE members --" }, columns
    )

    assert sort.active?
    assert_equal "asc", sort.direction
    assert_equal "title asc", sort.order_clause.to_s
  end

  test "the expression comes from the declaration, never from the param" do
    sort = ResourceTable::Sort.from_params({ "sort" => "department" }, columns)

    assert_equal "departments.name asc", sort.order_clause.to_s
  end

  # --- ordinary behaviour ---------------------------------------------------

  test "no sort param yields no ordering" do
    sort = ResourceTable::Sort.from_params({}, columns)

    refute sort.active?
    assert_nil sort.order_clause
    assert_nil sort.field
  end

  test "a declared column sorts ascending by default" do
    sort = ResourceTable::Sort.from_params({ "sort" => "title" }, columns)

    assert sort.active?
    assert_equal :title, sort.field
    assert_equal "asc", sort.direction
    assert_equal "title asc", sort.order_clause.to_s
  end

  test "desc is honoured" do
    sort = ResourceTable::Sort.from_params({ "sort" => "title", "dir" => "desc" }, columns)

    assert_equal "title desc", sort.order_clause.to_s
  end

  test "symbol param keys work as well as strings" do
    sort = ResourceTable::Sort.from_params({ sort: "title", dir: "desc" }, columns)

    assert_equal "title desc", sort.order_clause.to_s
  end

  test "unpermitted ActionController::Parameters do not raise" do
    # The helper hands this method the controller's real params. #to_h on an
    # unpermitted Parameters raises UnfilteredParameters, which would 500 the
    # first sorted page load — and no plain-Hash test would ever catch it.
    params = ActionController::Parameters.new("sort" => "title", "dir" => "desc")
    refute params.permitted?, "the fixture must be unpermitted or this proves nothing"

    sort = ResourceTable::Sort.from_params(params, columns)

    assert_equal "title desc", sort.order_clause.to_s
  end

  test "an undeclared sort in ActionController::Parameters is still rejected" do
    params = ActionController::Parameters.new("sort" => "synopsis")

    refute ResourceTable::Sort.from_params(params, columns).active?
  end

  test "the order clause is marked as trusted SQL" do
    sort = ResourceTable::Sort.from_params({ "sort" => "department" }, columns)

    assert_kind_of Arel::Nodes::SqlLiteral, sort.order_clause
  end

  test "direction_for marks only the active column" do
    sort = ResourceTable::Sort.from_params({ "sort" => "title", "dir" => "desc" }, columns)
    by_name = columns.index_by(&:name)

    assert_equal "desc", sort.direction_for(by_name[:title])
    assert_nil sort.direction_for(by_name[:department])
  end

  test "clicking the active column flips it, another starts ascending" do
    sort = ResourceTable::Sort.from_params({ "sort" => "title", "dir" => "asc" }, columns)
    by_name = columns.index_by(&:name)

    assert_equal "desc", sort.next_direction_for(by_name[:title])
    assert_equal "asc",  sort.next_direction_for(by_name[:department])
  end

  test "none is inert" do
    assert_nil ResourceTable::Sort.none.order_clause
    refute ResourceTable::Sort.none.active?
  end
end
