# frozen_string_literal: true

module Philiprehberger
  module Differ
    class Comparator
      def self.call(old_val, new_val, path: '', ignore: [], array_key: nil)
        return [] if ignored?(path, ignore)

        case [old_val, new_val]
        in [Hash, Hash] then compare_hashes(old_val, new_val, path, ignore, array_key)
        in [Array, Array] then compare_arrays(old_val, new_val, path, ignore, array_key)
        else compare_scalars(old_val, new_val, path)
        end
      end

      def self.ignored?(path, ignore)
        ignore.any? { |p| p.to_s == path }
      end

      def self.compare_hashes(old_hash, new_hash, path, ignore, array_key)
        (old_hash.keys + new_hash.keys).uniq.each_with_object([]) do |key, changes|
          full_path = path.empty? ? key.to_s : "#{path}.#{key}"
          next if ignored?(full_path, ignore)

          changes.concat(hash_key_diff(old_hash, new_hash, key, full_path, ignore, array_key))
        end
      end

      def self.hash_key_diff(old_hash, new_hash, key, full_path, ignore, array_key)
        if !old_hash.key?(key)
          [Change.new(path: full_path, type: :added, new_value: new_hash[key])]
        elsif !new_hash.key?(key)
          [Change.new(path: full_path, type: :removed, old_value: old_hash[key])]
        else
          call(old_hash[key], new_hash[key], path: full_path, ignore: ignore, array_key: array_key)
        end
      end

      def self.compare_arrays(old_arr, new_arr, path, ignore, array_key)
        if array_key && old_arr.first.is_a?(Hash)
          compare_arrays_by_key(old_arr, new_arr, path, ignore, array_key)
        else
          compare_arrays_by_index(old_arr, new_arr, path, ignore, array_key)
        end
      end

      def self.compare_arrays_by_index(old_arr, new_arr, path, ignore, array_key)
        [old_arr.length, new_arr.length].max.times.each_with_object([]) do |idx, changes|
          full_path = "#{path}.#{idx}"
          next if ignored?(full_path, ignore)

          changes.concat(array_idx_diff(old_arr, new_arr, idx, full_path, ignore, array_key))
        end
      end

      def self.array_idx_diff(old_arr, new_arr, idx, full_path, ignore, array_key)
        if idx >= old_arr.length
          [Change.new(path: full_path, type: :added, new_value: new_arr[idx])]
        elsif idx >= new_arr.length
          [Change.new(path: full_path, type: :removed, old_value: old_arr[idx])]
        else
          call(old_arr[idx], new_arr[idx], path: full_path, ignore: ignore, array_key: array_key)
        end
      end

      def self.compare_arrays_by_key(old_arr, new_arr, path, ignore, array_key)
        old_map = index_by_key(old_arr, array_key)
        new_map = index_by_key(new_arr, array_key)
        all_keys = (old_map.keys + new_map.keys).uniq
        all_keys.each_with_object([]) do |key_val, changes|
          changes.concat(keyed_element_diff(old_map, new_map, key_val, path, ignore, array_key))
        end
      end

      def self.index_by_key(arr, key)
        arr.each_with_object({}) { |item, map| map[item[key]] = item }
      end

      def self.keyed_element_diff(old_map, new_map, key_val, path, ignore, array_key)
        full_path = "#{path}.#{key_val}"
        if !old_map.key?(key_val)
          [Change.new(path: full_path, type: :added, new_value: new_map[key_val])]
        elsif !new_map.key?(key_val)
          [Change.new(path: full_path, type: :removed, old_value: old_map[key_val])]
        else
          call(old_map[key_val], new_map[key_val], path: full_path, ignore: ignore, array_key: array_key)
        end
      end

      def self.compare_scalars(old_val, new_val, path)
        return [] if old_val == new_val

        [Change.new(path: path, type: :changed, old_value: old_val, new_value: new_val)]
      end

      private_class_method :compare_hashes, :compare_arrays, :compare_scalars,
                           :hash_key_diff, :array_idx_diff, :ignored?,
                           :compare_arrays_by_index, :compare_arrays_by_key,
                           :index_by_key, :keyed_element_diff
    end
  end
end
