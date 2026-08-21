module ResourceTable
  # Collects the per-call-site overrides yielded by resource_table_for.
  #
  # Blocks are stored, never executed here — a cell block runs once per row,
  # at render time, through the view's own capture.
  class Builder
    attr_reader :cell_blocks, :actions_block

    def initialize
      @cell_blocks = {}
      @actions_block = nil
    end

    def cell(name, &block)
      @cell_blocks[name.to_sym] = block
    end

    def actions(&block)
      @actions_block = block
    end
  end
end
