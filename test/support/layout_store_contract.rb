# One contract, run against every adapter. A second adapter that quietly
# implements a different contract is exactly what this prevents.
#
# Including test case must define `store` and `owner` (and `other_owner`).
module LayoutStoreContract
  extend ActiveSupport::Testing::Declarative

  LAYOUT = { "visible" => %w[title pages], "widths" => { "title" => 180 } }.freeze

  test "reading an unknown key yields nil" do
    assert_nil store.read(owner, "BookResource/index")
  end

  test "a written layout reads back" do
    store.write(owner, "BookResource/index", LAYOUT)

    assert_equal LAYOUT, store.read(owner, "BookResource/index")
  end

  test "keys round-trip as strings, whatever went in" do
    store.write(owner, "BookResource/index", { visible: %i[title], widths: { title: 90 } })

    assert_equal({ "visible" => %w[title], "widths" => { "title" => 90 } },
                 store.read(owner, "BookResource/index"))
  end

  test "writing twice updates rather than duplicating" do
    store.write(owner, "BookResource/index", LAYOUT)
    store.write(owner, "BookResource/index", { "visible" => %w[pages] })

    assert_equal({ "visible" => %w[pages] }, store.read(owner, "BookResource/index"))
  end

  test "keys are independent of each other" do
    store.write(owner, "BookResource/index", LAYOUT)
    store.write(owner, "AuthorResource/index", { "visible" => %w[name] })

    assert_equal LAYOUT, store.read(owner, "BookResource/index")
    assert_equal({ "visible" => %w[name] }, store.read(owner, "AuthorResource/index"))
  end

  test "one owner cannot read another's layout" do
    store.write(owner, "BookResource/index", LAYOUT)

    assert_nil store.read(other_owner, "BookResource/index")
  end

  test "a nil owner reads nil and writes nothing" do
    assert_nil store.read(nil, "BookResource/index")
    assert_nothing_raised { store.write(nil, "BookResource/index", LAYOUT) }
    assert_nil store.read(nil, "BookResource/index")
  end
end
