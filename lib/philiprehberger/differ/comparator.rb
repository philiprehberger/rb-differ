# frozen_string_literal: true

module Philiprehberger
  module Differ
    class Comparator
      def self.call(old_val, new_val, path: '', ignore: [])
        return [] if ignore.include?(path)

        case [old_val, new_val]
        in [Hash, Hash] then compare_hashes(old_val, new_val, path, ignore)
        in [Array, Array] then compare_arrays(old_val, new_val, path, ignore)
        else compare_scalars(old_val, new_val, path)
        end
      end

      def self.compare_hashes(old_hash, new_hash, path, ignore)
        (old_hash.keys + new_hash.keys).uniq.each_with_object([]) do |key, changes|
          full_path = path.empty? ? key.to_s : "#{path}.#{key}"
          next if ignore.include?(full_path)

          changes.concat(hash_key_diff(old_hash, new_hash, key, full_path, ignore))
        end
      end

      def self.hash_key_diff(old_hash, new_hash, key, full_path, ignore)
        if !old_hash.key?(key)
          [Change.new(path: full_path, type: :added, new_value: new_hash[key])]
        elsif !new_hash.key?(key)
          [Change.new(path: full_path, type: :removed, old_value: old_hash[key])]
        else
          call(old_hash[key], new_hash[key], path: full_path, ignore: ignore)
        end
      end

      def self.compare_arrays(old_arr, new_arr, path, ignore)
        [old_arr.length, new_arr.length].max.times.each_with_object([]) do |idx, changes|
          full_path = "#{path}.#{idx}"
          next if ignore.include?(full_path)

          changes.concat(array_idx_diff(old_arr, new_arr, idx, full_path, ignore))
        end
      end

      def self.array_idx_diff(old_arr, new_arr, idx, full_path, ignore)
        if idx >= old_arr.length
          [Change.new(path: full_path, type: :added, new_value: new_arr[idx])]
        elsif idx >= new_arr.length
          [Change.new(path: full_path, type: :removed, old_value: old_arr[idx])]
        else
          call(old_arr[idx], new_arr[idx], path: full_path, ignore: ignore)
        end
      end

      def self.compare_scalars(old_val, new_val, path)
        return [] if old_val == new_val

        [Change.new(path: path, type: :changed, old_value: old_val, new_value: new_val)]
      end

      private_class_method :compare_hashes, :compare_arrays, :compare_scalars,
                           :hash_key_diff, :array_idx_diff
    end
  end
end
