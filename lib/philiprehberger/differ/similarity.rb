# frozen_string_literal: true

module Philiprehberger
  module Differ
    module Similarity
      def self.call(old_val, new_val, ignore: [], array_key: nil)
        total = count_fields(old_val, new_val, ignore: ignore, array_key: array_key)
        return 1.0 if total.zero?

        changes = Comparator.call(old_val, new_val, ignore: ignore, array_key: array_key)
        changed = changes.length
        (total - changed).to_f / total
      end

      def self.count_fields(old_val, new_val, ignore: [], array_key: nil, path: '')
        case [old_val, new_val]
        in [Hash, Hash] then count_hash_fields(old_val, new_val, ignore, array_key, path)
        in [Array, Array] then count_array_fields(old_val, new_val, ignore, array_key, path)
        else 1
        end
      end

      def self.count_hash_fields(old_hash, new_hash, ignore, array_key, path)
        opts = { ignore: ignore, array_key: array_key }
        (old_hash.keys + new_hash.keys).uniq.sum do |key|
          full_path = path.empty? ? key.to_s : "#{path}.#{key}"
          next 0 if ignore.any? { |p| p.to_s == full_path }

          count_hash_key(old_hash, new_hash, key, full_path, opts)
        end
      end

      def self.count_hash_key(old_hash, new_hash, key, full_path, opts)
        if old_hash.key?(key) && new_hash.key?(key)
          count_fields(old_hash[key], new_hash[key], ignore: opts[:ignore], array_key: opts[:array_key], path: full_path)
        else
          1
        end
      end

      def self.count_array_fields(old_arr, new_arr, ignore, array_key, path)
        if array_key && old_arr.first.is_a?(Hash)
          count_keyed_array(old_arr, new_arr, ignore, array_key, path)
        else
          count_indexed_array(old_arr, new_arr, ignore, array_key, path)
        end
      end

      def self.count_indexed_array(old_arr, new_arr, ignore, array_key, path)
        [old_arr.length, new_arr.length].max.times.sum do |idx|
          full_path = "#{path}.#{idx}"
          next 0 if ignore.any? { |p| p.to_s == full_path }
          next 1 if idx >= old_arr.length || idx >= new_arr.length

          count_fields(old_arr[idx], new_arr[idx], ignore: ignore, array_key: array_key, path: full_path)
        end
      end

      def self.count_keyed_array(old_arr, new_arr, ignore, array_key, path)
        old_map = old_arr.to_h { |item| [item[array_key], item] }
        new_map = new_arr.to_h { |item| [item[array_key], item] }
        count_keyed_array_fields(old_map, new_map, ignore, array_key, path)
      end

      def self.count_keyed_array_fields(old_map, new_map, ignore, array_key, path)
        (old_map.keys + new_map.keys).uniq.sum do |key_val|
          full_path = "#{path}.#{key_val}"
          next 1 unless old_map.key?(key_val) && new_map.key?(key_val)

          count_fields(old_map[key_val], new_map[key_val], ignore: ignore, array_key: array_key, path: full_path)
        end
      end

      private_class_method :count_fields, :count_hash_fields, :count_hash_key,
                           :count_array_fields, :count_indexed_array, :count_keyed_array,
                           :count_keyed_array_fields
    end
  end
end
