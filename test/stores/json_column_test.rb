require "test_helper"
require "support/layout_store_contract"

class JsonColumnTest < ActiveSupport::TestCase
  include LayoutStoreContract

  def store
    @store ||= ResourceTable::Stores::JsonColumn.new(column: :table_layouts)
  end

  def owner
    @owner ||= Author.create!(name: "Herbert")
  end

  def other_owner
    @other_owner ||= Author.create!(name: "Le Guin")
  end

  test "keeps every layout in the one column" do
    store.write(owner, "BookResource/index", { "visible" => %w[title] })
    store.write(owner, "AuthorResource/index", { "visible" => %w[name] })

    assert_equal %w[AuthorResource/index BookResource/index],
                 owner.reload.table_layouts.keys.sort
  end
end
