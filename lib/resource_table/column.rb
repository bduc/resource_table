module ResourceTable
  # One resolved column: everything the head and cell partials need, decided
  # before any rendering happens.
  class Column
    attr_reader :name, :spec, :width

    def initialize(name:, spec: nil, width: nil, flex: false, autosize: false, model_class: nil)
      @name        = name.to_sym
      @spec        = spec || {}
      @width       = width
      @flex        = flex
      @autosize    = autosize
      @model_class = model_class
    end

    # The :index namespace, or an empty hash. `index: false` reads as {} here —
    # such a field never becomes a Column at all (see Table#pickable).
    def index_spec
      value = @spec[:index]
      value.is_a?(Hash) ? value : {}
    end

    def label
      index_spec[:label] ||
        @spec[:label] ||
        @model_class&.human_attribute_name(@name) ||
        @name.to_s.humanize
    end

    def sortable?
      value = index_spec[:sortable]
      value == true || ((value.is_a?(String) || value.is_a?(Symbol)) && value.present?)
    end

    # Always a declared value — never anything derived from a request param.
    def sort_expression
      value = index_spec[:sortable]
      value == true ? @name.to_s : value.to_s
    end

    def align
      index_spec[:align]
    end

    def link
      index_spec[:link]
    end

    def flex?
      @flex
    end

    def autosize?
      @autosize
    end

    def partial
      ResourceTable.cell_partial_for(@spec[:as])
    end

    # What Value.display is handed: the field spec, with the index namespace's
    # own format winning where it sets one.
    def value_spec
      format = index_spec[:format]
      format ? @spec.merge(format: format) : @spec
    end
  end
end
