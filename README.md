# philiprehberger-differ

[![Gem Version](https://badge.fury.io/rb/philiprehberger-differ.svg)](https://rubygems.org/gems/philiprehberger-differ)
[![License](https://img.shields.io/github/license/philiprehberger/rb-differ)](LICENSE)

Deep structural diff for hashes, arrays, and nested objects in Ruby.

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem 'philiprehberger-differ'
```

Or install directly:

```sh
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

# Ignore specific paths
changeset = Philiprehberger::Differ.diff(old_data, new_data, ignore: ['age'])
```

## API

### `Philiprehberger::Differ.diff(old_val, new_val, ignore: [])`

Returns a `Changeset` representing all structural differences.

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

```sh
bundle install
bundle exec rspec
```

## License

MIT
