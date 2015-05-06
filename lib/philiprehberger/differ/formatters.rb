# frozen_string_literal: true

require 'json'

module Philiprehberger
  module Differ
    module Formatters
      module Text
        def self.format(changeset)
          changeset.changes.map { |c| format_change(c) }.join("\n")
        end

        def self.format_change(change)
          case change.type
          when :added   then "+ #{change.path}: #{change.new_value.inspect}"
          when :removed then "- #{change.path}: #{change.old_value.inspect}"
          when :changed then changed_line(change)
          end
        end

        def self.changed_line(change)
          "~ #{change.path}: #{change.old_value.inspect} -> #{change.new_value.inspect}"
        end

        private_class_method :format_change, :changed_line
      end

      module JsonPatch
        def self.format(changeset)
          changeset.changes.map { |c| format_op(c) }
        end

        def self.format_op(change)
          path = "/#{change.path.gsub('.', '/')}"
          case change.type
          when :added   then { op: 'add', path: path, value: change.new_value }
          when :removed then { op: 'remove', path: path }
          when :changed then { op: 'replace', path: path, value: change.new_value }
          end
        end

        private_class_method :format_op
      end
    end
  end
end
