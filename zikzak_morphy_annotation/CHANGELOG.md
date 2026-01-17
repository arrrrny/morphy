# Changelog

## [2.9.0] - 2025-01-17

### Added
- **CLI Tool** - Standalone command-line interface for faster code generation (2-4x faster than build_runner)
  - `morphy generate` - Generate morphy code for annotated classes
  - `morphy from-json` - Generate morphy entity from JSON file
  - `morphy clean` - Remove generated .morphy.dart files
  - `morphy analyze` - Analyze files for morphy annotations
  - Watch mode with `--watch` flag
- **MCP Server** - Model Context Protocol server for AI assistant integration
  - `morphy_generate` - Generate morphy code
  - `morphy_from_json` - Generate entity from JSON data
  - `morphy_analyze` - Analyze files for annotations
  - `morphy_clean` - Clean generated files
- **JSON to Entity Generator** - Create morphy entities from JSON files
  - Automatic type inference (String, int, double, bool, DateTime)
  - Nullable fields using `?` suffix in field names (e.g., `"lastName?": "Doe"`)
  - Nested object support (generates separate entity classes)
  - List support for primitives and objects
- **@JsonKey Support** - Full support for `@JsonKey` annotations on abstract getters
  - `name` - Custom JSON key name
  - `ignore` - Completely ignore the field
  - `defaultValue` - Default value when field is missing
  - `includeFromJson` - Include field when deserializing
  - `includeToJson` - Include field when serializing
  - `includeIfNull`, `required`, `toJson`, `fromJson`

### Fixed
- **@JsonKey on getters** - Fixed extraction of `@JsonKey` annotations from abstract class getters
  - Previously only checked field metadata, now also checks getter metadata
  - Enables proper JSON serialization with custom field names

### Changed
- Default include pattern changed to `lib/src/domain/entities/**.dart`
- Version bumped to 2.9.0 across all packages and tools

## 2.8.1 - 2025-07-16

* fixed warnings, cleaner output
* Updated dependencies to use hosted references

## 2.8.0 - 2025-07-16

* support patchWith nested for complex classes
* Updated dependencies to use hosted references

## 2.7.0 - 2025-07-16

* Support nested patch operations with List and Map support
* Updated dependencies to use hosted references

## 2.6.0 - 2025-07-15

* fixed: non sealed abstract classes was not generating json when generateJson was set true
* Updated dependencies to use hosted references

## 2.5.0 - 2025-07-15

* fixed: changeTo is now not generated for classes inherited that are public constructors hidden
* Updated dependencies to use hosted references

## 2.4.0 - 2025-07-15

* Fixed classes implementing non-sealed class missing changeTo method
* Updated dependencies to use hosted references

## 2.3.0 - 2025-07-15

* non-sealed classes fixed
* Updated dependencies to use hosted references

# Changelog

## [2.2.0] - 2025-07-15

### Added
- TODO: Add release notes for version 2.2.0

### Fixed
- Fixed constructor accessibility issue in cross-file entity extension
- Updated changeTo, copyWith, and patchWith methods to use public constructors


## [2.1.0] - 2025-07-15

### Added
- TODO: Add release notes for version 2.1.0

### Fixed
- Fixed constructor accessibility issue in cross-file entity extension
- Updated changeTo, copyWith, and patchWith methods to use public constructors


## [2.1.0] - 2025-07-15

### Added
- TODO: Add release notes for version 2.1.0

### Fixed
- Fixed constructor accessibility issue in cross-file entity extension
- Updated changeTo, copyWith, and patchWith methods to use public constructors


## [2.1.0] - 2025-07-15

### Added
- TODO: Add release notes for version 2.1.0

### Fixed
- Fixed constructor accessibility issue in cross-file entity extension
- Updated changeTo, copyWith, and patchWith methods to use public constructors


## [2.1.0] - 2025-07-15

### Added
- TODO: Add release notes for version 2.1.0

### Fixed
- Fixed constructor accessibility issue in cross-file entity extension
- Updated changeTo, copyWith, and patchWith methods to use public constructors


## [2.1.0] - 2025-07-15

### Added
- TODO: Add release notes for version 2.1.0

### Fixed
- Fixed constructor accessibility issue in cross-file entity extension
- Updated changeTo, copyWith, and patchWith methods to use public constructors


## [2.1.0] - 2025-07-15

### Added
- TODO: Add release notes for version 2.1.0

### Fixed
- Fixed constructor accessibility issue in cross-file entity extension
- Updated changeTo, copyWith, and patchWith methods to use public constructors
