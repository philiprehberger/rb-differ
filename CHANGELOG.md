# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-03-17

### Added
- Ignore paths with symbol support: `Differ.diff(a, b, ignore: [:updated_at, "user.email"])`
- Similarity score: `Differ.similarity(a, b)` returns Float between 0.0 and 1.0
- Text formatter: `changeset.to_text` for human-readable +/- output
- JSON Patch formatter: `changeset.to_json_patch` for RFC 6902 operations
- Nested array diff by key: `Differ.diff(a, b, array_key: :id)` matches elements by field

## [0.1.2]

- Add License badge to README
- Add bug_tracker_uri to gemspec
- Add Requirements section to README

## [Unreleased]

## [0.1.0] - 2026-03-15

### Added
- Initial release
- Deep comparison of hashes arrays and nested structures
- Path-based change descriptions
- Patch and unpatch support
- Serializable changeset output
