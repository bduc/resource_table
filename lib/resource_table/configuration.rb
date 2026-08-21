module ResourceTable
  # Host-supplied wiring. The engine ships no store, no route and no notion of
  # who "the user" is — an app sets all three.
  class Configuration
    # Anything answering read(owner, key) / write(owner, key, layout).
    attr_accessor :layout_store

    # Where the Stimulus controller PATCHes a changed layout.
    attr_accessor :layout_url

    # Method sent to the view to find the layout's owner.
    attr_accessor :owner_method

    def initialize
      @layout_store = nil
      @layout_url   = "/table-layout"
      @owner_method = :current_user
    end
  end
end
