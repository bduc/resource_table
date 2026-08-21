module ResourceTable
  module Stores
    module_function

    # jsonb hands a layout back with string keys, so a layout written with
    # symbols must read back the same way whether or not it has been through
    # the database yet. Recurses through hashes and arrays alike: a symbol
    # nested inside an array (e.g. `visible: %i[title]`) is exactly the shape
    # `deep_transform_keys` — a keys-only, hashes-only walk — misses.
    def normalize_layout(value)
      case value
      when Hash
        value.each_with_object({}) { |(k, v), h| h[k.to_s] = normalize_layout(v) }
      when Array
        value.map { |v| normalize_layout(v) }
      when Symbol
        value.to_s
      else
        value
      end
    end
  end
end
