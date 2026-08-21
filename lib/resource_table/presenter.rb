module ResourceTable
  # Where a computed cell lives.
  #
  # Deliberately not a component: it holds a view_context and answers
  # cell(column, record), so a partial and a ViewComponent can both call it
  # unchanged. See "Renderer boundary" in the design spec.
  class Presenter
    class << self
      def resource(klass = nil)
        @resource = klass if klass
        return @resource if defined?(@resource) && @resource

        superclass.respond_to?(:resource) ? superclass.resource : nil
      end
    end

    attr_reader :view_context, :options

    def initialize(view_context:, blocks: {}, **options)
      @view_context = view_context
      @blocks       = (blocks || {}).transform_keys(&:to_sym)
      @options      = options
    end

    # Resolution order: a call-site block, then a cell_<name> method, then the
    # shared Value.display.
    def cell(column, record)
      if (block = @blocks[column.name])
        return @view_context.capture(record, &block)
      end

      # method_defined?, NOT respond_to? — this object delegates missing methods
      # to the view, so respond_to? would consult the view too and a helper
      # named cell_<column> would silently become a cell override.
      method_name = :"cell_#{column.name}"
      return public_send(method_name, record) if self.class.method_defined?(method_name)

      ResourceCore::Value.display(record, column.name, column.value_spec)
    end

    private

    def method_missing(name, *args, &block)
      return super unless @view_context.respond_to?(name)

      @view_context.public_send(name, *args, &block)
    end

    def respond_to_missing?(name, include_private = false)
      @view_context.respond_to?(name, include_private) || super
    end
  end
end
