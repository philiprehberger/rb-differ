# frozen_string_literal: true

require_relative 'differ/version'
require_relative 'differ/change'
require_relative 'differ/changeset'
require_relative 'differ/comparator'

module Philiprehberger
  module Differ
    class Error < StandardError; end

    def self.diff(old_val, new_val, ignore: [])
      changes = Comparator.call(old_val, new_val, ignore: ignore)
      Changeset.new(changes)
    end
  end
end
