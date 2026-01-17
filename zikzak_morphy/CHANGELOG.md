# Changelog

## [2.9.1] - 2025-01-17

### Fixed
- CLI now automatically runs `build_runner` after generating `.morphy.dart` files to ensure `.g.dart` files are created for JSON serialization
- MCP server now properly runs `build_runner` to generate `.g.dart` files
- Build cache clearing in rebuild script to ensure fresh builds

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
- 
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

### Fixed
- Fixed constructor accessibility issue in cross-file entity extension
- Updated changeTo, copyWith, and patchWith methods to use public constructors


### Fixed
- Fixed constructor accessibility issue in cross-file entity extension
- Updated changeTo, copyWith, and patchWith methods to use public constructors

- BREAKING CHANGES! copyWith_A is now copyWithA and changeTo_A is now changeToA
- This is to make the naming more consistent with dart conventions
- merged the PRs that allow to set explicitToJson false
- Call the class fromJson if _className_ isn't specified
- Support property name shadowing global types such as Type, String, In…
- thanks to @miklcct for the PRs.

## 1.3.0
- bug fixes, subclass with no members now works, generic copy with bug now fixed where type is incorrect
- in order to fix the above problem the type returned from the copywith is now the type of the named copywith function, eg b.copyWith_A now returns an A type
- this is a BREAKING change.
- if you specify D newD = d.copyWith_A(); then newD will be of type D not A and you'll receive an error
- the thing is that if you know it is a d type you'd more likely do a d.copyWith_D() so this should not be a problem

## 1.2.0
- New functionality - private getters are now allowed!

## 1.1.0
- Breaking change! copywith / change to, the Opt class has been removed and now we favour the () => syntax for optional parameters

## 1.0.8
- change_to added for a subclass to change the type back to a superclass

## 1.0.7
- morphy_annotation must now be in the dependencies and morphy must be in the dev dependencies, cleaned this up

## 1.0.6
- Abstract classes are now sealed, additional option in annotation to specify non sealed abastract classes

## 1.0.5
- Fixed bug introduced with change to custom constructors

## 1.0.4
- Relaxed dependency versions
- Fixed bug for abstract class json serialize & deserialize

## 1.0.3
- Relaxed analyzer requiremenst to 6.0.0

## 1.0.2
- Added jsonserialization annotation dependency included in morphy

## 1.0.1
- Added jsonserialization dependency included in morphy

## 1.0.0+1
- Updated documentation

## 1.0.0
- First published version
