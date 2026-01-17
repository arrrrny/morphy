import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// Import the json parser from bin
import '../bin/morphy_json_parser.dart';

void main() {
  group('MorphyJsonParser', () {
    // Use prefixNestedEntities: false to match original test expectations
    final parser = MorphyJsonParser(prefixNestedEntities: false);

    group('parseJson', () {
      test('parses simple JSON with primitives', () {
        final json = {
          'id': 'user_123',
          'name': 'John Doe',
          'age': 30,
          'score': 95.5,
          'isActive': true,
        };

        final schema = parser.parseJson(json, entityName: 'User');

        expect(schema.name, equals('User'));
        expect(schema.fields.length, equals(5));

        expect(schema.fields[0].name, equals('id'));
        expect(schema.fields[0].type, equals('String'));
        expect(schema.fields[0].isNullable, isFalse);
        expect(schema.fields[0].isPrimitive, isTrue);

        expect(schema.fields[1].name, equals('name'));
        expect(schema.fields[1].type, equals('String'));

        expect(schema.fields[2].name, equals('age'));
        expect(schema.fields[2].type, equals('int'));

        expect(schema.fields[3].name, equals('score'));
        expect(schema.fields[3].type, equals('double'));

        expect(schema.fields[4].name, equals('isActive'));
        expect(schema.fields[4].type, equals('bool'));
      });

      test('parses nullable fields (ending with ?)', () {
        final json = {
          'id': 'user_123',
          'name': 'John',
          'lastName?': 'Doe',
          'email?': 'john@example.com',
          'age?': 30,
        };

        final schema = parser.parseJson(json, entityName: 'User');

        expect(schema.fields.length, equals(5));

        // Non-nullable fields
        final idField = schema.fields.firstWhere((f) => f.name == 'id');
        expect(idField.isNullable, isFalse);

        final nameField = schema.fields.firstWhere((f) => f.name == 'name');
        expect(nameField.isNullable, isFalse);

        // Nullable fields
        final lastNameField = schema.fields.firstWhere(
          (f) => f.name == 'lastName',
        );
        expect(lastNameField.isNullable, isTrue);
        expect(lastNameField.type, equals('String'));

        final emailField = schema.fields.firstWhere((f) => f.name == 'email');
        expect(emailField.isNullable, isTrue);

        final ageField = schema.fields.firstWhere((f) => f.name == 'age');
        expect(ageField.isNullable, isTrue);
        expect(ageField.type, equals('int'));
      });

      test('parses nested objects', () {
        final json = {
          'id': 'order_1',
          'customer': {'id': 'cust_1', 'name': 'Jane Doe'},
          'total': 150.00,
        };

        final schema = parser.parseJson(json, entityName: 'Order');

        expect(schema.name, equals('Order'));
        expect(schema.nestedEntities.length, equals(1));

        final customerField = schema.fields.firstWhere(
          (f) => f.name == 'customer',
        );
        expect(customerField.type, equals('Customer'));
        expect(customerField.isMorphyEntity, isTrue);
        expect(customerField.isPrimitive, isFalse);

        final nestedCustomer = schema.nestedEntities.first;
        expect(nestedCustomer.name, equals('Customer'));
        expect(nestedCustomer.fields.length, equals(2));
      });

      test('parses nested objects with prefix enabled', () {
        final prefixParser = MorphyJsonParser(prefixNestedEntities: true);
        final json = {
          'id': 'order_1',
          'customer': {'id': 'cust_1', 'name': 'Jane Doe'},
          'total': 150.00,
        };

        final schema = prefixParser.parseJson(json, entityName: 'Order');

        expect(schema.name, equals('Order'));
        expect(schema.nestedEntities.length, equals(1));

        final customerField = schema.fields.firstWhere(
          (f) => f.name == 'customer',
        );
        expect(customerField.type, equals('OrderCustomer'));
        expect(customerField.isMorphyEntity, isTrue);

        final nestedCustomer = schema.nestedEntities.first;
        expect(nestedCustomer.name, equals('OrderCustomer'));
      });

      test('parses lists of primitives', () {
        final json = {
          'id': 'user_1',
          'tags': ['dart', 'flutter', 'morphy'],
          'scores': [95, 87, 92],
        };

        final schema = parser.parseJson(json, entityName: 'User');

        final tagsField = schema.fields.firstWhere((f) => f.name == 'tags');
        expect(tagsField.type, equals('List<String>'));
        expect(tagsField.isPrimitive, isTrue);

        final scoresField = schema.fields.firstWhere((f) => f.name == 'scores');
        expect(scoresField.type, equals('List<int>'));
      });

      test('parses lists of objects', () {
        final json = {
          'id': 'cart_1',
          'items': [
            {'name': 'Item 1', 'quantity': 2},
            {'name': 'Item 2', 'quantity': 1},
          ],
        };

        final schema = parser.parseJson(json, entityName: 'Cart');

        final itemsField = schema.fields.firstWhere((f) => f.name == 'items');
        expect(itemsField.type, equals('List<Item>'));
        expect(itemsField.isMorphyEntity, isTrue);

        expect(schema.nestedEntities.length, equals(1));
        final nestedItem = schema.nestedEntities.first;
        expect(nestedItem.name, equals('Item'));
      });

      test('parses lists of objects with prefix enabled', () {
        final prefixParser = MorphyJsonParser(prefixNestedEntities: true);
        final json = {
          'id': 'cart_1',
          'items': [
            {'name': 'Item 1', 'quantity': 2},
            {'name': 'Item 2', 'quantity': 1},
          ],
        };

        final schema = prefixParser.parseJson(json, entityName: 'Cart');

        final itemsField = schema.fields.firstWhere((f) => f.name == 'items');
        expect(itemsField.type, equals('List<CartItem>'));
        expect(itemsField.isMorphyEntity, isTrue);

        expect(schema.nestedEntities.length, equals(1));
        final nestedItem = schema.nestedEntities.first;
        expect(nestedItem.name, equals('CartItem'));
      });

      test('parses DateTime from ISO 8601 strings', () {
        final json = {
          'id': 'event_1',
          'createdAt': '2024-01-15T10:30:00Z',
          'updatedAt': '2024-01-15T10:30:00.123Z',
        };

        final schema = parser.parseJson(json, entityName: 'Event');

        final createdAtField = schema.fields.firstWhere(
          (f) => f.name == 'createdAt',
        );
        expect(createdAtField.type, equals('DateTime'));

        final updatedAtField = schema.fields.firstWhere(
          (f) => f.name == 'updatedAt',
        );
        expect(updatedAtField.type, equals('DateTime'));
      });

      test('handles empty objects', () {
        final json = <String, dynamic>{};

        final schema = parser.parseJson(json, entityName: 'Empty');

        expect(schema.name, equals('Empty'));
        expect(schema.fields, isEmpty);
        expect(schema.nestedEntities, isEmpty);
      });

      test('handles null values as nullable dynamic', () {
        final json = {'id': 'user_1', 'nickname': null};

        final schema = parser.parseJson(json, entityName: 'User');

        final nicknameField = schema.fields.firstWhere(
          (f) => f.name == 'nickname',
        );
        expect(nicknameField.type, equals('dynamic'));
        expect(nicknameField.isNullable, isTrue);
      });

      test('handles deeply nested structures', () {
        final json = {
          'id': 'company_1',
          'name': 'Acme Corp',
          'headquarters': {
            'address': {
              'street': '123 Main St',
              'city': 'Springfield',
              'country': {'code': 'US', 'name': 'United States'},
            },
          },
        };

        final schema = parser.parseJson(json, entityName: 'Company');

        expect(schema.nestedEntities.isNotEmpty, isTrue);

        // Should have nested entities for headquarters, address, and country
        final nestedNames = <String>[];
        void collectNestedNames(EntitySchema s) {
          for (final nested in s.nestedEntities) {
            nestedNames.add(nested.name);
            collectNestedNames(nested);
          }
        }

        collectNestedNames(schema);

        expect(nestedNames, contains('Headquarters'));
      });
    });
  });

  group('MorphyEntityGenerator', () {
    test('generates basic entity class', () {
      final schema = EntitySchema(
        name: 'User',
        fields: [
          FieldSchema(
            name: 'id',
            type: 'String',
            isNullable: false,
            isPrimitive: true,
            isMorphyEntity: false,
          ),
          FieldSchema(
            name: 'name',
            type: 'String',
            isNullable: false,
            isPrimitive: true,
            isMorphyEntity: false,
          ),
          FieldSchema(
            name: 'age',
            type: 'int',
            isNullable: false,
            isPrimitive: true,
            isMorphyEntity: false,
          ),
        ],
        nestedEntities: [],
      );

      final generator = MorphyEntityGenerator(
        generateJson: false,
        generateCompareTo: true,
      );

      final output = generator.generate(schema);

      expect(output, contains('@morphy'));
      expect(output, contains('abstract class \$User'));
      expect(output, contains('String get id;'));
      expect(output, contains('String get name;'));
      expect(output, contains('int get age;'));
    });

    test('generates entity with nullable fields', () {
      final schema = EntitySchema(
        name: 'User',
        fields: [
          FieldSchema(
            name: 'id',
            type: 'String',
            isNullable: false,
            isPrimitive: true,
            isMorphyEntity: false,
          ),
          FieldSchema(
            name: 'email',
            type: 'String',
            isNullable: true,
            isPrimitive: true,
            isMorphyEntity: false,
          ),
        ],
        nestedEntities: [],
      );

      final generator = MorphyEntityGenerator(
        generateJson: false,
        generateCompareTo: true,
      );

      final output = generator.generate(schema);

      expect(output, contains('String get id;'));
      expect(output, contains('String? get email;'));
    });

    test('generates entity with generateJson: true', () {
      final schema = EntitySchema(
        name: 'User',
        fields: [
          FieldSchema(
            name: 'id',
            type: 'String',
            isNullable: false,
            isPrimitive: true,
            isMorphyEntity: false,
          ),
        ],
        nestedEntities: [],
      );

      final generator = MorphyEntityGenerator(
        generateJson: true,
        generateCompareTo: true,
      );

      final output = generator.generate(schema);

      expect(
        output,
        contains('@Morphy(generateJson: true, generateCompareTo: true)'),
      );
    });

    test('generates entity with nested classes', () {
      final nestedSchema = EntitySchema(
        name: 'UserAddress',
        fields: [
          FieldSchema(
            name: 'street',
            type: 'String',
            isNullable: false,
            isPrimitive: true,
            isMorphyEntity: false,
          ),
          FieldSchema(
            name: 'city',
            type: 'String',
            isNullable: false,
            isPrimitive: true,
            isMorphyEntity: false,
          ),
        ],
        nestedEntities: [],
      );

      final schema = EntitySchema(
        name: 'User',
        fields: [
          FieldSchema(
            name: 'id',
            type: 'String',
            isNullable: false,
            isPrimitive: true,
            isMorphyEntity: false,
          ),
          FieldSchema(
            name: 'address',
            type: 'UserAddress',
            isNullable: false,
            isPrimitive: false,
            isMorphyEntity: true,
          ),
        ],
        nestedEntities: [nestedSchema],
      );

      final generator = MorphyEntityGenerator(
        generateJson: false,
        generateCompareTo: true,
      );

      final output = generator.generate(schema);

      expect(output, contains('abstract class \$User'));
      expect(output, contains('UserAddress get address;'));
      expect(output, contains('abstract class \$UserAddress'));
      expect(output, contains('String get street;'));
      expect(output, contains('String get city;'));
    });
  });

  group('generateEntityFromJsonString', () {
    test('generates entity from JSON string', () {
      final jsonString = jsonEncode({
        'id': 'user_123',
        'name': 'John',
        'email?': 'john@example.com',
      });

      final result = generateEntityFromJsonString(
        jsonString: jsonString,
        entityName: 'User',
        outputFileName: 'user.dart',
        generateJson: false,
        generateCompareTo: true,
      );

      expect(result.entityName, equals('User'));
      expect(result.content, contains('abstract class \$User'));
      expect(result.content, contains('String get id;'));
      expect(result.content, contains('String get name;'));
      expect(result.content, contains('String? get email;'));
    });

    test('collects nested entity names with prefix (default)', () {
      final jsonString = jsonEncode({
        'id': 'order_1',
        'customer': {'id': 'cust_1', 'name': 'Jane'},
        'items': [
          {'name': 'Item 1', 'price': 10.0},
        ],
      });

      final result = generateEntityFromJsonString(
        jsonString: jsonString,
        entityName: 'Order',
        outputFileName: 'order.dart',
        generateJson: false,
        generateCompareTo: true,
      );

      // Default is prefixNestedEntities: true
      expect(result.nestedEntityNames, contains('OrderCustomer'));
      expect(result.nestedEntityNames, contains('OrderItem'));
    });

    test('collects nested entity names without prefix', () {
      final jsonString = jsonEncode({
        'id': 'order_1',
        'customer': {'id': 'cust_1', 'name': 'Jane'},
        'items': [
          {'name': 'Item 1', 'price': 10.0},
        ],
      });

      final result = generateEntityFromJsonString(
        jsonString: jsonString,
        entityName: 'Order',
        outputFileName: 'order.dart',
        generateJson: false,
        generateCompareTo: true,
        prefixNestedEntities: false,
      );

      expect(result.nestedEntityNames, contains('Customer'));
      expect(result.nestedEntityNames, contains('Item'));
    });
  });

  group('generateEntityFromJsonFile', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('morphy_json_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('generates entity from JSON file', () async {
      final jsonFile = File(p.join(tempDir.path, 'product.json'));
      await jsonFile.writeAsString(
        jsonEncode({
          'id': 'prod_1',
          'name': 'Widget',
          'price': 99.99,
          'inStock': true,
        }),
      );

      final outputDir = Directory(p.join(tempDir.path, 'output'));
      await outputDir.create();

      final result = await generateEntityFromJsonFile(
        jsonFilePath: jsonFile.path,
        outputDir: outputDir.path,
        entityName: null, // Infer from file name
        generateJson: false,
        generateCompareTo: true,
      );

      expect(result.entityName, equals('Product'));
      expect(result.filePath, endsWith('product.dart'));

      final generatedFile = File(result.filePath);
      expect(await generatedFile.exists(), isTrue);

      final content = await generatedFile.readAsString();
      expect(content, contains('abstract class \$Product'));
      expect(content, contains('String get id;'));
      expect(content, contains('String get name;'));
      expect(content, contains('double get price;'));
      expect(content, contains('bool get inStock;'));
    });

    test('uses provided entity name over inferred name', () async {
      final jsonFile = File(p.join(tempDir.path, 'data.json'));
      await jsonFile.writeAsString(jsonEncode({'id': '123', 'value': 'test'}));

      final outputDir = Directory(p.join(tempDir.path, 'output'));
      await outputDir.create();

      final result = await generateEntityFromJsonFile(
        jsonFilePath: jsonFile.path,
        outputDir: outputDir.path,
        entityName: 'MyCustomEntity',
        generateJson: false,
        generateCompareTo: true,
      );

      expect(result.entityName, equals('MyCustomEntity'));
      expect(result.content, contains('abstract class \$MyCustomEntity'));
    });

    test('generates with JSON serialization support', () async {
      final jsonFile = File(p.join(tempDir.path, 'config.json'));
      await jsonFile.writeAsString(jsonEncode({'key': 'value', 'count': 42}));

      final outputDir = Directory(p.join(tempDir.path, 'output'));
      await outputDir.create();

      final result = await generateEntityFromJsonFile(
        jsonFilePath: jsonFile.path,
        outputDir: outputDir.path,
        entityName: 'Config',
        generateJson: true,
        generateCompareTo: true,
      );

      expect(
        result.content,
        contains('@Morphy(generateJson: true, generateCompareTo: true)'),
      );
    });
  });

  group('Edge cases', () {
    final parser = MorphyJsonParser(prefixNestedEntities: false);

    test('handles field names with special characters', () {
      final json = {'user_id': '123', 'first-name': 'John', 'last.name': 'Doe'};

      // The parser should handle these gracefully
      // Exact behavior depends on implementation
      final schema = parser.parseJson(json, entityName: 'User');
      expect(schema.fields.length, equals(3));
    });

    test('handles mixed type arrays (uses dynamic)', () {
      final json = {
        'id': '1',
        'values': [1, 'two', 3.0, true],
      };

      final schema = parser.parseJson(json, entityName: 'MixedData');
      final valuesField = schema.fields.firstWhere((f) => f.name == 'values');
      // Mixed types become List<dynamic>
      expect(valuesField.type, equals('List<dynamic>'));
    });

    test('handles empty arrays as List<dynamic>', () {
      final json = {'id': '1', 'items': <dynamic>[]};

      final schema = parser.parseJson(json, entityName: 'EmptyList');
      final itemsField = schema.fields.firstWhere((f) => f.name == 'items');
      expect(itemsField.type, equals('List<dynamic>'));
    });

    test('preserves field order from JSON', () {
      // Note: JSON objects in Dart preserve insertion order
      final json = <String, dynamic>{};
      json['alpha'] = 'a';
      json['beta'] = 'b';
      json['gamma'] = 'c';

      final schema = parser.parseJson(json, entityName: 'Ordered');

      expect(schema.fields[0].name, equals('alpha'));
      expect(schema.fields[1].name, equals('beta'));
      expect(schema.fields[2].name, equals('gamma'));
    });
  });
}
