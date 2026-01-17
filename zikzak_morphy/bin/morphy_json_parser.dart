/// JSON parser for generating morphy entities from JSON data
///
/// Supports:
/// - Primitive types: String, int, double, bool, DateTime
/// - Nullable fields using '?' suffix in field name (e.g., "lastName?": "Doe")
/// - Nested objects (generates separate entity classes)
/// - Lists of primitives and objects
///
/// Example JSON:
/// ```json
/// {
///   "id": "user_001",
///   "name": "John",
///   "lastName?": "Doe",
///   "age": 30,
///   "isActive": true,
///   "createdAt": "2024-01-01T00:00:00Z"
/// }
/// ```
///
/// Generates:
/// ```dart
/// @morphy
/// abstract class $User {
///   String get id;
///   String get name;
///   String? get lastName;
///   int get age;
///   bool get isActive;
///   DateTime get createdAt;
/// }
/// ```
library morphy_json_parser;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// JSON parser that infers types from JSON data and generates morphy entities
class MorphyJsonParser {
  /// Parse JSON and return entity schema
  EntitySchema parseJson(Map<String, dynamic> json, {String? entityName}) {
    entityName ??= 'Entity';

    final fields = <FieldSchema>[];
    final nestedEntities = <EntitySchema>[];

    for (final entry in json.entries) {
      final key = entry.key;
      final value = entry.value;

      // Check if field name ends with '?' for explicit nullability
      final isExplicitlyNullable = key.endsWith('?');
      final fieldName = isExplicitlyNullable
          ? key.substring(0, key.length - 1)
          : key;

      final fieldType = _inferType(value);

      if (fieldType == '_NestedObject') {
        // Nested object → create separate entity
        final nestedEntityName = _toPascalCase(fieldName);
        final nestedSchema = parseJson(
          value as Map<String, dynamic>,
          entityName: nestedEntityName,
        );
        nestedEntities.add(nestedSchema);

        fields.add(
          FieldSchema(
            name: fieldName,
            type: nestedEntityName,
            isNullable: isExplicitlyNullable,
            isPrimitive: false,
            isMorphyEntity: true,
          ),
        );
      } else if (fieldType.startsWith('List<_NestedObject>')) {
        // Array of objects → create separate entity
        final list = value as List;
        if (list.isEmpty) {
          // Empty array - can't infer type
          fields.add(
            FieldSchema(
              name: fieldName,
              type: 'List<dynamic>',
              isNullable: isExplicitlyNullable,
              isPrimitive: false,
              isMorphyEntity: false,
            ),
          );
        } else {
          final itemEntityName = _singularize(_toPascalCase(fieldName));

          // Parse all items and merge schemas to get accurate type inference
          final itemSchema = _parseListItems(list, itemEntityName);
          nestedEntities.add(itemSchema);

          fields.add(
            FieldSchema(
              name: fieldName,
              type: 'List<$itemEntityName>',
              isNullable: isExplicitlyNullable,
              isPrimitive: false,
              isMorphyEntity: true,
            ),
          );
        }
      } else {
        // Primitive type
        fields.add(
          FieldSchema(
            name: fieldName,
            type: fieldType,
            isNullable: isExplicitlyNullable || value == null,
            isPrimitive: true,
            isMorphyEntity: false,
          ),
        );
      }
    }

    return EntitySchema(
      name: entityName,
      fields: fields,
      nestedEntities: nestedEntities,
    );
  }

  /// Infer primitive type from JSON value
  String _inferType(dynamic value) {
    if (value == null) {
      return 'dynamic'; // Will be nullable
    }

    if (value is bool) {
      return 'bool';
    }

    if (value is int) {
      return 'int';
    }

    if (value is double) {
      return 'double';
    }

    if (value is num) {
      // Could be int or double - check if it has decimals
      return value == value.toInt() ? 'int' : 'double';
    }

    if (value is String) {
      // Check if it's ISO 8601 DateTime
      if (_isIso8601DateTime(value)) {
        return 'DateTime';
      }
      return 'String';
    }

    if (value is List) {
      if (value.isEmpty) {
        return 'List<dynamic>';
      }

      final firstItemType = _inferType(value[0]);

      if (firstItemType == '_NestedObject') {
        return 'List<_NestedObject>';
      }

      // Get types of all items
      final itemTypes = value.map((item) => _inferType(item)).toSet();

      // If all same type, use that type
      if (itemTypes.length == 1) {
        return 'List<$firstItemType>';
      }

      // Special case: mix of int and double → use double (more general)
      if (itemTypes.contains('int') &&
          itemTypes.contains('double') &&
          itemTypes.length == 2) {
        return 'List<double>';
      }

      // Mixed types
      return 'List<dynamic>';
    }

    if (value is Map<String, dynamic>) {
      return '_NestedObject'; // Marker for nested entity
    }

    return 'dynamic';
  }

  /// Check if string matches ISO 8601 DateTime format
  bool _isIso8601DateTime(String value) {
    // Match: 2025-11-14T12:34:56Z or 2025-11-14T12:34:56.123Z or with timezone offset
    final iso8601Pattern = RegExp(
      r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})?$',
    );
    return iso8601Pattern.hasMatch(value);
  }

  /// Convert snake_case or camelCase to PascalCase
  String _toPascalCase(String input) {
    // Handle snake_case
    if (input.contains('_')) {
      return input
          .split('_')
          .map(
            (word) =>
                word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
          )
          .join('');
    }

    // Handle camelCase
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

  /// Simple singularization (remove 's' at end)
  String _singularize(String plural) {
    if (plural.endsWith('ies')) {
      return plural.substring(0, plural.length - 3) + 'y';
    }
    if (plural.endsWith('es') && plural.length > 3) {
      // addresses -> address, boxes -> box
      return plural.substring(0, plural.length - 2);
    }
    if (plural.endsWith('s') && !plural.endsWith('ss')) {
      return plural.substring(0, plural.length - 1);
    }
    return plural;
  }

  /// Parse list items and merge schemas to get accurate type inference
  /// Checks all items, not just the first one
  EntitySchema _parseListItems(List list, String entityName) {
    // Collect field info from ALL items
    final Map<String, Set<String>> fieldTypes = {};
    final Map<String, bool> fieldNullability = {};

    for (final item in list) {
      if (item is! Map<String, dynamic>) continue;

      for (final entry in item.entries) {
        final key = entry.key;
        final value = entry.value;

        // Check if field name ends with '?' for explicit nullability
        final isExplicitlyNullable = key.endsWith('?');
        final fieldName = isExplicitlyNullable
            ? key.substring(0, key.length - 1)
            : key;

        // Track nullability
        fieldNullability[fieldName] = fieldNullability[fieldName] ?? false;
        if (value == null || isExplicitlyNullable) {
          fieldNullability[fieldName] = true;
        }

        // Track type
        final type = _inferType(value);
        fieldTypes[fieldName] = fieldTypes[fieldName] ?? <String>{};
        fieldTypes[fieldName]!.add(type);
      }
    }

    // Build fields from merged data
    final fields = <FieldSchema>[];
    final nestedEntities = <EntitySchema>[];

    for (final key in fieldTypes.keys) {
      final types = fieldTypes[key]!;
      final isNullable = fieldNullability[key]!;

      // Determine final type
      String finalType;
      if (types.length == 1) {
        finalType = types.first;
      } else if (types.contains('int') &&
          types.contains('double') &&
          types.length == 2) {
        // Mix of int and double → use double
        finalType = 'double';
      } else {
        // Mixed types
        finalType = 'dynamic';
      }

      // Handle nested objects
      if (finalType == '_NestedObject') {
        final nestedEntityName = _toPascalCase(key);
        // Get first non-null nested object to parse
        final nestedItem = list.firstWhere(
          (item) => item is Map && item[key] is Map,
          orElse: () => null,
        );

        if (nestedItem != null) {
          final nestedSchema = parseJson(
            nestedItem[key] as Map<String, dynamic>,
            entityName: nestedEntityName,
          );
          nestedEntities.add(nestedSchema);

          fields.add(
            FieldSchema(
              name: key,
              type: nestedEntityName,
              isNullable: isNullable,
              isPrimitive: false,
              isMorphyEntity: true,
            ),
          );
        }
      } else {
        fields.add(
          FieldSchema(
            name: key,
            type: finalType,
            isNullable: isNullable,
            isPrimitive: true,
            isMorphyEntity: false,
          ),
        );
      }
    }

    return EntitySchema(
      name: entityName,
      fields: fields,
      nestedEntities: nestedEntities,
    );
  }
}

/// Schema representing a parsed entity
class EntitySchema {
  final String name;
  final List<FieldSchema> fields;
  final List<EntitySchema> nestedEntities;

  EntitySchema({
    required this.name,
    required this.fields,
    required this.nestedEntities,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Entity: $name');
    for (final field in fields) {
      buffer.writeln(
        '  - ${field.name}: ${field.type}${field.isNullable ? '?' : ''}',
      );
    }
    if (nestedEntities.isNotEmpty) {
      buffer.writeln('  Nested:');
      for (final nested in nestedEntities) {
        buffer.writeln('    - ${nested.name}');
      }
    }
    return buffer.toString();
  }
}

/// Schema representing a field in an entity
class FieldSchema {
  final String name;
  final String type;
  final bool isNullable;
  final bool isPrimitive;
  final bool isMorphyEntity;

  FieldSchema({
    required this.name,
    required this.type,
    required this.isNullable,
    required this.isPrimitive,
    required this.isMorphyEntity,
  });
}

/// Generator that creates morphy entity code from EntitySchema
class MorphyEntityGenerator {
  final bool generateJson;
  final bool generateCompareTo;

  MorphyEntityGenerator({
    this.generateJson = false,
    this.generateCompareTo = true,
  });

  /// Generate morphy entity code from schema
  String generate(EntitySchema schema) {
    final buffer = StringBuffer();

    // Generate nested entities first
    for (final nested in schema.nestedEntities) {
      buffer.writeln(generate(nested));
      buffer.writeln();
    }

    // Generate main entity
    buffer.writeln(_generateEntity(schema));

    return buffer.toString();
  }

  /// Generate a single entity class
  String _generateEntity(EntitySchema schema) {
    final buffer = StringBuffer();

    // Add annotation
    if (generateJson) {
      buffer.writeln(
        '@Morphy(generateJson: true, generateCompareTo: $generateCompareTo)',
      );
    } else {
      buffer.writeln('@morphy');
    }

    // Class definition
    buffer.writeln('abstract class \$${schema.name} {');

    // Generate fields as getters
    for (final field in schema.fields) {
      final nullSuffix = field.isNullable ? '?' : '';
      final typePrefix = field.isMorphyEntity ? '\$' : '';

      // Handle List types with morphy entities
      String fieldType = field.type;
      if (field.isMorphyEntity && field.type.startsWith('List<')) {
        // Extract inner type and add $ prefix
        final innerType = field.type.substring(5, field.type.length - 1);
        fieldType = 'List<\$$innerType>';
      } else if (field.isMorphyEntity) {
        fieldType = '\$${field.type}';
      }

      buffer.writeln('  $fieldType$nullSuffix get ${field.name};');
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generate a complete Dart file with imports and part directive
  String generateFile(
    EntitySchema schema, {
    required String fileName,
    String? partOf,
  }) {
    final buffer = StringBuffer();

    // Imports
    buffer.writeln(
      "import 'package:zikzak_morphy_annotation/morphy_annotation.dart';",
    );
    if (generateJson) {
      buffer.writeln("import 'package:json_annotation/json_annotation.dart';");
    }
    buffer.writeln();

    // Part directive for generated file
    final baseName = p.basenameWithoutExtension(fileName);
    buffer.writeln("part '$baseName.morphy.dart';");
    if (generateJson) {
      buffer.writeln("part '$baseName.g.dart';");
    }
    buffer.writeln();

    // Generate entities
    buffer.writeln(generate(schema));

    return buffer.toString();
  }
}

/// Result of entity generation
class GenerateFromJsonResult {
  final String entityName;
  final String filePath;
  final String content;
  final List<String> nestedEntityNames;

  GenerateFromJsonResult({
    required this.entityName,
    required this.filePath,
    required this.content,
    required this.nestedEntityNames,
  });
}

/// Generate morphy entity file from JSON file
Future<GenerateFromJsonResult> generateEntityFromJsonFile({
  required String jsonFilePath,
  required String outputDir,
  String? entityName,
  bool generateJson = false,
  bool generateCompareTo = true,
}) async {
  // Read JSON file
  final jsonFile = File(jsonFilePath);
  if (!await jsonFile.exists()) {
    throw Exception('JSON file not found: $jsonFilePath');
  }

  final jsonContent = await jsonFile.readAsString();
  final jsonData = jsonDecode(jsonContent) as Map<String, dynamic>;

  // Infer entity name from file name if not provided
  entityName ??= _inferEntityName(jsonFilePath);

  // Parse JSON
  final parser = MorphyJsonParser();
  final schema = parser.parseJson(jsonData, entityName: entityName);

  // Generate code
  final generator = MorphyEntityGenerator(
    generateJson: generateJson,
    generateCompareTo: generateCompareTo,
  );

  final fileName = _toSnakeCase(entityName) + '.dart';
  final content = generator.generateFile(schema, fileName: fileName);

  // Write output file
  final outputPath = p.join(outputDir, fileName);
  final outputFile = File(outputPath);

  // Create directory if it doesn't exist
  await outputFile.parent.create(recursive: true);

  await outputFile.writeAsString(content);

  // Collect nested entity names
  final nestedNames = <String>[];
  void collectNestedNames(EntitySchema s) {
    for (final nested in s.nestedEntities) {
      nestedNames.add(nested.name);
      collectNestedNames(nested);
    }
  }

  collectNestedNames(schema);

  return GenerateFromJsonResult(
    entityName: entityName,
    filePath: outputPath,
    content: content,
    nestedEntityNames: nestedNames,
  );
}

/// Generate morphy entity from JSON string
GenerateFromJsonResult generateEntityFromJsonString({
  required String jsonString,
  required String entityName,
  required String outputFileName,
  bool generateJson = false,
  bool generateCompareTo = true,
}) {
  final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;

  // Parse JSON
  final parser = MorphyJsonParser();
  final schema = parser.parseJson(jsonData, entityName: entityName);

  // Generate code
  final generator = MorphyEntityGenerator(
    generateJson: generateJson,
    generateCompareTo: generateCompareTo,
  );

  final content = generator.generateFile(schema, fileName: outputFileName);

  // Collect nested entity names
  final nestedNames = <String>[];
  void collectNestedNames(EntitySchema s) {
    for (final nested in s.nestedEntities) {
      nestedNames.add(nested.name);
      collectNestedNames(nested);
    }
  }

  collectNestedNames(schema);

  return GenerateFromJsonResult(
    entityName: entityName,
    filePath: outputFileName,
    content: content,
    nestedEntityNames: nestedNames,
  );
}

/// Infer entity name from file path
String _inferEntityName(String filePath) {
  final baseName = p.basenameWithoutExtension(filePath);
  return _toPascalCase(baseName);
}

/// Convert to PascalCase
String _toPascalCase(String input) {
  // Handle snake_case
  if (input.contains('_')) {
    return input
        .split('_')
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join('');
  }

  // Handle kebab-case
  if (input.contains('-')) {
    return input
        .split('-')
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join('');
  }

  // Handle camelCase
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1);
}

/// Convert PascalCase or camelCase to snake_case
String _toSnakeCase(String input) {
  final result = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    if (char.toUpperCase() == char && char.toLowerCase() != char) {
      if (i > 0) {
        result.write('_');
      }
      result.write(char.toLowerCase());
    } else {
      result.write(char);
    }
  }
  return result.toString();
}
