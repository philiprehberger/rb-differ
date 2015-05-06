# frozen_string_literal: true

module Philiprehberger
  module Differ
    class Changeset
      attr_reader :changes

      def initialize(changes = [])
        @changes = changes
      end

      def changed?
        !@changes.empty?
      end

      def added
        @changes.select { |c| c.type == :added }
      end

      def removed
        @changes.select { |c| c.type == :removed }
      end

      def changed
        @changes.select { |c| c.type == :changed }
      end

      def apply(hash)
        result = deep_dup(hash)
        @changes.each { |c| apply_change(result, c) }
        result
      end

      def revert(hash)
        result = deep_dup(hash)
        @changes.each { |c| revert_change(result, c) }
        result
      end

      def to_h
        { changes: @changes.map(&:to_h) }
      end

      def to_text
        Formatters::Text.format(self)
      end

      def to_json_patch
        Formatters::JsonPatch.format(self)
      end

      private

      def apply_change(hash, change)
        keys = parse_path(change.path)
        target = dig_to_parent(hash, keys)
        key = coerce_key(target, keys.last)

        case change.type
        when :added, :changed then target[key] = change.new_value
        when :removed         then target.is_a?(Hash) ? target.delete(key) : target.delete_at(key)
        end
      end

      def revert_change(hash, change)
        keys = parse_path(change.path)
        target = dig_to_parent(hash, keys)
        key = coerce_key(target, keys.last)

        case change.type
        when :added then target.is_a?(Hash) ? target.delete(key) : target.delete_at(key)
        when :removed, :changed then target[key] = change.old_value
        end
      end

      def parse_path(path)
        path.to_s.split('.')
      end

      def dig_to_parent(hash, keys)
        parent = hash
        keys[0..-2].each { |k| parent = parent[coerce_key(parent, k)] }
        parent
      end

      def coerce_key(target, key)
        return key.to_i if target.is_a?(Array)
        return key.to_sym if target.is_a?(Hash) && (target.key?(key.to_sym) || symbol_keys?(target))

        key
      end

      def symbol_keys?(hash)
        hash.keys.any?(Symbol)
      end

      def deep_dup(obj)
        case obj
        when Hash  then obj.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
        when Array then obj.map { |v| deep_dup(v) }
        else obj
        end
      end
    end
  end
end
