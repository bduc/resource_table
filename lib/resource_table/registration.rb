module ResourceTable
  # A field type's `partial` belongs to whichever renderer registered it first,
  # so the table keeps its own map rather than fighting resource_form for that
  # one attribute. Anything absent falls through to the generic cell.
  CELL_PARTIALS = {
    boolean: "boolean",
    lookup_one: "lookup_one"
  }.freeze

  def self.cell_partial_for(type_name)
    CELL_PARTIALS.fetch(type_name&.to_sym, "cell")
  end

  # Registered at boot so a typo raises then, rather than at render time in
  # whichever view happens to use it.
  def self.register_field_types!
    ResourceCore.register_renderer :table, options: []

    ResourceCore.register_namespace :index, %i[sortable width align link label format default flex]

    # Both engines register the theme name :daisyui, parentless. Their partial
    # paths differ by prefix (resource_form/daisyui/form/ versus
    # resource_table/daisyui/table/), so the duplicate registration is
    # idempotent and deliberate — do not "fix" it by renaming one of them.
    ResourceCore.register_theme :daisyui
  end
end
