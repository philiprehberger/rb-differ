# philiprehberger-differ

[![Gem Version](https://badge.fury.io/rb/philiprehberger-differ.svg)](https://rubygems.org/gems/philiprehberger-differ)
[![Tests](https://github.com/philiprehberger/rb-differ/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-differ/actions/workflows/ci.yml)
[![License](https://img.shields.io/github/license/philiprehberger/rb-differ)](LICENSE)

Deep structural diff for hashes, arrays, and nested objects in Ruby

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem 'philiprehberger-differ'
```

Or install directly:

```bash
gem install philiprehberger-differ
```

## Usage

```ruby
require 'philiprehberger/differ'

old_data = { name: 'Alice', age: 30, address: { city: 'Berlin' } }
new_data = { name: 'Alice', age: 31, address: { city: 'Vienna' }, email: 'alice@example.com' }

changeset = Philiprehberger::Differ.diff(old_data, new_data)

changeset.changed?   # => true
changeset.changes    # => [Change, Change, ...]
changeset.added      # => changes where type == :added
changeset.removed    # => changes where type == :removed
changeset.changed    # => changes where type == :changed

# Apply changes to produce new version from old
result = changeset.apply(old_data)

# Revert changes to produce old version from new
original = changeset.revert(new_data)
```

### Ignore Paths

Exclude specific keys from comparison. Supports both symbols and dot-notation strings for nested paths:

```ruby
changeset = Philiprehberger::Differ.diff(old_data, new_data, ignore: [:updated_at, :metadata])

# Ignore nested paths
changeset = Philiprehberger::Differ.diff(old_data, new_data, ignore: ['user.email', 'meta.version'])
```

### Similarity Score

Get a ratio of unchanged fields to total fields, returned as a Float between 0.0 and 1.0:

```ruby
score = Philiprehberger::Differ.similarity(old_data, new_data)
# => 0.5  (half the fields are identical)

score = Philiprehberger::Differ.similarity(old_data, old_data)
# => 1.0  (identical)
```

### Text Formatter

Human-readable text output with +/- prefixes:

```ruby
changeset = Philiprehberger::Differ.diff(
  { name: 'Alice', age: 30 },
  { name: 'Bob', email: 'bob@example.com' }
)

puts changeset.to_text
# ~ name: "Alice" -> "Bob"
# - age: 30
# + email: "bob@example.com"
```

### JSON Patch Format

Returns an array of RFC 6902 JSON Patch operations:

```ruby
changeset = Philiprehberger::Differ.diff(
  { name: 'Alice', age: 30 },
  { name: 'Bob' }
)

changeset.to_json_patch
# => [
#   { op: "replace", path: "/name", value: "Bob" },
#   { op: "remove", path: "/age" }
# ]
```

### Nested Array Diff by Key

Match array elements by a key field instead of index for smarter array comparison:

```ruby
old_data = { users: [{ id: 1, name: 'Alice' }, { id: 2, name: 'Bob' }] }
new_data = { users: [{ id: 2, name: 'Bobby' }, { id: 1, name: 'Alice' }] }

# Without array_key: detects changes at every index (order-sensitive)
# With array_key: matches by :id, only detects Bob -> Bobby change
changeset = Philiprehberger::Differ.diff(old_data, new_data, array_key: :id)
```

## API

### `Philiprehberger::Differ.diff(old_val, new_val, ignore: [], array_key: nil)`

Returns a `Changeset` representing all structural differences.

### `Philiprehberger::Differ.similarity(old_val, new_val, ignore: [], array_key: nil)`

Returns a Float between 0.0 (completely different) and 1.0 (identical).

### `Changeset`

| Method | Description |
|---|---|
| `changed?` | Returns `true` if any differences exist |
| `changes` | All `Change` objects |
| `added` | Changes where `type == :added` |
| `removed` | Changes where `type == :removed` |
| `changed` | Changes where `type == :changed` |
| `apply(hash)` | Applies changes to produce the new version |
| `revert(hash)` | Reverts changes to produce the old version |
| `to_h` | Serializable hash representation |
| `to_text` | Human-readable text with +/- prefixes |
| `to_json_patch` | Array of RFC 6902 JSON Patch operations |

### `Change`

| Attribute | Description |
|---|---|
| `path` | Dot-notation path to the changed value |
| `type` | `:added`, `:removed`, or `:changed` |
| `old_value` | Previous value (`nil` for additions) |
| `new_value` | New value (`nil` for removals) |
| `to_s` | Human-readable string |
| `to_h` | Serializable hash |

## Development

```bash
bundle install
bundle exec rspec      # Run tests
bundle exec rubocop    # Check code style
```

## License

MIT
