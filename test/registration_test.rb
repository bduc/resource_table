require "test_helper"

class RegistrationTest < ActiveSupport::TestCase
  setup { ResourceTable.register_field_types! }

  test "registers the table renderer" do
    assert_includes ResourceCore::Registry.renderers.keys, :table
  end

  test "registers the index namespace with the declared keys" do
    assert_equal %i[sortable width align link label format default flex].sort,
                 ResourceCore::Registry.namespace(:index).sort
  end

  test "every cell partial named by the map exists" do
    root = ResourceTable::Engine.root.join("app/views/resource_table/daisyui/table")
    (ResourceTable::CELL_PARTIALS.values + [ "cell" ]).uniq.each do |partial|
      assert root.join("_#{partial}.html.erb").exist?, "missing cell partial #{partial.inspect}"
    end
  end

  test "an unmapped type falls through to the generic cell" do
    assert_equal "cell", ResourceTable.cell_partial_for(:text)
    assert_equal "cell", ResourceTable.cell_partial_for(nil)
    assert_equal "boolean", ResourceTable.cell_partial_for(:boolean)
  end

  test "declaring an unknown index key raises, naming the key" do
    error = assert_raises(ArgumentError) do
      Class.new(ResourceCore::BaseResource) do
        def self.name = "BookResource"
        field :title, index: { sortible: true }
      end.fields
    end
    assert_match(/sortible/, error.message)
  end

  test "index: false is accepted" do
    klass = Class.new(ResourceCore::BaseResource) do
      def self.name = "BookResource"
      field :title, index: false
    end
    assert_equal false, klass.fields[:title][:index]
  end
end
