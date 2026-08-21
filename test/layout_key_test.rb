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
  end

  teardown do
    Object.send(:remove_const, "BookResource") if Object.const_defined?("BookResource")
    Object.send(:remove_const, "ImposterResource") if Object.const_defined?("ImposterResource")
  end

  # Tests for layout_key_valid? — rejection cases

  test "layout_key_valid? rejects nil" do
    assert_equal false, ResourceTable.layout_key_valid?(nil)
  end

  test "layout_key_valid? rejects non-string symbol" do
    assert_equal false, ResourceTable.layout_key_valid?(:symbol)
  end

  test "layout_key_valid? rejects non-string hash" do
    assert_equal false, ResourceTable.layout_key_valid?({})
  end

  test "layout_key_valid? rejects non-string integer" do
    assert_equal false, ResourceTable.layout_key_valid?(42)
  end

  test "layout_key_valid? rejects non-string array" do
    assert_equal false, ResourceTable.layout_key_valid?([])
  end

  test "layout_key_valid? rejects key with no slash separator" do
    assert_equal false, ResourceTable.layout_key_valid?("BookResourceindex")
  end

  test "layout_key_valid? rejects double slash" do
    assert_equal false, ResourceTable.layout_key_valid?("//")
  end

  test "layout_key_valid? rejects extra path segments" do
    assert_equal false, ResourceTable.layout_key_valid?("BookResource/index/extra")
  end

  test "layout_key_valid? rejects different view segment" do
    assert_equal false, ResourceTable.layout_key_valid?("BookResource/show")
  end

  test "layout_key_valid? rejects empty view segment" do
    assert_equal false, ResourceTable.layout_key_valid?("BookResource/")
  end

  test "layout_key_valid? rejects path traversal in view segment" do
    assert_equal false, ResourceTable.layout_key_valid?("BookResource/../../etc")
  end

  test "layout_key_valid? rejects name without resource suffix" do
    assert_equal false, ResourceTable.layout_key_valid?("Book/index")
  end

  test "layout_key_valid? rejects namespaced constant" do
    assert_equal false, ResourceTable.layout_key_valid?("Admin::BookResource/index")
  end

  test "layout_key_valid? rejects invalid character in resource name" do
    assert_equal false, ResourceTable.layout_key_valid?("Book-Resource/index")
  end

  test "layout_key_valid? rejects constant name starting with lowercase" do
    assert_equal false, ResourceTable.layout_key_valid?("bookResource/index")
  end

  test "layout_key_valid? rejects name that matches pattern but resolves to no constant" do
    assert_equal false, ResourceTable.layout_key_valid?("NoSuchResource/index")
  end

  test "layout_key_valid? rejects real class that is not a resource" do
    assert_equal false, ResourceTable.layout_key_valid?("ImposterResource/index")
  end

  # Tests for layout_key_valid? — acceptance cases

  test "layout_key_valid? accepts a real resource class" do
    assert_equal true, ResourceTable.layout_key_valid?("BookResource/index")
  end

  # Tests for layout_key method

  test "layout_key builds key from resource class and default view" do
    assert_equal "BookResource/index", ResourceTable.layout_key(@resource_class)
  end

  test "layout_key builds key from resource class and explicit view" do
    assert_equal "BookResource/show", ResourceTable.layout_key(@resource_class, :show)
  end

  test "layout_key converts symbol view to string" do
    assert_equal "BookResource/custom", ResourceTable.layout_key(@resource_class, :custom)
  end

  test "layout_key uses Resource class name" do
    assert_equal "BookResource/index", ResourceTable.layout_key(@resource_class)
  end
end
