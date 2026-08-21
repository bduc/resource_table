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

  test "a create race against another tab resolves to the row that won, not a duplicate" do
    key = "BookResource/index"

    # What our "tab" found when it looked: nothing yet, so a fresh, unsaved
    # record — built directly rather than via a query, so its staleness does
    # not depend on timing.
    stale_record = AuthorSetting.new(author: owner, key: key)

    # The other tab wins the race and creates the row first.
    AuthorSetting.create!(author: owner, key: key, value: { "visible" => %w[other_tab] })

    # Hand `write` the stale record in place of a fresh find_or_initialize_by,
    # so its save! collides for real with the row above via the unique index
    # (index_author_settings_on_author_id_and_key) — a genuine
    # ActiveRecord::RecordNotUnique, not a stubbed exception. find_by! passes
    # through to a real relation so the rescue path finds the winning row.
    real_relation = AuthorSetting.where(author: owner)
    relation_double = Object.new
    relation_double.define_singleton_method(:find_or_initialize_by) { |*| stale_record }
    relation_double.define_singleton_method(:find_by!) { |*args| real_relation.find_by!(*args) }
    store.define_singleton_method(:scope) { |_owner| relation_double }

    result = store.write(owner, key, { "visible" => %w[mine] })

    assert_equal({ "visible" => %w[mine] }, result)
    assert_equal 1, AuthorSetting.where(author: owner, key: key).count
  end
end
