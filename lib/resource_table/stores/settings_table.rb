module ResourceTable
  module Stores
    # One row per (owner, key).
    #
    # The default for an app with more than a couple of tables: a single jsonb
    # column makes every write a read-modify-write of all layouts, so two tabs
    # adjusting two tables clobber each other, and loading the owner drags the
    # whole blob into memory on every request.
    class SettingsTable
      def initialize(model:, owner_association: :user, key_column: :key, value_column: :value)
        @model             = model
        @owner_association = owner_association
        @key_column        = key_column
        @value_column      = value_column
      end

      def read(owner, key)
        return nil if owner.nil?

        record = scope(owner).find_by(@key_column => key.to_s)
        return nil if record.nil?

        value = record.public_send(@value_column)
        value.presence && stringify(value)
      end

      def write(owner, key, layout)
        return nil if owner.nil?

        record = scope(owner).find_or_initialize_by(@key_column => key.to_s)
        record.public_send(:"#{@value_column}=", stringify(layout))
        record.save!
        record.public_send(@value_column)
      end

      private

      def scope(owner)
        @model.where(@owner_association => owner)
      end

      # jsonb hands back string keys, so a layout written with symbols must read
      # back the same way whether or not it has been through the database yet.
      def stringify(value)
        value.to_h.deep_transform_keys(&:to_s)
      end
    end
  end
end
