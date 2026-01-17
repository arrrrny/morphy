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

## [2.8.1] - 2025-07-16

### Fixed
- Fixed warnings, cleaner output
- Updated dependencies to use hosted references

## [2.8.0] - 2025-07-16

### Added
- Support patchWith nested for complex classes
- Updated dependencies to use hosted references

## [2.7.0] - 2025-07-16

### Added
**Nested Patch Operations** - Deep patching support for complex object hierarchies

## [2.0.0] - 2024-12-19

### Added
- Complete package rename from `morphy` to `zikzak_morphy`
- Enhanced `changeTo` method generation with proper inheritance support
- **Factory Constructor Support** - Define named constructors with custom logic directly in abstract classes
- **Self-Referencing Classes** - Full support for tree structures and hierarchical data (TreeNode pattern)
- **Advanced Inheritance Examples** - Person → Employee → Manager transformation patterns
- **Collection Patching** - Specialized methods for updating Lists and Maps containing Morphy objects
- **Function-based Patch Methods** - Fluent API for building complex nested patches
- Improved type safety for constructor parameter generation
- Better error handling for patch-based operations
- Comprehensive documentation with real-world examples
- Clean architecture integration patterns

### Fixed
- **Critical Fix**: `changeTo` methods no longer attempt to access non-existent fields on source classes
- Constructor parameter generation now correctly handles fields that only exist in target classes
- Improved null safety handling in generated code
- Fixed fallback value logic for inheritance hierarchies

### Changed
- Package namespace updated to `zikzak_morphy` and `zikzak_morphy_annotation`
- Improved code generation performance and reliability
- Enhanced error messages for better debugging experience
- Updated build configuration and dependency management

### Technical Improvements
- Fixed `ConstructorParameterGenerator.generateChangeToConstructorParams` to properly handle fields that don't exist in source classes
- Enhanced patch system with better type checking
- Improved generic type handling across inheritance hierarchies
- **Factory Method Generation** - Automatic transformation from `$Class.method` to `Class.method` syntax
- **Recursive Type Support** - Proper handling of self-referencing classes and circular dependencies
- **Advanced Polymorphism** - Enhanced type transformations between related classes
- Better integration with Flutter Clean Architecture patterns

### Migration Notes
- Update import statements from `package:morphy_annotation/morphy_annotation.dart` to `package:zikzak_morphy_annotation/morphy_annotation.dart`
- Update build.yaml configuration to use `zikzak_morphy|morphy` instead of `morphy|morphy`
- **New Syntax Required** - Use `$` prefix for abstract class names and define properties as getters
- **Factory Methods** - Replace manual factory functions with in-class factory method definitions
- Add `part 'filename.morphy.dart';` directive to files using annotations
- Regenerate all `.morphy.dart` files with `dart run build_runner build --delete-conflicting-outputs`

### New Features Showcase

#### Factory Constructors
```dart
@Morphy(hidePublicConstructor: true)
abstract class $User {
  String get name;
  int get age;

  factory $User.create(String name, int age) =>
      User._(name: name, age: age);
}

// Usage: User.create("John", 30)
```

#### Self-Referencing Classes
```dart
@Morphy(generateJson: true)
abstract class $TreeNode {
  String get value;
  List<$TreeNode>? get children;
  $TreeNode? get parent;

  factory $TreeNode.root(String value) =>
      TreeNode._(value: value, children: [], parent: null);
}

// Usage: TreeNode.root("Root")
```

#### Nested Patch Operations
```dart
@Morphy()
abstract class $Profile {
  String get name;
  int get age;
}

@Morphy()
abstract class $Customer {
  String get email;
  $Profile get profile;
  List<$Store> get favoriteStores;
  Map<String, $Contact> get contacts;
}

// Deep nested patching with function-based approach
final customerPatch = CustomerPatch.create()
  ..withEmail('new@example.com')
  ..withProfilePatchFunc((patch) => patch
    ..withName('Updated Name')
    ..withAge(35))
  ..updateFavoriteStoresAt(0, (patch) => patch
    ..withName('Updated Store'))
  ..updateContactsValue('work', (patch) => patch
    ..withPhone('555-0123'));

final updatedCustomer = customerPatch.applyTo(originalCustomer);
```

#### Enhanced Type Transformations
```dart
final person = Person.basic('Alice', 35);
final manager = person.changeToManager(
  teamSize: 10,
  responsibilities: ['Planning'],
  salary: 120000.0,
  role: 'Tech Lead',
);
```

## Credits

This version builds upon the foundational work of the original [Morphy package](https://pub.dev/packages/morphy) by [@atreon](https://github.com/atreon). We acknowledge and appreciate the innovative architecture and design patterns that made this enhanced version possible.

## [1.x.x] - Previous Versions

For changelog entries of the original Morphy package, please refer to the [original package documentation](https://pub.dev/packages/morphy/changelog).
