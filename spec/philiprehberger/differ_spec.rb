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
  end

  describe 'ignore paths' do
    it 'excludes paths listed in ignore' do
      old_hash = { name: 'Alice', age: 30, id: 1 }
      new_hash = { name: 'Bob', age: 31, id: 2 }
      result = described_class.diff(old_hash, new_hash, ignore: ['id'])

      paths = result.changes.map(&:path)
      expect(paths).not_to include('id')
      expect(paths).to contain_exactly('name', 'age')
    end

    it 'ignores symbol keys in ignore list' do
      old_hash = { name: 'Alice', updated_at: '2024-01-01' }
      new_hash = { name: 'Bob', updated_at: '2024-06-01' }
      result = described_class.diff(old_hash, new_hash, ignore: [:updated_at])

      paths = result.changes.map(&:path)
      expect(paths).to contain_exactly('name')
    end

    it 'ignores nested paths as dot-notation strings' do
      old_hash = { user: { name: 'Alice', email: 'old@ex.com' } }
      new_hash = { user: { name: 'Bob', email: 'new@ex.com' } }
      result = described_class.diff(old_hash, new_hash, ignore: ['user.email'])

      paths = result.changes.map(&:path)
      expect(paths).to contain_exactly('user.name')
    end

    it 'ignores multiple nested paths' do
      old_hash = { user: { name: 'A', email: 'a@x.com' }, metadata: { version: 1 } }
      new_hash = { user: { name: 'B', email: 'b@x.com' }, metadata: { version: 2 } }
      result = described_class.diff(old_hash, new_hash, ignore: ['user.email', :metadata])

      paths = result.changes.map(&:path)
      expect(paths).to contain_exactly('user.name')
    end
  end

  describe '.similarity' do
    it 'returns 1.0 for identical hashes' do
      data = { name: 'Alice', age: 30 }
      expect(described_class.similarity(data, data)).to eq(1.0)
    end

    it 'returns 0.0 when all fields differ' do
      old_hash = { name: 'Alice', age: 30 }
      new_hash = { name: 'Bob', age: 25 }
      expect(described_class.similarity(old_hash, new_hash)).to eq(0.0)
    end

    it 'returns ratio of unchanged to total fields' do
      old_hash = { a: 1, b: 2, c: 3, d: 4 }
      new_hash = { a: 1, b: 2, c: 30, d: 40 }
      expect(described_class.similarity(old_hash, new_hash)).to eq(0.5)
    end

    it 'handles nested hashes' do
      old_hash = { user: { name: 'Alice', age: 30 } }
      new_hash = { user: { name: 'Alice', age: 31 } }
      expect(described_class.similarity(old_hash, new_hash)).to eq(0.5)
    end

    it 'handles added fields' do
      old_hash = { a: 1 }
      new_hash = { a: 1, b: 2 }
      expect(described_class.similarity(old_hash, new_hash)).to eq(0.5)
    end

    it 'returns 1.0 for two empty hashes' do
      expect(described_class.similarity({}, {})).to eq(1.0)
    end

    it 'respects ignore option' do
      old_hash = { a: 1, b: 2, c: 3 }
      new_hash = { a: 1, b: 20, c: 30 }
      expect(described_class.similarity(old_hash, new_hash, ignore: ['c'])).to eq(0.5)
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

  describe '#to_text' do
    it 'formats added changes with + prefix' do
      changeset = described_class.diff({ name: 'Alice' }, { name: 'Alice', age: 30 })
      text = changeset.to_text

      expect(text).to include('+ age: 30')
    end

    it 'formats removed changes with - prefix' do
      changeset = described_class.diff({ name: 'Alice', age: 30 }, { name: 'Alice' })
      text = changeset.to_text

      expect(text).to include('- age: 30')
    end

    it 'formats changed values with ~ prefix' do
      changeset = described_class.diff({ name: 'Alice' }, { name: 'Bob' })
      text = changeset.to_text

      expect(text).to include('~ name: "Alice" -> "Bob"')
    end

    it 'renders multiple changes on separate lines' do
      changeset = described_class.diff({ a: 1, b: 2 }, { a: 10, b: 20 })
      lines = changeset.to_text.split("\n")

      expect(lines.length).to eq(2)
    end

    it 'returns empty string when no changes' do
      changeset = described_class.diff({ a: 1 }, { a: 1 })
      expect(changeset.to_text).to eq('')
    end
  end

  describe '#to_json_patch' do
    it 'returns add operation for added fields' do
      changeset = described_class.diff({ name: 'Alice' }, { name: 'Alice', age: 30 })
      ops = changeset.to_json_patch

      expect(ops).to include({ op: 'add', path: '/age', value: 30 })
    end

    it 'returns remove operation for removed fields' do
      changeset = described_class.diff({ name: 'Alice', age: 30 }, { name: 'Alice' })
      ops = changeset.to_json_patch

      expect(ops).to include({ op: 'remove', path: '/age' })
    end

    it 'returns replace operation for changed fields' do
      changeset = described_class.diff({ name: 'Alice' }, { name: 'Bob' })
      ops = changeset.to_json_patch

      expect(ops).to include({ op: 'replace', path: '/name', value: 'Bob' })
    end

    it 'uses slash-separated paths for nested fields' do
      changeset = described_class.diff({ user: { city: 'Berlin' } }, { user: { city: 'Vienna' } })
      ops = changeset.to_json_patch

      expect(ops.first[:path]).to eq('/user/city')
    end

    it 'returns empty array when no changes' do
      changeset = described_class.diff({ a: 1 }, { a: 1 })
      expect(changeset.to_json_patch).to eq([])
    end

    it 'handles multiple operations' do
      old_hash = { name: 'Alice', age: 30 }
      new_hash = { name: 'Bob', email: 'bob@ex.com' }
      ops = described_class.diff(old_hash, new_hash).to_json_patch

      expect(ops.length).to eq(3)
      op_types = ops.map { |o| o[:op] }
      expect(op_types).to include('replace', 'remove', 'add')
    end
  end

  describe 'array_key option' do
    it 'matches array elements by key field' do
      old_data = { users: [{ id: 1, name: 'Alice' }, { id: 2, name: 'Bob' }] }
      new_data = { users: [{ id: 2, name: 'Bobby' }, { id: 1, name: 'Alice' }] }
      result = described_class.diff(old_data, new_data, array_key: :id)

      expect(result.changes.length).to eq(1)
      expect(result.changes.first.path).to eq('users.2.name')
      expect(result.changes.first.old_value).to eq('Bob')
      expect(result.changes.first.new_value).to eq('Bobby')
    end

    it 'detects added elements by key' do
      old_data = { items: [{ id: 1, v: 'a' }] }
      new_data = { items: [{ id: 1, v: 'a' }, { id: 2, v: 'b' }] }
      result = described_class.diff(old_data, new_data, array_key: :id)

      expect(result.added.length).to eq(1)
      expect(result.added.first.new_value).to eq({ id: 2, v: 'b' })
    end

    it 'detects removed elements by key' do
      old_data = { items: [{ id: 1, v: 'a' }, { id: 2, v: 'b' }] }
      new_data = { items: [{ id: 1, v: 'a' }] }
      result = described_class.diff(old_data, new_data, array_key: :id)

      expect(result.removed.length).to eq(1)
      expect(result.removed.first.old_value).to eq({ id: 2, v: 'b' })
    end

    it 'falls back to index comparison for non-hash arrays' do
      old_data = { tags: %w[ruby python] }
      new_data = { tags: %w[ruby go] }
      result = described_class.diff(old_data, new_data, array_key: :id)

      expect(result.changed.length).to eq(1)
      expect(result.changed.first.path).to eq('tags.1')
    end

    it 'handles completely different sets of keyed elements' do
      old_data = { items: [{ id: 1, v: 'a' }] }
      new_data = { items: [{ id: 2, v: 'b' }] }
      result = described_class.diff(old_data, new_data, array_key: :id)

      expect(result.removed.length).to eq(1)
      expect(result.added.length).to eq(1)
    end

    it 'works with similarity calculation' do
      old_data = { users: [{ id: 1, name: 'Alice' }, { id: 2, name: 'Bob' }] }
      new_data = { users: [{ id: 2, name: 'Bobby' }, { id: 1, name: 'Alice' }] }
      score = described_class.similarity(old_data, new_data, array_key: :id)

      expect(score).to be > 0.0
      expect(score).to be < 1.0
    end
  end
end
