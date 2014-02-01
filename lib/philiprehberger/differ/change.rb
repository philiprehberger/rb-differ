# frozen_string_literal: true

module Philiprehberger
  module Differ
    class Change
      attr_reader :path, :type, :old_value, :new_value

      def initialize(path:, type:, old_value: nil, new_value: nil)
        @path = path
        @type = type
        @old_value = old_value
        @new_value = new_value
      end

      def to_s
        case type
        when :added   then "Added #{path}: #{new_value.inspect}"
        when :removed then "Removed #{path}: #{old_value.inspect}"
        when :changed then "Changed #{path}: #{old_value.inspect} -> #{new_value.inspect}"
        end
      end

      def to_h
        { path: path, type: type, old_value: old_value, new_value: new_value }
      end
    end
  end
end
