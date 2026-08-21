require "test_helper"

class NormalizeLayoutTest < ActiveSupport::TestCase
  test "symbol values inside an array are stringified" do
    result = ResourceTable::Stores.normalize_layout({ visible: %i[title pages] })

    assert_equal({ "visible" => %w[title pages] }, result)
  end

  test "hash keys are stringified at every depth" do
    result = ResourceTable::Stores.normalize_layout({ widths: { title: 90 } })

    assert_equal({ "widths" => { "title" => 90 } }, result)
  end

  test "integer values are preserved as integers, not stringified" do
    result = ResourceTable::Stores.normalize_layout({ widths: { title: 90 } })

    assert_kind_of Integer, result["widths"]["title"]
  end

  test "nil is preserved" do
    assert_nil ResourceTable::Stores.normalize_layout(nil)
  end

  test "true and false are preserved" do
    result = ResourceTable::Stores.normalize_layout({ pinned: true, archived: false })

    assert result["pinned"]
    refute result["archived"]
  end

  test "an already-string-keyed hash is unchanged" do
    layout = { "visible" => %w[title pages], "widths" => { "title" => 180 } }

    assert_equal layout, ResourceTable::Stores.normalize_layout(layout)
  end

  test "a deeply nested mix of arrays and hashes converts throughout" do
    input = {
      groups: [
        { key: :title, sort: :asc },
        { key: :pages, sort: :desc }
      ]
    }

    assert_equal(
      { "groups" => [ { "key" => "title", "sort" => "asc" }, { "key" => "pages", "sort" => "desc" } ] },
      ResourceTable::Stores.normalize_layout(input)
    )
  end
end
