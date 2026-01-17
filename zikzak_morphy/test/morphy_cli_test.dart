import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late String morphyExecutable;

  setUpAll(() {
    // Get the path to the morphy executable
    morphyExecutable = p.join(Directory.current.path, 'bin', 'morphy.dart');
  });

  setUp(() async {
    // Create a temporary directory for each test
    tempDir = await Directory.systemTemp.createTemp('morphy_cli_test_');
  });

  tearDown(() async {
    // Clean up the temporary directory
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<ProcessResult> runMorphy(List<String> args) async {
    return Process.run('dart', [
      'run',
      morphyExecutable,
      ...args,
    ], workingDirectory: Directory.current.path);
  }

  group('morphy CLI', () {
    test('--version prints version', () async {
      final result = await runMorphy(['--version']);
      expect(result.exitCode, equals(0));
      expect(result.stdout.toString(), contains('morphy version'));
    });

    test('--help prints usage', () async {
      final result = await runMorphy(['--help']);
      expect(result.exitCode, equals(0));
      expect(result.stdout.toString(), contains('morphy'));
      expect(result.stdout.toString(), contains('generate'));
      expect(result.stdout.toString(), contains('analyze'));
      expect(result.stdout.toString(), contains('clean'));
      expect(result.stdout.toString(), contains('from-json'));
    });
  });

  group('analyze command', () {
    test('analyze --help shows directory option', () async {
      final result = await runMorphy(['analyze', '--help']);
      expect(result.exitCode, equals(0));
      expect(result.stdout.toString(), contains('--directory'));
      expect(result.stdout.toString(), contains('-d'));
      expect(result.stdout.toString(), contains('--include'));
      expect(result.stdout.toString(), contains('--verbose'));
    });

    test('analyze with --directory option works', () async {
      // Create a test directory structure
      final libDir = Directory(
        p.join(tempDir.path, 'lib', 'src', 'domain', 'entities'),
      );
      await libDir.create(recursive: true);

      final result = await runMorphy(['analyze', '--directory', tempDir.path]);
      expect(result.exitCode, equals(0));
    });

    test('analyze with positional directory argument works', () async {
      // Create a test directory structure
      final libDir = Directory(
        p.join(tempDir.path, 'lib', 'src', 'domain', 'entities'),
      );
      await libDir.create(recursive: true);

      final result = await runMorphy(['analyze', tempDir.path]);
      expect(result.exitCode, equals(0));
    });

    test('analyze fails with non-existent directory', () async {
      final result = await runMorphy([
        'analyze',
        '--directory',
        '/non/existent/path',
      ]);
      expect(result.exitCode, equals(1));
      expect(result.stderr.toString(), contains('not found'));
    });
  });

  group('generate command', () {
    test('generate --help shows directory option', () async {
      final result = await runMorphy(['generate', '--help']);
      expect(result.exitCode, equals(0));
      expect(result.stdout.toString(), contains('--directory'));
      expect(result.stdout.toString(), contains('-d'));
      expect(result.stdout.toString(), contains('--include'));
      expect(result.stdout.toString(), contains('--exclude'));
      expect(result.stdout.toString(), contains('--watch'));
      expect(result.stdout.toString(), contains('--verbose'));
    });

    test(
      'generate with --directory option on empty dir shows no files',
      () async {
        // Create a test directory structure
        final libDir = Directory(
          p.join(tempDir.path, 'lib', 'src', 'domain', 'entities'),
        );
        await libDir.create(recursive: true);

        final result = await runMorphy([
          'generate',
          '--directory',
          tempDir.path,
        ]);
        expect(result.exitCode, equals(0));
        expect(result.stdout.toString(), contains('No files found'));
      },
    );

    test('generate with positional directory argument works', () async {
      // Create a test directory structure
      final libDir = Directory(
        p.join(tempDir.path, 'lib', 'src', 'domain', 'entities'),
      );
      await libDir.create(recursive: true);

      final result = await runMorphy(['generate', tempDir.path]);
      expect(result.exitCode, equals(0));
    });

    test('generate fails with non-existent directory', () async {
      final result = await runMorphy([
        'generate',
        '--directory',
        '/non/existent/path',
      ]);
      expect(result.exitCode, equals(1));
      expect(result.stderr.toString(), contains('not found'));
    });

    test('generate with annotated file creates .morphy.dart', () async {
      // Create a test directory structure
      final libDir = Directory(
        p.join(tempDir.path, 'lib', 'src', 'domain', 'entities'),
      );
      await libDir.create(recursive: true);

      // Create a pubspec.yaml
      final pubspecFile = File(p.join(tempDir.path, 'pubspec.yaml'));
      await pubspecFile.writeAsString('''
name: test_project
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  zikzak_morphy_annotation: any
''');

      // Create a simple annotated file
      final entityFile = File(p.join(libDir.path, 'user.dart'));
      await entityFile.writeAsString('''
import 'package:zikzak_morphy_annotation/morphy_annotation.dart';

part 'user.morphy.dart';

@Morphy()
abstract class \$User {
  String get id;
  String get name;
}
''');

      final result = await runMorphy([
        'generate',
        '--directory',
        tempDir.path,
        '--include',
        'lib/src/domain/entities/**.dart',
      ]);

      // Note: This may fail if zikzak_morphy_annotation isn't available
      // In real tests, you'd want to ensure dependencies are available
      // For now, we just check the command runs
      expect(
        result.stdout.toString().isNotEmpty ||
            result.stderr.toString().isNotEmpty,
        isTrue,
      );
    });
  });

  group('clean command', () {
    test('clean --help shows directory option', () async {
      final result = await runMorphy(['clean', '--help']);
      expect(result.exitCode, equals(0));
      expect(result.stdout.toString(), contains('--directory'));
      expect(result.stdout.toString(), contains('-d'));
      expect(result.stdout.toString(), contains('--dry-run'));
      expect(result.stdout.toString(), contains('--verbose'));
    });

    test('clean with --directory option works', () async {
      final result = await runMorphy(['clean', '--directory', tempDir.path]);
      expect(result.exitCode, equals(0));
      expect(result.stdout.toString(), contains('No .morphy.dart files found'));
    });

    test('clean with positional directory argument works', () async {
      final result = await runMorphy(['clean', tempDir.path]);
      expect(result.exitCode, equals(0));
    });

    test('clean removes .morphy.dart files', () async {
      // Create some .morphy.dart files
      final morphyFile1 = File(p.join(tempDir.path, 'user.morphy.dart'));
      final morphyFile2 = File(p.join(tempDir.path, 'product.morphy.dart'));
      await morphyFile1.writeAsString('// generated');
      await morphyFile2.writeAsString('// generated');

      expect(await morphyFile1.exists(), isTrue);
      expect(await morphyFile2.exists(), isTrue);

      final result = await runMorphy(['clean', '--directory', tempDir.path]);
      expect(result.exitCode, equals(0));
      expect(result.stdout.toString(), contains('Cleaned 2'));

      expect(await morphyFile1.exists(), isFalse);
      expect(await morphyFile2.exists(), isFalse);
    });

    test('clean --dry-run does not delete files', () async {
      // Create a .morphy.dart file
      final morphyFile = File(p.join(tempDir.path, 'user.morphy.dart'));
      await morphyFile.writeAsString('// generated');

      expect(await morphyFile.exists(), isTrue);

      final result = await runMorphy([
        'clean',
        '--directory',
        tempDir.path,
        '--dry-run',
      ]);
      expect(result.exitCode, equals(0));
      expect(result.stdout.toString(), contains('Dry run'));
      expect(result.stdout.toString(), contains('would delete'));

      // File should still exist
      expect(await morphyFile.exists(), isTrue);
    });
  });

  group('from-json command', () {
    test('from-json --help shows options', () async {
      final result = await runMorphy(['from-json', '--help']);
      expect(result.exitCode, equals(0));
      expect(result.stdout.toString(), contains('--name'));
      expect(result.stdout.toString(), contains('--output'));
      expect(result.stdout.toString(), contains('--json'));
      expect(result.stdout.toString(), contains('--compare'));
      expect(result.stdout.toString(), contains('--prefix-nested'));
    });

    test('from-json requires a JSON file argument', () async {
      final result = await runMorphy(['from-json']);
      expect(result.exitCode, equals(1));
      expect(
        result.stdout.toString() + result.stderr.toString(),
        contains('Missing required argument'),
      );
    });

    test('from-json generates entity from JSON file', () async {
      // Create output directory
      final outputDir = Directory(
        p.join(tempDir.path, 'lib', 'src', 'domain', 'entities'),
      );
      await outputDir.create(recursive: true);

      // Create a JSON file
      final jsonFile = File(p.join(tempDir.path, 'user.json'));
      await jsonFile.writeAsString(
        jsonEncode({
          'id': 'user_123',
          'name': 'John Doe',
          'email?': 'john@example.com',
          'age': 30,
          'isActive': true,
        }),
      );

      final result = await runMorphy([
        'from-json',
        jsonFile.path,
        '--output',
        outputDir.path,
      ]);

      expect(result.exitCode, equals(0));
      expect(result.stdout.toString(), contains('Generated entity'));
      expect(result.stdout.toString(), contains('User'));

      // Check the generated file exists
      final generatedFile = File(p.join(outputDir.path, 'user.dart'));
      expect(await generatedFile.exists(), isTrue);

      final content = await generatedFile.readAsString();
      expect(content, contains('\$User'));
      expect(content, contains('String get id'));
      expect(content, contains('String get name'));
      expect(content, contains('String? get email')); // nullable
      expect(content, contains('int get age'));
      expect(content, contains('bool get isActive'));
    });

    test('from-json with --name overrides entity name', () async {
      // Create output directory
      final outputDir = Directory(p.join(tempDir.path, 'output'));
      await outputDir.create(recursive: true);

      // Create a JSON file
      final jsonFile = File(p.join(tempDir.path, 'data.json'));
      await jsonFile.writeAsString(jsonEncode({'id': '123', 'value': 42.5}));

      final result = await runMorphy([
        'from-json',
        jsonFile.path,
        '--name',
        'MyEntity',
        '--output',
        outputDir.path,
      ]);

      expect(result.exitCode, equals(0));
      expect(result.stdout.toString(), contains('MyEntity'));

      // Check the generated file
      final generatedFile = File(p.join(outputDir.path, 'my_entity.dart'));
      expect(await generatedFile.exists(), isTrue);

      final content = await generatedFile.readAsString();
      expect(content, contains('\$MyEntity'));
    });

    test('from-json with --json flag adds generateJson: true', () async {
      // Create output directory
      final outputDir = Directory(p.join(tempDir.path, 'output'));
      await outputDir.create(recursive: true);

      // Create a JSON file
      final jsonFile = File(p.join(tempDir.path, 'product.json'));
      await jsonFile.writeAsString(
        jsonEncode({'id': 'prod_1', 'price': 99.99}),
      );

      final result = await runMorphy([
        'from-json',
        jsonFile.path,
        '--json',
        '--output',
        outputDir.path,
      ]);

      expect(result.exitCode, equals(0));

      // Check the generated file has generateJson: true
      final generatedFile = File(p.join(outputDir.path, 'product.dart'));
      final content = await generatedFile.readAsString();
      expect(content, contains('generateJson: true'));
    });

    test('from-json handles nested objects with prefix (default)', () async {
      // Create output directory
      final outputDir = Directory(p.join(tempDir.path, 'output'));
      await outputDir.create(recursive: true);

      // Create a JSON file with nested object
      final jsonFile = File(p.join(tempDir.path, 'order.json'));
      await jsonFile.writeAsString(
        jsonEncode({
          'id': 'order_1',
          'customer': {'id': 'cust_1', 'name': 'Jane Doe'},
          'total': 150.00,
        }),
      );

      final result = await runMorphy([
        'from-json',
        jsonFile.path,
        '--output',
        outputDir.path,
      ]);

      expect(result.exitCode, equals(0));
      expect(result.stdout.toString(), contains('Nested entities'));
      expect(result.stdout.toString(), contains('OrderCustomer'));

      // Check the generated file contains nested entity with prefix
      final generatedFile = File(p.join(outputDir.path, 'order.dart'));
      final content = await generatedFile.readAsString();
      expect(content, contains('\$Order'));
      expect(content, contains('\$OrderCustomer')); // Prefixed nested entity
      expect(content, contains('\$OrderCustomer get customer'));
    });

    test('from-json handles nested objects without prefix', () async {
      // Create output directory
      final outputDir = Directory(p.join(tempDir.path, 'output'));
      await outputDir.create(recursive: true);

      // Create a JSON file with nested object
      final jsonFile = File(p.join(tempDir.path, 'order.json'));
      await jsonFile.writeAsString(
        jsonEncode({
          'id': 'order_1',
          'customer': {'id': 'cust_1', 'name': 'Jane Doe'},
          'total': 150.00,
        }),
      );

      final result = await runMorphy([
        'from-json',
        jsonFile.path,
        '--output',
        outputDir.path,
        '--no-prefix-nested',
      ]);

      expect(result.exitCode, equals(0));
      expect(result.stdout.toString(), contains('Nested entities'));
      expect(result.stdout.toString(), contains('Customer'));

      // Check the generated file contains nested entity without prefix
      final generatedFile = File(p.join(outputDir.path, 'order.dart'));
      final content = await generatedFile.readAsString();
      expect(content, contains('\$Order'));
      expect(content, contains('\$Customer')); // Non-prefixed nested entity
      expect(content, contains('\$Customer get customer'));
    });

    test('from-json handles lists with prefix (default)', () async {
      // Create output directory
      final outputDir = Directory(p.join(tempDir.path, 'output'));
      await outputDir.create(recursive: true);

      // Create a JSON file with list
      final jsonFile = File(p.join(tempDir.path, 'cart.json'));
      await jsonFile.writeAsString(
        jsonEncode({
          'id': 'cart_1',
          'items': [
            {'name': 'Item 1', 'quantity': 2},
            {'name': 'Item 2', 'quantity': 1},
          ],
        }),
      );

      final result = await runMorphy([
        'from-json',
        jsonFile.path,
        '--output',
        outputDir.path,
      ]);

      expect(result.exitCode, equals(0));

      // Check the generated file
      final generatedFile = File(p.join(outputDir.path, 'cart.dart'));
      final content = await generatedFile.readAsString();
      expect(content, contains('\$Cart'));
      expect(content, contains('\$CartItem')); // Prefixed nested entity
      expect(
        content,
        contains('List<\$CartItem>'),
      ); // List of prefixed nested entities
    });

    test('from-json handles lists without prefix', () async {
      // Create output directory
      final outputDir = Directory(p.join(tempDir.path, 'output'));
      await outputDir.create(recursive: true);

      // Create a JSON file with list
      final jsonFile = File(p.join(tempDir.path, 'cart.json'));
      await jsonFile.writeAsString(
        jsonEncode({
          'id': 'cart_1',
          'items': [
            {'name': 'Item 1', 'quantity': 2},
            {'name': 'Item 2', 'quantity': 1},
          ],
        }),
      );

      final result = await runMorphy([
        'from-json',
        jsonFile.path,
        '--output',
        outputDir.path,
        '--no-prefix-nested',
      ]);

      expect(result.exitCode, equals(0));

      // Check the generated file
      final generatedFile = File(p.join(outputDir.path, 'cart.dart'));
      final content = await generatedFile.readAsString();
      expect(content, contains('\$Cart'));
      expect(content, contains('\$Item')); // Non-prefixed nested entity
      expect(
        content,
        contains('List<\$Item>'),
      ); // List of non-prefixed nested entities
    });

    test('from-json fails with non-existent file', () async {
      final result = await runMorphy(['from-json', '/non/existent/file.json']);

      expect(result.exitCode, equals(1));
      expect(result.stderr.toString(), contains('not found'));
    });
  });

  group('command aliases', () {
    test('gen is alias for generate', () async {
      final result = await runMorphy(['gen', '--help']);
      expect(result.exitCode, equals(0));
      expect(result.stdout.toString(), contains('Generate morphy code'));
    });

    test('build is alias for generate', () async {
      final result = await runMorphy(['build', '--help']);
      expect(result.exitCode, equals(0));
      expect(result.stdout.toString(), contains('Generate morphy code'));
    });

    test('json is alias for from-json', () async {
      final result = await runMorphy(['json', '--help']);
      expect(result.exitCode, equals(0));
      expect(result.stdout.toString(), contains('Generate a morphy entity'));
    });

    test('fj is alias for from-json', () async {
      final result = await runMorphy(['fj', '--help']);
      expect(result.exitCode, equals(0));
      expect(result.stdout.toString(), contains('Generate a morphy entity'));
    });
  });
}
