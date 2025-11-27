# Changelog

## [2.9.0] - 2025-11-20

### Added
- **🎉 Curly Brace Factory Support** - Factory methods now support both arrow (`=>`) and curly brace (`{ }`) syntax
  - Define complex initialization logic with local variables
  - Multi-step computations and validations
  - Preserves variable names while transforming class references
  - Example:
    ```dart
    factory $Order.create({required List<OrderItem> items}) {
      final now = DateTime.now();
      final total = items.fold(0.0, (sum, item) => sum + item.price);
      return Order._(
        id: 'ORD-${now.millisecondsSinceEpoch}',
        items: items,
        total: total,
        createdAt: now,
      );
    }
    ```

- **📦 Comprehensive E-Commerce Example Suite** - Real-world examples in `example/ecommerce/`
  - `product.dart` - Polymorphic products with sealed classes (`$$Product`)
  - `order.dart` - Complex nested structures with deep patch operations
  - `customer.dart` - Generic types (`Preference<T>`, `Cart<T>`)
  - `category.dart` - Self-referencing tree structures
  - `ecommerce_demo.dart` - Complete integration demo showcasing all features

- **🎯 Enhanced Documentation**
  - Detailed README for e-commerce examples
  - Feature-by-feature breakdown with real code
  - Learning path for new users
  - Production-ready patterns

### Improved
- **Smart Class Reference Transformation** - New `_transformClassReferences()` method
  - Transforms `$ClassName` to `ClassName` in factory bodies
  - Preserves variable names (doesn't transform `$variable`)
  - Handles all known Morphy classes from `_allAnnotatedClasses`
  - Uses word boundaries to avoid partial matches

- **Factory Body Extraction** - Enhanced `_extractFactoryBody()` method
  - Tries arrow notation first (backward compatible)
  - Falls back to curly brace notation
  - Proper brace depth tracking
  - String and character literal handling
  - Escape character support

### Examples
All examples demonstrate:
- ✅ Polymorphic sealed classes with `$$` prefix
- ✅ Curly brace factories with complex logic
- ✅ Generic types (`Preference<T>`, `Cart<T>`)
- ✅ Explicit subtypes for type transformations
- ✅ Deep nested patches for complex updates
- ✅ Self-referencing structures
- ✅ JSON serialization
- ✅ Extension methods for utilities

### Technical Details
- Factory methods can now use full Dart syntax in curly brace bodies
- Automatic transformation of `$ClassName` references while preserving variables
- Support for nested braces, strings, and complex expressions
- Backward compatible with existing arrow notation factories
- No breaking changes to existing code

### Migration from v2.8.x
No changes required! All existing code continues to work:
- Arrow notation factories (`=>`) still fully supported
- Simply add curly braces for more complex initialization
- Regenerate with `dart run build_runner build`

### Real-World Use Cases
See `example/ecommerce/` for:
1. **Product Management** - Physical, digital, and subscription products
2. **Order Processing** - Complex calculations and nested updates
3. **Customer Management** - Preferences, tiers, and loyalty
4. **Category Trees** - Hierarchical navigation and breadcrumbs
5. **Type Transformations** - Generic to specific type conversions

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
