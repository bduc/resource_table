module ResourceTable
  # Resource + stored layout + request params → which columns, in what order, at
  # what width, sorted how. No view, no browser: the whole interesting decision
  # is testable on its own.
  class Table
    attr_reader :resource_class

    def initialize(resource_class:, layout: nil, params: {})
      @resource_class = resource_class
      @layout         = stringify(layout)
      @params         = params || {}
    end

    # Every column a user may switch on, in declaration order. `index: false`
    # is excluded here and so can never be reached, by the picker or by a stale
    # stored layout.
    def pickable
      @pickable ||= specs.map { |name, spec| build(name, spec) }
    end

    # The visible columns, in the user's order if they have one.
    def columns
      @columns ||= begin
        by_name = pickable.index_by(&:name)
        ordered = visible_names.filter_map { |name| by_name[name] }
        ordered.presence || default_columns
      end
    end

    def sort
      # Deliberately `columns` (visible), not `pickable` (all offerable): a
      # sortable-but-hidden column stays unsortable via URL, so a bookmarked
      # `?sort=` link degrades to the default order once that column is
      # hidden, rather than ordering by a column the user cannot see.
      @sort ||= Sort.from_params(@params, columns)
    end

    private

    def specs
      @resource_class.fields.reject { |_name, spec| spec[:index] == false }
    end

    def default_columns
      pickable.reject { |column| column.index_spec[:default] == false }
    end

    def visible_names
      Array(@layout["visible"]).map(&:to_sym)
    end

    def widths
      @widths ||= (@layout["widths"] || {}).transform_keys(&:to_sym)
    end

    def build(name, spec)
      index = spec[:index].is_a?(Hash) ? spec[:index] : {}
      flex  = index[:flex] == true
      width = widths[name] || index[:width]

      Column.new(
        name: name,
        spec: spec,
        width: width,
        flex: flex,
        # Measured to its content on first render, then persisted — so this is
        # true exactly once per fresh table, and never for the slack absorber.
        autosize: !flex && width.nil?,
        model_class: @resource_class.model_class
      )
    end

    def stringify(layout)
      return {} if layout.blank?

      layout.to_h.transform_keys(&:to_s)
    end
  end
end
