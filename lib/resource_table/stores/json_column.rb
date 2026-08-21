module ResourceTable
  module Stores
    # Every layout for an owner in one jsonb column.
    #
    # Fine for an app with one or two tables; see SettingsTable for why it stops
    # being fine after that.
    class JsonColumn
      def initialize(column:)
        @column = column
      end

      def read(owner, key)
        return nil if owner.nil?

        value = all(owner)[key.to_s]
        value.presence && stringify(value)
      end

      def write(owner, key, layout)
        return nil if owner.nil?

        merged = all(owner).merge(key.to_s => stringify(layout))
        owner.update!(@column => merged)
        merged[key.to_s]
      end

      private

      def all(owner)
        (owner.public_send(@column) || {}).to_h
      end

      def stringify(value)
        value.to_h.deep_transform_keys(&:to_s)
      end
    end
  end
end
