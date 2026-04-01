# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-04-01

### Added
- `Differ.subset(changeset, path)` for filtering changes by path prefix
- `Differ.merge(base, theirs, ours)` for three-way merge with conflict detection
- `Differ.breaking_changes?(changeset)` for detecting removals and type changes

## [0.2.9] - 2026-03-31

### Added
- Add GitHub issue templates, dependabot config, and PR template

## [0.2.8] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.2.7] - 2026-03-26

### Changed

- Add Sponsor badge and fix License link format in README

## [0.2.6] - 2026-03-24

### Changed
- Expand test coverage to 60+ examples covering edge cases and error paths

## [0.2.5] - 2026-03-24

### Fixed
- Align README one-liner with gemspec summary

## [0.2.4] - 2026-03-24

### Fixed
- Standardize README code examples to use double-quote require statements

## [0.2.3] - 2026-03-24

### Fixed
- Fix Installation section quote style to double quotes
- Remove inline comments from Development section to match template

## [0.2.2] - 2026-03-18

### Changed
- Revert gemspec to single-quoted strings per RuboCop default configuration

## [0.2.1] - 2026-03-18

### Changed
- Fix RuboCop Style/StringLiterals violations in gemspec

## [0.2.0] - 2026-03-17

### Added
- Ignore paths with symbol support: `Differ.diff(a, b, ignore: [:updated_at, "user.email"])`
- Similarity score: `Differ.similarity(a, b)` returns Float between 0.0 and 1.0
- Text formatter: `changeset.to_text` for human-readable +/- output
- JSON Patch formatter: `changeset.to_json_patch` for RFC 6902 operations
- Nested array diff by key: `Differ.diff(a, b, array_key: :id)` matches elements by field

## [0.1.2] - 2026-03-16

### Changed
- Add License badge to README
- Add bug_tracker_uri to gemspec
- Add Requirements section to README

## [0.1.0] - 2026-03-15

### Added
- Initial release
- Deep comparison of hashes arrays and nested structures
- Path-based change descriptions
- Patch and unpatch support
- Serializable changeset output
