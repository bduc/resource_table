module ResourceTable
  # The boundary between a request parameter and an ORDER BY.
  #
  # `sortable: "departments.name"` means a param selects among SQL fragments.
  # The param may only ever NAME a column the resource declared sortable; the
  # expression itself comes from that declaration. A param that names nothing
  # declared produces no ordering at all — it is never interpolated, escaped or
  # sanitised, because it never reaches SQL in the first place.
  class Sort
    DIRECTIONS = %w[asc desc].freeze

    attr_reader :field, :direction

    def self.none
      new(field: nil, expression: nil, direction: "asc")
    end

    def self.from_params(params, columns)
      params = normalize(params)
      requested = params["sort"].presence
      return none if requested.nil?

      column = Array(columns).find { |c| c.sortable? && c.name.to_s == requested.to_s }
      return none if column.nil?

      direction = params["dir"].to_s.downcase
      direction = "asc" unless DIRECTIONS.include?(direction)

      new(field: column.name, expression: column.sort_expression, direction: direction)
    end

    def initialize(field:, expression:, direction:)
      @field      = field
      @expression = expression
      @direction  = direction
    end

    def active?
      !@field.nil?
    end

    # Safe to mark as trusted SQL: @expression is a resource declaration and
    # @direction is one of two literals. Neither is request data.
    def order_clause
      return nil unless active?

      Arel.sql("#{@expression} #{@direction}")
    end

    def direction_for(column)
      return nil unless active? && column.name == @field

      @direction
    end

    def next_direction_for(column)
      direction_for(column) == "asc" ? "desc" : "asc"
    end

    # The caller hands us the controller's real params, so this is almost always
    # an ActionController::Parameters, whose #to_h RAISES UnfilteredParameters
    # unless the object has been permitted. Reaching for #to_unsafe_h is correct
    # precisely because nothing here is trusted: "sort" must match a column the
    # resource DECLARED sortable, and "dir" is whitelisted against two literals.
    # Only "sort" and "dir" may ever be read from this hash — reading any other
    # key here means revisiting the #to_unsafe_h decision above.
    def self.normalize(params)
      return {} if params.nil?

      hash = params.respond_to?(:to_unsafe_h) ? params.to_unsafe_h : params.to_h
      hash.transform_keys(&:to_s)
    end
    private_class_method :normalize
  end
end
