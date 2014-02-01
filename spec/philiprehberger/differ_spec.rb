# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Philiprehberger::Differ do
  it 'has a version number' do
    expect(Philiprehberger::Differ::VERSION).not_to be_nil
  end

  describe '.diff' do
    it 'detects changed values in a flat hash' do
      old_hash = { name: 'Alice', age: 30 }
      new_hash = { name: 'Alice', age: 31 }
      result = described_class.diff(old_hash, new_hash)

      expect(result.changes.length).to eq(1)
      expect(result.changes.first.type).to eq(:changed)
      expect(result.changes.first.path).to eq('age')
    end

    it 'detects added keys' do
      old_hash = { name: 'Alice' }
      new_hash = { name: 'Alice', email: 'alice@example.com' }
      result = described_class.diff(old_hash, new_hash)

      expect(result.added.length).to eq(1)
      expect(result.added.first.path).to eq('email')
      expect(result.added.first.new_value).to eq('alice@example.com')
    end

    it 'detects removed keys' do
      old_hash = { name: 'Alice', age: 30 }
      new_hash = { name: 'Alice' }
      result = described_class.diff(old_hash, new_hash)

      expect(result.removed.length).to eq(1)
      expect(result.removed.first.path).to eq('age')
      expect(result.removed.first.old_value).to eq(30)
    end

    it 'handles nested hashes with dot-notation paths' do
      old_hash = { user: { address: { city: 'Berlin' } } }
      new_hash = { user: { address: { city: 'Vienna' } } }
      result = described_class.diff(old_hash, new_hash)

      expect(result.changes.first.path).to eq('user.address.city')
      expect(result.changes.first.old_value).to eq('Berlin')
      expect(result.changes.first.new_value).to eq('Vienna')
    end

    it 'handles array changes' do
      old_val = { tags: %w[ruby python] }
      new_val = { tags: %w[ruby go] }
      result = described_class.diff(old_val, new_val)

      expect(result.changed.length).to eq(1)
      expect(result.changed.first.path).to eq('tags.1')
    end

    it 'returns changed? true when differences exist' do
      result = described_class.diff({ a: 1 }, { a: 2 })
      expect(result.changed?).to be true
    end

    it 'returns changed? false when identical' do
      result = described_class.diff({ a: 1 }, { a: 1 })
      expect(result.changed?).to be false
    end

    it 'excludes paths listed in ignore' do
      old_hash = { name: 'Alice', age: 30, id: 1 }
      new_hash = { name: 'Bob', age: 31, id: 2 }
      result = described_class.diff(old_hash, new_hash, ignore: ['id'])

      paths = result.changes.map(&:path)
      expect(paths).not_to include('id')
      expect(paths).to contain_exactly('name', 'age')
    end
  end

  describe 'Changeset' do
    it 'applies changes to produce new version' do
      old_hash = { name: 'Alice', age: 30 }
      new_hash = { name: 'Bob', age: 30, email: 'bob@example.com' }
      changeset = described_class.diff(old_hash, new_hash)

      result = changeset.apply(old_hash)
      expect(result[:name]).to eq('Bob')
      expect(result[:email]).to eq('bob@example.com')
    end

    it 'reverts changes to produce old version' do
      old_hash = { name: 'Alice', age: 30 }
      new_hash = { name: 'Bob', age: 31 }
      changeset = described_class.diff(old_hash, new_hash)

      result = changeset.revert(new_hash)
      expect(result[:name]).to eq('Alice')
      expect(result[:age]).to eq(30)
    end

    it 'serializes to a hash' do
      changeset = described_class.diff({ a: 1 }, { a: 2 })
      hash = changeset.to_h

      expect(hash).to have_key(:changes)
      expect(hash[:changes].first[:type]).to eq(:changed)
    end
  end
end
