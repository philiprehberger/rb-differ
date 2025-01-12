# frozen_string_literal: true

require_relative 'differ/version'
require_relative 'differ/change'
require_relative 'differ/changeset'
require_relative 'differ/comparator'
require_relative 'differ/formatters'
require_relative 'differ/similarity'

module Philiprehberger
  module Differ
    class Error < StandardError; end

    def self.diff(old_val, new_val, ignore: [], array_key: nil)
      changes = Comparator.call(old_val, new_val, ignore: ignore, array_key: array_key)
      Changeset.new(changes)
    end

    def self.similarity(old_val, new_val, ignore: [], array_key: nil)
      Similarity.call(old_val, new_val, ignore: ignore, array_key: array_key)
    end

    # Filter changeset to only changes under a specific path prefix
    #
    # @param changeset [Changeset] the changeset to filter
    # @param path [String] the path prefix to filter by
    # @return [Changeset] new changeset with only matching changes
    def self.subset(changeset, path)
      prefix = path.to_s
      filtered = changeset.changes.select do |change|
        change.path.to_s == prefix || change.path.to_s.start_with?("#{prefix}.")
      end
      Changeset.new(filtered)
    end

    # Perform a three-way merge with conflict detection
    #
    # @param base [Hash] the common ancestor
    # @param theirs [Hash] their changes
    # @param ours [Hash] our changes
    # @return [Hash] { merged: Hash, conflicts: Array }
    def self.merge(base, theirs, ours)
      their_changes = Comparator.call(base, theirs)
      our_changes = Comparator.call(base, ours)

      conflicts = detect_conflicts(their_changes, our_changes)
      conflict_paths = conflicts.map { |c| c[:path] }

      merged = deep_dup(base)
      (their_changes + our_changes).each do |change|
        next if conflict_paths.include?(change.path)

        apply_merge_change(merged, change)
      end

      { merged: merged, conflicts: conflicts }
    end

    # Detect if a changeset contains breaking changes (removals or type changes)
    #
    # @param changeset [Changeset] the changeset to check
    # @return [Boolean] true if breaking changes are detected
    def self.breaking_changes?(changeset)
      changeset.changes.any? do |change|
        change.type == :removed ||
          (change.type == :changed && change.old_value.class != change.new_value.class)
      end
    end

    def self.detect_conflicts(their_changes, our_changes)
      their_paths = their_changes.to_h { |c| [c.path, c] }
      our_paths = our_changes.to_h { |c| [c.path, c] }

      conflicts = []
      their_paths.each do |path, their_change|
        our_change = our_paths[path]
        next unless our_change

        if their_change.new_value != our_change.new_value
          conflicts << { path: path, theirs: their_change.new_value, ours: our_change.new_value }
        end
      end
      conflicts
    end
    private_class_method :detect_conflicts

    def self.apply_merge_change(hash, change)
      keys = change.path.to_s.split('.')
      target = hash
      keys[0..-2].each do |k|
        k = k.to_sym if target.is_a?(Hash) && target.key?(k.to_sym)
        target = target[k]
      end

      key = keys.last
      key = key.to_sym if target.is_a?(Hash) && (target.key?(key.to_sym) || target.keys.any?(Symbol))

      case change.type
      when :added, :changed then target[key] = change.new_value
      when :removed then target.delete(key)
      end
    end
    private_class_method :apply_merge_change

    def self.deep_dup(obj)
      case obj
      when Hash then obj.each_with_object({}) { |(k, v), h| h[k] = deep_dup(v) }
      when Array then obj.map { |v| deep_dup(v) }
      else obj
      end
    end
    private_class_method :deep_dup
  end
end
