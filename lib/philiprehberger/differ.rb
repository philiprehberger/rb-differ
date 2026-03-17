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
  end
end
