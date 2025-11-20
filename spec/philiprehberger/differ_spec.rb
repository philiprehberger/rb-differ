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

  describe 'edge cases: empty and identical inputs' do
    it 'returns no changes for two empty hashes' do
      result = described_class.diff({}, {})
      expect(result.changed?).to be false
      expect(result.changes).to be_empty
    end

    it 'returns no changes for deeply identical nested hashes' do
      data = { a: { b: { c: [1, 2, 3] } } }
      result = described_class.diff(data, data.dup)
      expect(result.changed?).to be false
    end

    it 'treats empty hash vs non-empty hash as additions' do
      result = described_class.diff({}, { name: 'Alice' })
      expect(result.added.length).to eq(1)
      expect(result.added.first.path).to eq('name')
    end

    it 'treats non-empty hash vs empty hash as removals' do
      result = described_class.diff({ name: 'Alice' }, {})
      expect(result.removed.length).to eq(1)
      expect(result.removed.first.path).to eq('name')
    end

    it 'detects changes from empty array to non-empty array' do
      result = described_class.diff({ items: [] }, { items: [1] })
      expect(result.added.length).to eq(1)
      expect(result.added.first.path).to eq('items.0')
    end

    it 'detects changes from non-empty array to empty array' do
      result = described_class.diff({ items: [1, 2] }, { items: [] })
      expect(result.removed.length).to eq(2)
    end

    it 'returns no changes for two empty arrays' do
      result = described_class.diff({ items: [] }, { items: [] })
      expect(result.changed?).to be false
    end
  end

  describe 'edge cases: nil values' do
    it 'detects change from nil to a value' do
      result = described_class.diff({ a: nil }, { a: 42 })
      expect(result.changed.length).to eq(1)
      expect(result.changed.first.old_value).to be_nil
      expect(result.changed.first.new_value).to eq(42)
    end

    it 'detects change from a value to nil' do
      result = described_class.diff({ a: 42 }, { a: nil })
      expect(result.changed.length).to eq(1)
      expect(result.changed.first.old_value).to eq(42)
      expect(result.changed.first.new_value).to be_nil
    end

    it 'returns no change when both values are nil' do
      result = described_class.diff({ a: nil }, { a: nil })
      expect(result.changed?).to be false
    end
  end

  describe 'edge cases: type mismatches' do
    it 'detects change when hash becomes a scalar' do
      result = described_class.diff({ a: { b: 1 } }, { a: 'string' })
      expect(result.changed.length).to eq(1)
      expect(result.changed.first.path).to eq('a')
    end

    it 'detects change when scalar becomes a hash' do
      result = described_class.diff({ a: 'string' }, { a: { b: 1 } })
      expect(result.changed.length).to eq(1)
      expect(result.changed.first.path).to eq('a')
    end

    it 'detects change when array becomes a scalar' do
      result = described_class.diff({ a: [1, 2] }, { a: 99 })
      expect(result.changed.length).to eq(1)
      expect(result.changed.first.path).to eq('a')
    end

    it 'detects change from integer to string' do
      result = described_class.diff({ a: 1 }, { a: '1' })
      expect(result.changed.length).to eq(1)
    end

    it 'detects change from boolean to integer' do
      result = described_class.diff({ a: true }, { a: 1 })
      expect(result.changed.length).to eq(1)
    end
  end

  describe 'deeply nested structures' do
    it 'detects changes four levels deep' do
      old_hash = { a: { b: { c: { d: 'old' } } } }
      new_hash = { a: { b: { c: { d: 'new' } } } }
      result = described_class.diff(old_hash, new_hash)

      expect(result.changes.length).to eq(1)
      expect(result.changes.first.path).to eq('a.b.c.d')
    end

    it 'detects added key inside nested hash' do
      old_hash = { a: { b: {} } }
      new_hash = { a: { b: { c: 1 } } }
      result = described_class.diff(old_hash, new_hash)

      expect(result.added.length).to eq(1)
      expect(result.added.first.path).to eq('a.b.c')
    end

    it 'detects multiple changes at different nesting levels' do
      old_hash = { x: 1, a: { y: 2, b: { z: 3 } } }
      new_hash = { x: 10, a: { y: 20, b: { z: 30 } } }
      result = described_class.diff(old_hash, new_hash)

      expect(result.changes.length).to eq(3)
      paths = result.changes.map(&:path)
      expect(paths).to contain_exactly('x', 'a.y', 'a.b.z')
    end

    it 'handles arrays nested inside hashes inside arrays' do
      old_val = { data: [{ tags: %w[a b] }] }
      new_val = { data: [{ tags: %w[a c] }] }
      result = described_class.diff(old_val, new_val)

      expect(result.changed.length).to eq(1)
      expect(result.changed.first.path).to eq('data.0.tags.1')
    end
  end

  describe 'Change object' do
    it '#to_s formats added change' do
      change = Philiprehberger::Differ::Change.new(path: 'name', type: :added, new_value: 'Alice')
      expect(change.to_s).to eq('Added name: "Alice"')
    end

    it '#to_s formats removed change' do
      change = Philiprehberger::Differ::Change.new(path: 'age', type: :removed, old_value: 30)
      expect(change.to_s).to eq('Removed age: 30')
    end

    it '#to_s formats changed value' do
      change = Philiprehberger::Differ::Change.new(path: 'name', type: :changed, old_value: 'Alice', new_value: 'Bob')
      expect(change.to_s).to eq('Changed name: "Alice" -> "Bob"')
    end

    it '#to_h returns a hash representation' do
      change = Philiprehberger::Differ::Change.new(path: 'x', type: :added, new_value: 1)
      h = change.to_h
      expect(h).to eq({ path: 'x', type: :added, old_value: nil, new_value: 1 })
    end

    it 'stores all attributes via readers' do
      change = Philiprehberger::Differ::Change.new(path: 'a.b', type: :changed, old_value: 1, new_value: 2)
      expect(change.path).to eq('a.b')
      expect(change.type).to eq(:changed)
      expect(change.old_value).to eq(1)
      expect(change.new_value).to eq(2)
    end
  end

  describe 'Changeset edge cases' do
    it 'apply does not mutate the original hash' do
      old_hash = { name: 'Alice', nested: { value: 1 } }
      new_hash = { name: 'Bob', nested: { value: 2 } }
      changeset = described_class.diff(old_hash, new_hash)

      changeset.apply(old_hash)
      expect(old_hash[:name]).to eq('Alice')
      expect(old_hash[:nested][:value]).to eq(1)
    end

    it 'revert does not mutate the original hash' do
      old_hash = { name: 'Alice' }
      new_hash = { name: 'Bob' }
      changeset = described_class.diff(old_hash, new_hash)

      changeset.revert(new_hash)
      expect(new_hash[:name]).to eq('Bob')
    end

    it 'apply handles removal of keys' do
      old_hash = { name: 'Alice', age: 30 }
      new_hash = { name: 'Alice' }
      changeset = described_class.diff(old_hash, new_hash)

      result = changeset.apply(old_hash)
      expect(result).not_to have_key(:age)
      expect(result[:name]).to eq('Alice')
    end

    it 'revert restores removed keys' do
      old_hash = { name: 'Alice', age: 30 }
      new_hash = { name: 'Alice' }
      changeset = described_class.diff(old_hash, new_hash)

      result = changeset.revert(new_hash)
      expect(result[:age]).to eq(30)
    end

    it 'revert removes added keys' do
      old_hash = { name: 'Alice' }
      new_hash = { name: 'Alice', email: 'a@b.com' }
      changeset = described_class.diff(old_hash, new_hash)

      result = changeset.revert(new_hash)
      expect(result).not_to have_key(:email)
    end

    it 'apply handles nested hash changes' do
      old_hash = { user: { name: 'Alice', address: { city: 'Berlin' } } }
      new_hash = { user: { name: 'Alice', address: { city: 'Vienna' } } }
      changeset = described_class.diff(old_hash, new_hash)

      result = changeset.apply(old_hash)
      expect(result[:user][:address][:city]).to eq('Vienna')
    end

    it 'to_h returns empty changes array for identical inputs' do
      changeset = described_class.diff({ a: 1 }, { a: 1 })
      expect(changeset.to_h).to eq({ changes: [] })
    end
  end

  describe '.similarity edge cases' do
    it 'returns 1.0 for two identical scalars compared at top level' do
      expect(described_class.similarity(42, 42)).to eq(1.0)
    end

    it 'returns 0.0 for two different scalars' do
      expect(described_class.similarity(1, 2)).to eq(0.0)
    end

    it 'returns 1.0 for two identical arrays' do
      old_val = { tags: [1, 2, 3] }
      new_val = { tags: [1, 2, 3] }
      expect(described_class.similarity(old_val, new_val)).to eq(1.0)
    end

    it 'returns correct ratio for arrays with partial changes' do
      old_val = { tags: [1, 2, 3, 4] }
      new_val = { tags: [1, 2, 30, 40] }
      expect(described_class.similarity(old_val, new_val)).to eq(0.5)
    end

    it 'handles similarity with removed fields' do
      old_hash = { a: 1, b: 2 }
      new_hash = { a: 1 }
      score = described_class.similarity(old_hash, new_hash)
      expect(score).to eq(0.5)
    end

    it 'returns 1.0 for two empty arrays' do
      expect(described_class.similarity([], [])).to eq(1.0)
    end

    it 'handles similarity with arrays of different length' do
      old_val = { items: [1] }
      new_val = { items: [1, 2, 3] }
      score = described_class.similarity(old_val, new_val)
      expect(score).to be > 0.0
      expect(score).to be < 1.0
    end
  end

  describe 'string-keyed hashes' do
    it 'detects changes in string-keyed hashes' do
      old_hash = { 'name' => 'Alice', 'age' => 30 }
      new_hash = { 'name' => 'Bob', 'age' => 30 }
      result = described_class.diff(old_hash, new_hash)

      expect(result.changed.length).to eq(1)
      expect(result.changed.first.path).to eq('name')
    end

    it 'detects added keys in string-keyed hashes' do
      old_hash = { 'a' => 1 }
      new_hash = { 'a' => 1, 'b' => 2 }
      result = described_class.diff(old_hash, new_hash)

      expect(result.added.length).to eq(1)
    end
  end

  describe '#to_text edge cases' do
    it 'formats nested path changes correctly' do
      changeset = described_class.diff({ a: { b: 1 } }, { a: { b: 2 } })
      text = changeset.to_text
      expect(text).to include('~ a.b: 1 -> 2')
    end

    it 'formats nil values in text output' do
      changeset = described_class.diff({ a: nil }, { a: 1 })
      text = changeset.to_text
      expect(text).to include('~ a: nil -> 1')
    end
  end

  describe '#to_json_patch edge cases' do
    it 'converts deeply nested paths to slash notation' do
      changeset = described_class.diff({ a: { b: { c: 1 } } }, { a: { b: { c: 2 } } })
      ops = changeset.to_json_patch
      expect(ops.first[:path]).to eq('/a/b/c')
    end

    it 'handles array index paths in json patch format' do
      changeset = described_class.diff({ items: [1, 2] }, { items: [1, 3] })
      ops = changeset.to_json_patch
      expect(ops.first[:path]).to eq('/items/1')
      expect(ops.first[:op]).to eq('replace')
    end
  end

  describe '.diff with many simultaneous change types' do
    it 'detects added, removed, and changed in single diff' do
      old_hash = { a: 1, b: 2, c: 3 }
      new_hash = { a: 10, c: 3, d: 4 }
      result = described_class.diff(old_hash, new_hash)

      expect(result.changed.length).to eq(1)
      expect(result.removed.length).to eq(1)
      expect(result.added.length).to eq(1)
      expect(result.changes.length).to eq(3)
    end
  end

  describe 'array diff with added and removed elements' do
    it 'detects added elements at the end of an array' do
      result = described_class.diff({ a: [1, 2] }, { a: [1, 2, 3, 4] })
      expect(result.added.length).to eq(2)
      paths = result.added.map(&:path)
      expect(paths).to contain_exactly('a.2', 'a.3')
    end

    it 'detects removed elements from the end of an array' do
      result = described_class.diff({ a: [1, 2, 3] }, { a: [1] })
      expect(result.removed.length).to eq(2)
    end
  end

  describe 'Changeset empty initialization' do
    it 'returns false for changed? on a fresh empty changeset' do
      changeset = Philiprehberger::Differ::Changeset.new
      expect(changeset.changed?).to be false
    end

    it 'returns empty arrays for added, removed, and changed filters' do
      changeset = Philiprehberger::Differ::Changeset.new
      expect(changeset.added).to eq([])
      expect(changeset.removed).to eq([])
      expect(changeset.changed).to eq([])
    end

    it 'returns empty changes array in to_h' do
      changeset = Philiprehberger::Differ::Changeset.new
      expect(changeset.to_h).to eq({ changes: [] })
    end

    it 'returns empty string for to_text' do
      changeset = Philiprehberger::Differ::Changeset.new
      expect(changeset.to_text).to eq('')
    end

    it 'returns empty array for to_json_patch' do
      changeset = Philiprehberger::Differ::Changeset.new
      expect(changeset.to_json_patch).to eq([])
    end
  end

  describe 'Change defaults' do
    it 'defaults old_value to nil when not provided' do
      change = Philiprehberger::Differ::Change.new(path: 'x', type: :added, new_value: 1)
      expect(change.old_value).to be_nil
    end

    it 'defaults new_value to nil when not provided' do
      change = Philiprehberger::Differ::Change.new(path: 'x', type: :removed, old_value: 1)
      expect(change.new_value).to be_nil
    end

    it '#to_s returns nil for an unrecognized type' do
      change = Philiprehberger::Differ::Change.new(path: 'x', type: :unknown)
      expect(change.to_s).to be_nil
    end

    it '#to_h includes all fields even when values are nil' do
      change = Philiprehberger::Differ::Change.new(path: 'x', type: :removed, old_value: 'gone')
      expect(change.to_h).to eq({ path: 'x', type: :removed, old_value: 'gone', new_value: nil })
    end
  end

  describe 'apply and revert round-trip' do
    it 'apply produces the new hash from the old hash' do
      old_hash = { a: 1, b: 2, c: 3 }
      new_hash = { a: 10, c: 3, d: 4 }
      changeset = described_class.diff(old_hash, new_hash)

      result = changeset.apply(old_hash)
      expect(result).to eq(new_hash)
    end

    it 'revert produces the old hash from the new hash' do
      old_hash = { a: 1, b: 2, c: 3 }
      new_hash = { a: 10, c: 3, d: 4 }
      changeset = described_class.diff(old_hash, new_hash)

      result = changeset.revert(new_hash)
      expect(result).to eq(old_hash)
    end

    it 'apply then revert returns the original hash' do
      old_hash = { name: 'Alice', score: 100 }
      new_hash = { name: 'Bob', score: 200, rank: 1 }
      changeset = described_class.diff(old_hash, new_hash)

      applied = changeset.apply(old_hash)
      reverted = changeset.revert(applied)
      expect(reverted).to eq(old_hash)
    end
  end

  describe 'apply and revert with arrays' do
    it 'apply handles array element additions' do
      old_hash = { items: [1, 2] }
      new_hash = { items: [1, 2, 3] }
      changeset = described_class.diff(old_hash, new_hash)

      result = changeset.apply(old_hash)
      expect(result[:items]).to eq([1, 2, 3])
    end

    it 'apply handles array element removals' do
      old_hash = { items: [1, 2, 3] }
      new_hash = { items: [1] }
      changeset = described_class.diff(old_hash, new_hash)

      result = changeset.apply(old_hash)
      expect(result[:items][1]).to be_nil
    end

    it 'apply handles array element changes' do
      old_hash = { items: %w[a b c] }
      new_hash = { items: %w[a x c] }
      changeset = described_class.diff(old_hash, new_hash)

      result = changeset.apply(old_hash)
      expect(result[:items]).to eq(%w[a x c])
    end

    it 'revert restores removed array elements' do
      old_hash = { tags: [1, 2, 3] }
      new_hash = { tags: [1] }
      changeset = described_class.diff(old_hash, new_hash)

      result = changeset.revert(new_hash)
      expect(result[:tags][1]).to eq(2)
      expect(result[:tags][2]).to eq(3)
    end
  end

  describe 'scalar comparison at top level' do
    it 'detects change between two different strings' do
      result = described_class.diff('hello', 'world')
      expect(result.changed?).to be true
      expect(result.changed.length).to eq(1)
      expect(result.changed.first.path).to eq('')
    end

    it 'returns no changes for identical strings' do
      result = described_class.diff('same', 'same')
      expect(result.changed?).to be false
    end

    it 'detects change between two different integers' do
      result = described_class.diff(1, 2)
      expect(result.changed?).to be true
    end

    it 'returns no changes for identical integers' do
      result = described_class.diff(42, 42)
      expect(result.changed?).to be false
    end

    it 'detects change between nil and a value' do
      result = described_class.diff(nil, 'something')
      expect(result.changed?).to be true
      expect(result.changed.first.old_value).to be_nil
      expect(result.changed.first.new_value).to eq('something')
    end

    it 'returns no changes for nil vs nil' do
      result = described_class.diff(nil, nil)
      expect(result.changed?).to be false
    end
  end

  describe 'special value types' do
    it 'detects change from float to integer' do
      result = described_class.diff({ v: 1.5 }, { v: 2 })
      expect(result.changed.length).to eq(1)
    end

    it 'detects change between symbols' do
      result = described_class.diff({ s: :foo }, { s: :bar })
      expect(result.changed.length).to eq(1)
      expect(result.changed.first.old_value).to eq(:foo)
      expect(result.changed.first.new_value).to eq(:bar)
    end

    it 'returns no change for identical booleans' do
      result = described_class.diff({ flag: true }, { flag: true })
      expect(result.changed?).to be false
    end

    it 'detects change from false to true' do
      result = described_class.diff({ flag: false }, { flag: true })
      expect(result.changed.length).to eq(1)
    end

    it 'detects change between empty string and non-empty string' do
      result = described_class.diff({ s: '' }, { s: 'hello' })
      expect(result.changed.length).to eq(1)
    end
  end

  describe 'ignore with array_key combined' do
    it 'ignores specified paths when using array_key matching' do
      old_data = { users: [{ id: 1, name: 'Alice', age: 25 }, { id: 2, name: 'Bob', age: 30 }] }
      new_data = { users: [{ id: 1, name: 'Alicia', age: 26 }, { id: 2, name: 'Bobby', age: 31 }] }
      result = described_class.diff(old_data, new_data, array_key: :id, ignore: ['users.1.name', 'users.2.name'])

      paths = result.changes.map(&:path)
      expect(paths).not_to include('users.1.name')
      expect(paths).not_to include('users.2.name')
    end

    it 'similarity respects both ignore and array_key' do
      old_data = { items: [{ id: 1, a: 1, b: 2 }] }
      new_data = { items: [{ id: 1, a: 10, b: 20 }] }
      score_all = described_class.similarity(old_data, new_data, array_key: :id)
      score_ign = described_class.similarity(old_data, new_data, array_key: :id, ignore: ['items.1.b'])

      expect(score_ign).to be >= score_all
    end
  end

  describe 'to_text with mixed change types' do
    it 'includes all three prefixes in a single diff' do
      old_hash = { a: 1, b: 2 }
      new_hash = { a: 10, c: 3 }
      text = described_class.diff(old_hash, new_hash).to_text

      expect(text).to include('~')
      expect(text).to include('-')
      expect(text).to include('+')
    end

    it 'formats hash values in text output' do
      changeset = described_class.diff({ a: { x: 1 } }, { a: 'flat' })
      text = changeset.to_text
      expect(text).to include('~ a:')
      expect(text).to include('{')
    end

    it 'formats array values in text output' do
      changeset = described_class.diff({ a: [1, 2] }, { a: 'flat' })
      text = changeset.to_text
      expect(text).to include('~ a:')
      expect(text).to include('[1, 2]')
    end
  end

  describe 'to_json_patch with arrays' do
    it 'generates add operation for new array elements' do
      changeset = described_class.diff({ items: [1] }, { items: [1, 2] })
      ops = changeset.to_json_patch

      expect(ops.length).to eq(1)
      expect(ops.first[:op]).to eq('add')
      expect(ops.first[:path]).to eq('/items/1')
      expect(ops.first[:value]).to eq(2)
    end

    it 'generates remove operation for deleted array elements' do
      changeset = described_class.diff({ items: [1, 2] }, { items: [1] })
      ops = changeset.to_json_patch

      expect(ops.length).to eq(1)
      expect(ops.first[:op]).to eq('remove')
      expect(ops.first[:path]).to eq('/items/1')
    end

    it 'generates replace for changed array elements' do
      changeset = described_class.diff({ items: [1, 2] }, { items: [1, 99] })
      ops = changeset.to_json_patch

      expect(ops.first[:op]).to eq('replace')
      expect(ops.first[:value]).to eq(99)
    end
  end

  describe 'similarity with nested arrays' do
    it 'returns 1.0 for identical nested arrays' do
      data = { matrix: [[1, 2], [3, 4]] }
      expect(described_class.similarity(data, data)).to eq(1.0)
    end

    it 'accounts for keyed array additions in similarity' do
      old_data = { items: [{ id: 1, v: 'a' }] }
      new_data = { items: [{ id: 1, v: 'a' }, { id: 2, v: 'b' }] }
      score = described_class.similarity(old_data, new_data, array_key: :id)
      expect(score).to be > 0.0
      expect(score).to be < 1.0
    end

    it 'returns 0.0 when all keyed elements are replaced' do
      old_data = { items: [{ id: 1, v: 'a' }] }
      new_data = { items: [{ id: 2, v: 'b' }] }
      score = described_class.similarity(old_data, new_data, array_key: :id)
      expect(score).to eq(0.0)
    end
  end

  describe 'large hash diff' do
    it 'handles a hash with many keys efficiently' do
      old_hash = (1..50).to_h { |i| [:"key_#{i}", i] }
      new_hash = old_hash.merge(key_25: 999, key_50: 999)
      result = described_class.diff(old_hash, new_hash)

      expect(result.changed.length).to eq(2)
      expect(result.changes.length).to eq(2)
    end

    it 'similarity is correct for large hashes with few changes' do
      old_hash = (1..100).to_h { |i| [:"k#{i}", i] }
      new_hash = old_hash.merge(k1: 999)
      score = described_class.similarity(old_hash, new_hash)
      expect(score).to eq(0.99)
    end
  end

  describe 'string-keyed hash apply and revert' do
    it 'applies changes to string-keyed hashes' do
      old_hash = { 'name' => 'Alice', 'age' => 30 }
      new_hash = { 'name' => 'Bob', 'age' => 30 }
      changeset = described_class.diff(old_hash, new_hash)

      result = changeset.apply(old_hash)
      expect(result['name']).to eq('Bob')
    end

    it 'reverts changes on string-keyed hashes' do
      old_hash = { 'name' => 'Alice' }
      new_hash = { 'name' => 'Bob' }
      changeset = described_class.diff(old_hash, new_hash)

      result = changeset.revert(new_hash)
      expect(result['name']).to eq('Alice')
    end
  end

  describe '.subset' do
    it 'filters changes by path prefix' do
      changeset = described_class.diff(
        { 'user' => { 'name' => 'Alice', 'age' => 30 }, 'meta' => { 'version' => 1 } },
        { 'user' => { 'name' => 'Bob', 'age' => 31 }, 'meta' => { 'version' => 2 } }
      )
      result = described_class.subset(changeset, 'user')
      expect(result.changes.length).to eq(2)
      result.changes.each do |change|
        expect(change.path).to start_with('user')
      end
    end

    it 'returns empty changeset for non-matching prefix' do
      changeset = described_class.diff({ 'a' => 1 }, { 'a' => 2 })
      result = described_class.subset(changeset, 'b')
      expect(result.changes).to be_empty
    end

    it 'includes exact path match' do
      changeset = described_class.diff({ 'name' => 'Alice' }, { 'name' => 'Bob' })
      result = described_class.subset(changeset, 'name')
      expect(result.changes.length).to eq(1)
    end
  end

  describe '.merge' do
    it 'merges non-conflicting changes' do
      base = { 'name' => 'Alice', 'age' => 30 }
      theirs = { 'name' => 'Bob', 'age' => 30 }
      ours = { 'name' => 'Alice', 'age' => 31 }
      result = described_class.merge(base, theirs, ours)
      expect(result[:merged]['name']).to eq('Bob')
      expect(result[:merged]['age']).to eq(31)
      expect(result[:conflicts]).to be_empty
    end

    it 'detects conflicting changes' do
      base = { 'name' => 'Alice' }
      theirs = { 'name' => 'Bob' }
      ours = { 'name' => 'Charlie' }
      result = described_class.merge(base, theirs, ours)
      expect(result[:conflicts].length).to eq(1)
      expect(result[:conflicts][0][:path]).to eq('name')
    end

    it 'preserves unchanged values' do
      base = { 'name' => 'Alice', 'age' => 30 }
      theirs = { 'name' => 'Alice', 'age' => 31 }
      ours = { 'name' => 'Alice', 'age' => 30 }
      result = described_class.merge(base, theirs, ours)
      expect(result[:merged]['name']).to eq('Alice')
      expect(result[:merged]['age']).to eq(31)
    end
  end

  describe '.breaking_changes?' do
    it 'detects removals as breaking' do
      changeset = described_class.diff({ 'a' => 1, 'b' => 2 }, { 'a' => 1 })
      expect(described_class.breaking_changes?(changeset)).to be true
    end

    it 'detects type changes as breaking' do
      changeset = described_class.diff({ 'a' => 'string' }, { 'a' => 42 })
      expect(described_class.breaking_changes?(changeset)).to be true
    end

    it 'does not flag value changes of same type' do
      changeset = described_class.diff({ 'a' => 1 }, { 'a' => 2 })
      expect(described_class.breaking_changes?(changeset)).to be false
    end

    it 'does not flag additions' do
      changeset = described_class.diff({ 'a' => 1 }, { 'a' => 1, 'b' => 2 })
      expect(described_class.breaking_changes?(changeset)).to be false
    end
  end

  describe 'Changeset Enumerable and helpers' do
    let(:changeset) do
      described_class.diff(
        { name: 'Alice', age: 30, city: 'Berlin' },
        { name: 'Bob', email: 'bob@example.com' }
      )
    end

    describe '#each' do
      it 'yields each change' do
        types = changeset.map(&:type)
        expect(types).to include(:changed, :removed, :added)
      end

      it 'returns an enumerator without a block' do
        expect(changeset.each).to be_an(Enumerator)
      end
    end

    describe '#count' do
      it 'returns the number of changes' do
        expect(changeset.count).to eq(changeset.changes.length)
      end

      it 'returns 0 for identical objects' do
        cs = described_class.diff({ a: 1 }, { a: 1 })
        expect(cs.count).to eq(0)
      end
    end

    describe '#paths' do
      it 'returns all changed paths' do
        expect(changeset.paths).to include('name')
      end

      it 'returns empty array for identical objects' do
        cs = described_class.diff({ a: 1 }, { a: 1 })
        expect(cs.paths).to eq([])
      end
    end

    describe '#include?' do
      it 'returns true for a changed path' do
        expect(changeset.include?('name')).to be true
      end

      it 'returns false for an unchanged path' do
        expect(changeset.include?('missing')).to be false
      end

      it 'accepts symbols' do
        expect(changeset.include?(:name)).to be true
      end
    end

    describe '#summary' do
      it 'returns counts by type' do
        summary = changeset.summary
        expect(summary).to have_key(:added)
        expect(summary).to have_key(:removed)
        expect(summary).to have_key(:changed)
        expect(summary.values.sum).to eq(changeset.count)
      end

      it 'returns zeros for identical objects' do
        cs = described_class.diff({ a: 1 }, { a: 1 })
        expect(cs.summary).to eq({ added: 0, removed: 0, changed: 0 })
      end
    end
  end
end
