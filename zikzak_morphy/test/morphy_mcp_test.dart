import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Helper class to interact with the MCP server
class McpServerClient {
  late Process _process;
  late StreamSubscription<String> _stdoutSubscription;
  final _responses = <int, Completer<Map<String, dynamic>>>{};
  int _requestId = 0;
  final List<String> _rawOutput = [];

  Future<void> start() async {
    final mcpServerPath = p.join(
      Directory.current.path,
      'bin',
      'morphy_mcp_server.dart',
    );

    _process = await Process.start('dart', ['run', mcpServerPath]);

    _stdoutSubscription = _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          _rawOutput.add(line);
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            final id = json['id'];
            if (id != null && _responses.containsKey(id)) {
              _responses[id]!.complete(json);
            }
          } catch (_) {
            // Ignore non-JSON output
          }
        });

    // Wait for server to be ready
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> stop() async {
    await _stdoutSubscription.cancel();
    _process.kill();
    await _process.exitCode;
  }

  Future<Map<String, dynamic>> sendRequest(
    String method,
    Map<String, dynamic> params,
  ) async {
    final id = ++_requestId;
    final request = {
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    };

    final completer = Completer<Map<String, dynamic>>();
    _responses[id] = completer;

    _process.stdin.writeln(jsonEncode(request));

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException('Request timed out: $method');
      },
    );
  }

  Future<Map<String, dynamic>> initialize() async {
    return sendRequest('initialize', {
      'protocolVersion': '2024-11-05',
      'capabilities': {},
      'clientInfo': {'name': 'test-client', 'version': '1.0.0'},
    });
  }

  Future<Map<String, dynamic>> listTools() async {
    return sendRequest('tools/list', {});
  }

  Future<Map<String, dynamic>> callTool(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    return sendRequest('tools/call', {'name': name, 'arguments': arguments});
  }
}

void main() {
  late Directory tempDir;
  late McpServerClient client;

  setUpAll(() async {
    client = McpServerClient();
    await client.start();
    await client.initialize();
  });

  tearDownAll(() async {
    await client.stop();
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('morphy_mcp_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MCP Server', () {
    test('lists available tools', () async {
      final response = await client.listTools();

      expect(response['result'], isNotNull);
      final tools = response['result']['tools'] as List<dynamic>;

      final toolNames = tools.map((t) => t['name'] as String).toList();
      expect(toolNames, contains('morphy_generate'));
      expect(toolNames, contains('morphy_analyze'));
      expect(toolNames, contains('morphy_clean'));
      expect(toolNames, contains('morphy_from_json'));
      expect(toolNames, contains('morphy_watch'));
    });

    test('morphy_generate tool has correct schema', () async {
      final response = await client.listTools();
      final tools = response['result']['tools'] as List<dynamic>;
      final generateTool = tools.firstWhere(
        (t) => t['name'] == 'morphy_generate',
      );

      expect(generateTool['inputSchema'], isNotNull);
      final properties =
          generateTool['inputSchema']['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('directory'), isTrue);
      expect(properties.containsKey('include'), isTrue);
      expect(properties.containsKey('exclude'), isTrue);
      expect(properties.containsKey('dry_run'), isTrue);
      expect(properties.containsKey('verbose'), isTrue);
      expect(properties.containsKey('delete_conflicting'), isTrue);
    });

    test('morphy_analyze tool has correct schema', () async {
      final response = await client.listTools();
      final tools = response['result']['tools'] as List<dynamic>;
      final analyzeTool = tools.firstWhere(
        (t) => t['name'] == 'morphy_analyze',
      );

      expect(analyzeTool['inputSchema'], isNotNull);
      final properties =
          analyzeTool['inputSchema']['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('directory'), isTrue);
      expect(properties.containsKey('include'), isTrue);
    });

    test('morphy_clean tool has correct schema', () async {
      final response = await client.listTools();
      final tools = response['result']['tools'] as List<dynamic>;
      final cleanTool = tools.firstWhere((t) => t['name'] == 'morphy_clean');

      expect(cleanTool['inputSchema'], isNotNull);
      final properties =
          cleanTool['inputSchema']['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('directory'), isTrue);
      expect(properties.containsKey('dry_run'), isTrue);
    });

    test('morphy_from_json tool has correct schema', () async {
      final response = await client.listTools();
      final tools = response['result']['tools'] as List<dynamic>;
      final fromJsonTool = tools.firstWhere(
        (t) => t['name'] == 'morphy_from_json',
      );

      expect(fromJsonTool['inputSchema'], isNotNull);
      final properties =
          fromJsonTool['inputSchema']['properties'] as Map<String, dynamic>;

      expect(properties.containsKey('json'), isTrue);
      expect(properties.containsKey('json_file'), isTrue);
      expect(properties.containsKey('name'), isTrue);
      expect(properties.containsKey('output_dir'), isTrue);
      expect(properties.containsKey('generate_json'), isTrue);
      expect(properties.containsKey('generate_compare'), isTrue);
      expect(properties.containsKey('prefix_nested'), isTrue);
    });
  });

  group('morphy_analyze tool', () {
    test('analyzes empty directory', () async {
      final libDir = Directory(
        p.join(tempDir.path, 'lib', 'src', 'domain', 'entities'),
      );
      await libDir.create(recursive: true);

      final response = await client.callTool('morphy_analyze', {
        'directory': tempDir.path,
      });

      expect(response['result'], isNotNull);
      final content = response['result']['content'] as List<dynamic>;
      expect(content.isNotEmpty, isTrue);

      final text = content.first['text'] as String;
      expect(text, contains('Morphy Analysis Report'));
      expect(text, contains('Total annotated classes: 0'));
    });

    test('reports error for non-existent directory', () async {
      final response = await client.callTool('morphy_analyze', {
        'directory': '/non/existent/path',
      });

      expect(response['result'], isNotNull);
      final content = response['result']['content'] as List<dynamic>;
      final text = content.first['text'] as String;
      expect(text.toLowerCase(), contains('not found'));
    });
  });

  group('morphy_generate tool', () {
    test('generates for empty directory', () async {
      final libDir = Directory(
        p.join(tempDir.path, 'lib', 'src', 'domain', 'entities'),
      );
      await libDir.create(recursive: true);

      final response = await client.callTool('morphy_generate', {
        'directory': tempDir.path,
      });

      expect(response['result'], isNotNull);
      final content = response['result']['content'] as List<dynamic>;
      expect(content.isNotEmpty, isTrue);

      final text = content.first['text'] as String;
      expect(text, contains('No files found'));
    });

    test('dry_run does not write files', () async {
      final libDir = Directory(
        p.join(tempDir.path, 'lib', 'src', 'domain', 'entities'),
      );
      await libDir.create(recursive: true);

      final response = await client.callTool('morphy_generate', {
        'directory': tempDir.path,
        'dry_run': true,
      });

      expect(response['result'], isNotNull);
      expect(response['result']['isError'], isNot(true));
    });
  });

  group('morphy_clean tool', () {
    test('cleans empty directory', () async {
      final response = await client.callTool('morphy_clean', {
        'directory': tempDir.path,
      });

      expect(response['result'], isNotNull);
      final content = response['result']['content'] as List<dynamic>;
      final text = content.first['text'] as String;
      expect(text, contains('No .morphy.dart files found'));
    });

    test('removes .morphy.dart files', () async {
      // Create .morphy.dart files
      final morphyFile1 = File(p.join(tempDir.path, 'user.morphy.dart'));
      final morphyFile2 = File(p.join(tempDir.path, 'product.morphy.dart'));
      await morphyFile1.writeAsString('// generated');
      await morphyFile2.writeAsString('// generated');

      expect(await morphyFile1.exists(), isTrue);
      expect(await morphyFile2.exists(), isTrue);

      final response = await client.callTool('morphy_clean', {
        'directory': tempDir.path,
      });

      expect(response['result'], isNotNull);
      final content = response['result']['content'] as List<dynamic>;
      final text = content.first['text'] as String;
      expect(text, contains('Cleaned 2'));

      expect(await morphyFile1.exists(), isFalse);
      expect(await morphyFile2.exists(), isFalse);
    });

    test('dry_run does not delete files', () async {
      final morphyFile = File(p.join(tempDir.path, 'user.morphy.dart'));
      await morphyFile.writeAsString('// generated');

      final response = await client.callTool('morphy_clean', {
        'directory': tempDir.path,
        'dry_run': true,
      });

      expect(response['result'], isNotNull);
      final content = response['result']['content'] as List<dynamic>;
      final text = content.first['text'] as String;
      expect(text, contains('Dry run'));

      // File should still exist
      expect(await morphyFile.exists(), isTrue);
    });
  });

  group('morphy_from_json tool', () {
    test('requires json or json_file', () async {
      final response = await client.callTool('morphy_from_json', {
        'name': 'Test',
        'output_dir': tempDir.path,
      });

      expect(response['result'], isNotNull);
      final content = response['result']['content'] as List<dynamic>;
      final text = content.first['text'] as String;
      expect(text.toLowerCase(), contains('must be provided'));
    });

    test('requires name when using json directly', () async {
      final response = await client.callTool('morphy_from_json', {
        'json': {'id': '123', 'name': 'test'},
        'output_dir': tempDir.path,
      });

      expect(response['result'], isNotNull);
      final content = response['result']['content'] as List<dynamic>;
      final text = content.first['text'] as String;
      expect(text.toLowerCase(), contains('name'));
    });

    test('generates entity from json object', () async {
      final outputDir = Directory(p.join(tempDir.path, 'entities'));
      await outputDir.create(recursive: true);

      final response = await client.callTool('morphy_from_json', {
        'name': 'User',
        'json': {
          'id': 'user_123',
          'name': 'John',
          'email?': 'john@example.com',
          'age': 30,
          'isActive': true,
        },
        'output_dir': outputDir.path,
      });

      expect(response['result'], isNotNull);
      expect(response['result']['isError'], isNot(true));

      final content = response['result']['content'] as List<dynamic>;
      final text = content.first['text'] as String;
      expect(text, contains('User'));
      expect(text, contains('Generated'));

      // Verify the file was created
      final generatedFile = File(p.join(outputDir.path, 'user.dart'));
      expect(await generatedFile.exists(), isTrue);

      final fileContent = await generatedFile.readAsString();
      expect(fileContent, contains('\$User'));
      expect(fileContent, contains('String get id'));
      expect(fileContent, contains('String get name'));
      expect(fileContent, contains('String? get email')); // nullable
      expect(fileContent, contains('int get age'));
      expect(fileContent, contains('bool get isActive'));
    });

    test('generates entity from json file', () async {
      final outputDir = Directory(p.join(tempDir.path, 'entities'));
      await outputDir.create(recursive: true);

      // Create JSON file
      final jsonFile = File(p.join(tempDir.path, 'product.json'));
      await jsonFile.writeAsString(
        jsonEncode({
          'id': 'prod_1',
          'name': 'Widget',
          'price': 99.99,
          'inStock': true,
        }),
      );

      final response = await client.callTool('morphy_from_json', {
        'json_file': jsonFile.path,
        'output_dir': outputDir.path,
      });

      expect(response['result'], isNotNull);
      expect(response['result']['isError'], isNot(true));

      final content = response['result']['content'] as List<dynamic>;
      final text = content.first['text'] as String;
      expect(text, contains('Product'));

      // Verify the file was created
      final generatedFile = File(p.join(outputDir.path, 'product.dart'));
      expect(await generatedFile.exists(), isTrue);
    });

    test('generates with generateJson option', () async {
      final outputDir = Directory(p.join(tempDir.path, 'entities'));
      await outputDir.create(recursive: true);

      final response = await client.callTool('morphy_from_json', {
        'name': 'Config',
        'json': {'key': 'value', 'count': 42},
        'output_dir': outputDir.path,
        'generate_json': true,
      });

      expect(response['result'], isNotNull);
      expect(response['result']['isError'], isNot(true));

      final generatedFile = File(p.join(outputDir.path, 'config.dart'));
      final content = await generatedFile.readAsString();
      expect(content, contains('generateJson: true'));
    });

    test('handles nested objects', () async {
      final outputDir = Directory(p.join(tempDir.path, 'entities'));
      await outputDir.create(recursive: true);

      final response = await client.callTool('morphy_from_json', {
        'name': 'Order',
        'json': {
          'id': 'order_1',
          'customer': {'id': 'cust_1', 'name': 'Jane Doe'},
          'total': 150.00,
        },
        'output_dir': outputDir.path,
      });

      expect(response['result'], isNotNull);
      expect(response['result']['isError'], isNot(true));

      final content = response['result']['content'] as List<dynamic>;
      final text = content.first['text'] as String;
      expect(text, contains('Nested entities'));

      final generatedFile = File(p.join(outputDir.path, 'order.dart'));
      final fileContent = await generatedFile.readAsString();
      expect(fileContent, contains('\$Order'));
      expect(fileContent, contains('\$OrderCustomer')); // Prefixed by default
    });

    test('handles nested objects without prefix', () async {
      final outputDir = Directory(p.join(tempDir.path, 'entities'));
      await outputDir.create(recursive: true);

      final response = await client.callTool('morphy_from_json', {
        'name': 'Order',
        'json': {
          'id': 'order_1',
          'customer': {'id': 'cust_1', 'name': 'Jane Doe'},
          'total': 150.00,
        },
        'output_dir': outputDir.path,
        'prefix_nested': false,
      });

      expect(response['result'], isNotNull);
      expect(response['result']['isError'], isNot(true));

      final generatedFile = File(p.join(outputDir.path, 'order.dart'));
      final fileContent = await generatedFile.readAsString();
      expect(fileContent, contains('\$Order'));
      expect(fileContent, contains('\$Customer')); // Not prefixed
    });

    test('handles lists with prefix (default)', () async {
      final outputDir = Directory(p.join(tempDir.path, 'entities'));
      await outputDir.create(recursive: true);

      final response = await client.callTool('morphy_from_json', {
        'name': 'Cart',
        'json': {
          'id': 'cart_1',
          'items': [
            {'name': 'Item 1', 'quantity': 2},
            {'name': 'Item 2', 'quantity': 1},
          ],
        },
        'output_dir': outputDir.path,
      });

      expect(response['result'], isNotNull);
      expect(response['result']['isError'], isNot(true));

      final generatedFile = File(p.join(outputDir.path, 'cart.dart'));
      final content = await generatedFile.readAsString();
      expect(content, contains('\$Cart'));
      expect(content, contains('\$CartItem')); // Prefixed by default
      expect(content, contains('List<\$CartItem>'));
    });

    test('handles lists without prefix', () async {
      final outputDir = Directory(p.join(tempDir.path, 'entities'));
      await outputDir.create(recursive: true);

      final response = await client.callTool('morphy_from_json', {
        'name': 'Cart',
        'json': {
          'id': 'cart_1',
          'items': [
            {'name': 'Item 1', 'quantity': 2},
            {'name': 'Item 2', 'quantity': 1},
          ],
        },
        'output_dir': outputDir.path,
        'prefix_nested': false,
      });

      expect(response['result'], isNotNull);
      expect(response['result']['isError'], isNot(true));

      final generatedFile = File(p.join(outputDir.path, 'cart.dart'));
      final content = await generatedFile.readAsString();
      expect(content, contains('\$Cart'));
      expect(content, contains('\$Item')); // Not prefixed
      expect(content, contains('List<\$Item>'));
    });

    test('reports error for non-existent json file', () async {
      final response = await client.callTool('morphy_from_json', {
        'json_file': '/non/existent/file.json',
        'output_dir': tempDir.path,
      });

      expect(response['result'], isNotNull);
      final content = response['result']['content'] as List<dynamic>;
      final text = content.first['text'] as String;
      expect(text.toLowerCase(), contains('not found'));
    });
  });
}
