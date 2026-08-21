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

    # Whether a call-site block or a cell_<name> method overrides this column.
    # A specialised cell partial (boolean, lookup_one) renders its own markup only
    # when nothing overrides it — otherwise the override wins, as it does for the
    # generic cell.
    def overridden?(column)
      @blocks.key?(column.name) || self.class.method_defined?(:"cell_#{column.name}")
    end

    # The URL for a record's own show page, or nil if none can be generated —
    # a model with no route (lookup_one's associated record) or none mounted
    # for this record's controller/action (link: :self). Both the lookup_one
    # and the generic cell partial fall back to plain text rather than
    # letting url_for raise and take down the whole page over one cell.
    #
    # Rescued narrowly: ActionController::UrlGenerationError is Rails saying
    # no route matches, NoMethodError is a *_path/*_url helper that was never
    # defined for this model. Anything else is a genuine bug and should still
    # raise.
    def record_url(record)
      @view_context.url_for(record)
    rescue ActionController::UrlGenerationError, NoMethodError
      nil
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
