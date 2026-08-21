require "test_helper"
require "support/layout_store_contract"

class SettingsTableTest < ActiveSupport::TestCase
  include LayoutStoreContract

  def store
    @store ||= ResourceTable::Stores::SettingsTable.new(model: AuthorSetting, owner_association: :author)
  end

  def owner
    @owner ||= Author.create!(name: "Herbert")
  end

  def other_owner
    @other_owner ||= Author.create!(name: "Le Guin")
  end

  test "writes one row per key" do
    store.write(owner, "BookResource/index", { "visible" => %w[title] })
    store.write(owner, "AuthorResource/index", { "visible" => %w[name] })

    assert_equal 2, AuthorSetting.where(author: owner).count
  end
end
