require "test_helper"

class LayoutKeyTest < ActiveSupport::TestCase
  # Create a real test resource for use in tests
  setup do
    @resource_class = Class.new(ResourceCore::BaseResource) do
      def self.name
        "BookResource"
      end

      def self.model_class_name
        "Book"
      end
    end
    Object.const_set("BookResource", @resource_class)

    # Create a fake class that ends with "Resource" but does not inherit from BaseResource
    @imposter_class = Class.new do
      def self.name
        "ImposterResource"
      end
    end
    Object.const_set("ImposterResource", @imposter_class)

    # Two constants that are genuinely resolvable AND genuinely
    # ResourceCore::BaseResource subclasses, so the only thing standing
    # between them and a valid key is the shape regex — not the ancestry
    # check, and not safe_constantize finding nothing. Deleting the regex's
    # match? line must turn the tests using these red; a class name that
    # simply fails to constantize would pass regardless of the regex, which
    # is exactly the false coverage this guards against.
    @namespaced_class = Class.new(ResourceCore::BaseResource) do
      def self.name
        "Admin::BookResource"
      end
    end
    admin_module = Module.new
    Object.const_set("Admin", admin_module)
    admin_module.const_set("BookResource", @namespaced_class)

    @underscored_class = Class.new(ResourceCore::BaseResource) do
      def self.name
        "Book_Resource"
      end
    end
    Object.const_set("Book_Resource", @underscored_class)
  end

  teardown do
    Object.send(:remove_const, "BookResource") if Object.const_defined?("BookResource")
    Object.send(:remove_const, "ImposterResource") if Object.const_defined?("ImposterResource")
    Object.send(:remove_const, "Admin") if Object.const_defined?("Admin")
    Object.send(:remove_const, "Book_Resource") if Object.const_defined?("Book_Resource")
  end

  # Tests for layout_key_valid? — rejection cases

  test "layout_key_valid? rejects non-string types" do
    [ nil, :symbol, {}, 42, [] ].each do |invalid_input|
      refute ResourceTable.layout_key_valid?(invalid_input),
             "Should reject #{invalid_input.inspect} (#{invalid_input.class})"
    end
  end

  test "layout_key_valid? rejects key with no slash separator" do
    refute ResourceTable.layout_key_valid?("BookResourceindex")
  end

  test "layout_key_valid? rejects double slash" do
    refute ResourceTable.layout_key_valid?("//")
  end

  test "layout_key_valid? rejects extra path segments" do
    refute ResourceTable.layout_key_valid?("BookResource/index/extra")
  end

  test "layout_key_valid? rejects different view segment" do
    refute ResourceTable.layout_key_valid?("BookResource/show")
  end

  test "layout_key_valid? rejects empty view segment" do
    refute ResourceTable.layout_key_valid?("BookResource/")
  end

  test "layout_key_valid? rejects path traversal in view segment" do
    refute ResourceTable.layout_key_valid?("BookResource/../../etc")
  end

  test "layout_key_valid? rejects name without resource suffix" do
    refute ResourceTable.layout_key_valid?("Book/index")
  end

  # Admin::BookResource genuinely exists and genuinely inherits from
  # BaseResource (see setup) — safe_constantize would resolve it and the
  # ancestry check would pass, so only the regex's ban on "::" stops it.
  # A string that merely fails to constantize (as most of the other
  # rejection tests in this file do) cannot tell that apart from the regex
  # actually doing its job.
  test "layout_key_valid? rejects a namespaced constant that really does resolve" do
    refute ResourceTable.layout_key_valid?("Admin::BookResource/index")
  end

  test "layout_key_valid? rejects invalid character in resource name" do
    refute ResourceTable.layout_key_valid?("Book-Resource/index")
  end

  # Book_Resource genuinely exists and genuinely inherits from BaseResource
  # (see setup) — Ruby constant names may contain underscores, so this is
  # not a syntax error the way "Book-Resource" above is. Only the regex's
  # [A-Za-z0-9]* character class (no underscore) stops it.
  test "layout_key_valid? rejects an underscored constant that really does resolve" do
    refute ResourceTable.layout_key_valid?("Book_Resource/index")
  end

  test "layout_key_valid? rejects constant name starting with lowercase" do
    refute ResourceTable.layout_key_valid?("bookResource/index")
  end

  test "layout_key_valid? rejects name that matches pattern but resolves to no constant" do
    refute ResourceTable.layout_key_valid?("NoSuchResource/index")
  end

  test "layout_key_valid? rejects real class that is not a resource" do
    refute ResourceTable.layout_key_valid?("ImposterResource/index")
  end

  # Tests for layout_key_valid? — acceptance cases

  test "layout_key_valid? accepts a real resource class" do
    assert ResourceTable.layout_key_valid?("BookResource/index")
  end

  # Tests for layout_resource_class — the single resolution path
  # layout_key_valid? is expressed in terms of.

  test "layout_resource_class returns the class for a valid key" do
    assert_equal @resource_class, ResourceTable.layout_resource_class("BookResource/index")
  end

  # Same reasoning as the layout_key_valid? tests above: both of these keys
  # name real, resolvable ResourceCore::BaseResource subclasses (see setup),
  # so only the regex stands between them and being returned.
  test "layout_resource_class returns nil for a namespaced constant that really does resolve" do
    assert_nil ResourceTable.layout_resource_class("Admin::BookResource/index")
  end

  test "layout_resource_class returns nil for an underscored constant that really does resolve" do
    assert_nil ResourceTable.layout_resource_class("Book_Resource/index")
  end

  test "layout_resource_class returns nil for each invalid key shape" do
    [
      nil,
      :symbol,
      {},
      42,
      [],
      "BookResourceindex",
      "//",
      "BookResource/index/extra",
      "BookResource/show",
      "BookResource/",
      "BookResource/../../etc",
      "Book/index",
      "Admin::BookResource/index",
      "Book-Resource/index",
      "Book_Resource/index",
      "bookResource/index",
      "NoSuchResource/index",
      "ImposterResource/index"
    ].each do |invalid_key|
      assert_nil ResourceTable.layout_resource_class(invalid_key),
                 "Should return nil for #{invalid_key.inspect} (#{invalid_key.class})"
    end
  end

  # Tests for layout_key method
  #
  # layout_key takes no view argument: layout_resource_class only ever
  # accepts the literal "index" segment (see the rejection tests above), so
  # a `view:` that produced anything else could only ever build a key no
  # request could resolve back to a class.

  test "layout_key builds <ResourceName>/index from the resource class" do
    assert_equal "BookResource/index", ResourceTable.layout_key(@resource_class)
  end

  test "layout_key takes no second argument" do
    assert_raises(ArgumentError) { ResourceTable.layout_key(@resource_class, :show) }
  end
end
