import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';
import 'package:zikzak_morphy_annotation/morphy_annotation.dart';

import 'morphy_standalone_generator.dart';
import 'morphy_json_parser.dart';

/// MCP Server for Morphy Code Generator
///
/// This server implements the Model Context Protocol to expose
/// morphy CLI functionality as MCP tools.
///
/// Run with: dart run zikzak_morphy:morphy_mcp_server
void main() async {
  final server = MorphyMcpServer();
  await server.run();
}

class MorphyMcpServer {
  static const String serverName = 'morphy-mcp-server';
  static const String serverVersion = '2.9.0';

  /// Main server loop that handles JSON-RPC messages
  Future<void> run() async {
    // Enable stdin line reading
    try {
      stdin.echoMode = false;
    } catch (_) {
      // Ignore errors in piped context
    }
    try {
      stdin.lineMode = true;
    } catch (_) {
      // Ignore errors in piped context
    }

    // Process messages
    await for (final line
        in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.isEmpty) continue;

      try {
        final request = jsonDecode(line) as Map<String, dynamic>;
        final response = await handleRequest(request);
        stdout.writeln(jsonEncode(response));
        await stdout.flush();
      } catch (e, stackTrace) {
        stderr.writeln('Error processing request: $e\n$stackTrace');
        final errorResponse = {
          'jsonrpc': '2.0',
          'error': {
            'code': -32603,
            'message': 'Internal error: ${e.toString()}',
          },
          'id': null,
        };
        stdout.writeln(jsonEncode(errorResponse));
        await stdout.flush();
      }
    }
  }

  /// Handle incoming JSON-RPC requests
  Future<Map<String, dynamic>> handleRequest(
    Map<String, dynamic> request,
  ) async {
    final method = request['method'] as String?;
    final id = request['id'];

    switch (method) {
      case 'initialize':
        return _initialize(id);
      case 'tools/list':
        return _listTools(id);
      case 'tools/call':
        return await _callTool(
          id,
          request['params'] as Map<String, dynamic>? ?? {},
        );
      case 'resources/list':
        return await _listResources(id);
      case 'resources/read':
        return await _readResource(
          id,
          request['params'] as Map<String, dynamic>? ?? {},
        );
      case 'shutdown':
        return _success(id, {});
      case 'ping':
        return _success(id, {'pong': true});
      default:
        return _error(id, -32601, 'Method not found: $method');
    }
  }

  /// Handle initialize request
  Map<String, dynamic> _initialize(dynamic id) {
    return {
      'jsonrpc': '2.0',
      'result': {
        'protocolVersion': '2024-11-05',
        'capabilities': {
          'tools': {'listChanged': true},
          'resources': {'subscribe': true, 'listChanged': true},
          'prompts': {},
        },
        'serverInfo': {'name': serverName, 'version': serverVersion},
      },
      'id': id,
    };
  }

  /// List available tools
  Map<String, dynamic> _listTools(dynamic id) {
    return {
      'jsonrpc': '2.0',
      'result': {
        'tools': [
          _generateToolDefinition(),
          _fromJsonToolDefinition(),
          _analyzeToolDefinition(),
          _watchToolDefinition(),
          _cleanToolDefinition(),
        ],
      },
      'id': id,
    };
  }

  /// Generate tool definition - main code generation tool
  Map<String, dynamic> _generateToolDefinition() {
    return {
      'name': 'morphy_generate',
      'description':
          'Generate morphy code (copyWith, equals, toString, JSON serialization) for Dart classes annotated with @morphy. '
          'Scans the specified directory for Dart files with morphy annotations and generates corresponding .morphy.dart files.',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description':
                'The directory to scan for Dart files. Defaults to current working directory.',
          },
          'include': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                'Glob patterns for files to include. Defaults to ["lib/src/domain/entities/**.dart"].',
          },
          'exclude': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                'Glob patterns for files to exclude. Defaults to ["**/*.g.dart", "**/*.morphy.dart", "**/*.freezed.dart"].',
          },
          'delete_conflicting': {
            'type': 'boolean',
            'description':
                'Delete conflicting output files before generating. Defaults to true.',
          },
          'verbose': {
            'type': 'boolean',
            'description': 'Enable verbose output. Defaults to false.',
          },
          'dry_run': {
            'type': 'boolean',
            'description':
                'Preview files that would be generated without writing them. Defaults to false.',
          },
        },
      },
    };
  }

  /// Analyze tool definition - analyze files for morphy annotations
  Map<String, dynamic> _analyzeToolDefinition() {
    return {
      'name': 'morphy_analyze',
      'description':
          'Analyze Dart files in a directory and list classes with morphy annotations. '
          'Useful for understanding what code will be generated before running morphy_generate.',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description':
                'The directory to analyze. Defaults to current working directory.',
          },
          'include': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                'Glob patterns for files to include. Defaults to ["lib/src/domain/entities/**.dart"].',
          },
        },
      },
    };
  }

  /// Watch tool definition
  Map<String, dynamic> _watchToolDefinition() {
    return {
      'name': 'morphy_watch',
      'description':
          'Start watching a directory for file changes and automatically regenerate morphy code. '
          'Note: This starts a long-running process.',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description':
                'The directory to watch. Defaults to current working directory.',
          },
          'include': {
            'type': 'array',
            'items': {'type': 'string'},
            'description':
                'Glob patterns for files to include. Defaults to ["lib/src/domain/entities/**.dart"].',
          },
        },
      },
    };
  }

  /// Clean tool definition
  Map<String, dynamic> _cleanToolDefinition() {
    return {
      'name': 'morphy_clean',
      'description':
          'Remove all generated .morphy.dart files from a directory.',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'directory': {
            'type': 'string',
            'description':
                'The directory to clean. Defaults to current working directory.',
          },
          'dry_run': {
            'type': 'boolean',
            'description':
                'Preview files that would be deleted without deleting them. Defaults to false.',
          },
        },
      },
    };
  }

  /// From-JSON tool definition - generate entity from JSON
  Map<String, dynamic> _fromJsonToolDefinition() {
    return {
      'name': 'morphy_from_json',
      'description':
          'Generate a morphy entity class from JSON data. '
          'Field names ending with "?" will be nullable (e.g., "lastName?": "Doe" becomes String? get lastName). '
          'Supports primitives (String, int, double, bool, DateTime), nested objects, and lists. '
          'Nested objects automatically generate separate entity classes.',
      'inputSchema': {
        'type': 'object',
        'properties': {
          'json': {
            'type': 'object',
            'description':
                'The JSON object defining the entity structure. Use field names ending with "?" for nullable fields.',
          },
          'json_file': {
            'type': 'string',
            'description':
                'Path to a JSON file (alternative to providing json directly).',
          },
          'name': {
            'type': 'string',
            'description':
                'Entity name in PascalCase (e.g., "User", "ProductItem"). Required if using json, inferred from file name if using json_file.',
          },
          'output_dir': {
            'type': 'string',
            'description':
                'Output directory for the generated entity file. Defaults to "lib/src/domain/entities".',
          },
          'generate_json': {
            'type': 'boolean',
            'description':
                'Generate JSON serialization support (@Morphy(generateJson: true)). Defaults to false.',
          },
          'generate_compare': {
            'type': 'boolean',
            'description': 'Generate compareTo support. Defaults to true.',
          },
        },
        'required': [],
      },
    };
  }

  /// Handle tool calls
  Future<Map<String, dynamic>> _callTool(
    dynamic id,
    Map<String, dynamic> params,
  ) async {
    final toolName = params['name'] as String;
    final args = params['arguments'] as Map<String, dynamic>? ?? {};

    try {
      String result;
      List<String> generatedFiles = [];

      switch (toolName) {
        case 'morphy_generate':
          final generateResult = await _runGenerate(args);
          result = generateResult.message;
          generatedFiles = generateResult.generatedFiles;
          break;
        case 'morphy_from_json':
          final fromJsonResult = await _runFromJson(args);
          result = fromJsonResult.message;
          generatedFiles = fromJsonResult.generatedFiles;
          break;
        case 'morphy_analyze':
          result = await _runAnalyze(args);
          break;
        case 'morphy_watch':
          result = await _runWatch(args);
          break;
        case 'morphy_clean':
          result = await _runClean(args);
          break;
        default:
          return _error(id, -32602, 'Unknown tool: $toolName');
      }

      // Send resource change notifications for generated files
      for (final filePath in generatedFiles) {
        _sendResourceNotification('created', filePath);
      }

      return {
        'jsonrpc': '2.0',
        'result': {
          'content': [
            {'type': 'text', 'text': result},
          ],
        },
        'id': id,
      };
    } catch (e, stackTrace) {
      return {
        'jsonrpc': '2.0',
        'result': {
          'content': [
            {
              'type': 'text',
              'text':
                  'Error: ${e.toString()}\n\nStack trace:\n${stackTrace.toString()}',
            },
          ],
          'isError': true,
        },
        'id': id,
      };
    }
  }

  /// Run the generate command
  Future<GenerateResult> _runGenerate(Map<String, dynamic> args) async {
    final directory = args['directory'] as String? ?? Directory.current.path;
    final includePatterns =
        (args['include'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        ['lib/src/domain/entities/**.dart'];
    final excludePatterns =
        (args['exclude'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        ['**/*.g.dart', '**/*.morphy.dart', '**/*.freezed.dart'];
    final deleteConflicting = args['delete_conflicting'] as bool? ?? true;
    final verbose = args['verbose'] as bool? ?? false;
    final dryRun = args['dry_run'] as bool? ?? false;

    final absoluteDir = p.normalize(p.absolute(directory));

    if (!Directory(absoluteDir).existsSync()) {
      throw Exception('Directory not found: $absoluteDir');
    }

    // Find all matching files
    final files = await _findFiles(
      absoluteDir,
      includePatterns,
      excludePatterns,
    );

    if (files.isEmpty) {
      return GenerateResult(
        message: 'No files found matching the include patterns in $absoluteDir',
        generatedFiles: [],
      );
    }

    if (dryRun) {
      final buffer = StringBuffer();
      buffer.writeln('Dry run - would process ${files.length} files:');
      for (final file in files) {
        buffer.writeln('  - ${p.relative(file, from: absoluteDir)}');
      }
      return GenerateResult(message: buffer.toString(), generatedFiles: []);
    }

    // Create analysis context
    final collection = AnalysisContextCollection(
      includedPaths: [absoluteDir],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );

    final generatedFiles = <String>[];
    final errors = <String>[];
    var successCount = 0;
    var skippedCount = 0;

    for (final filePath in files) {
      try {
        final result = await _processFile(
          filePath,
          collection,
          absoluteDir,
          deleteConflicting,
          verbose,
        );
        if (result != null) {
          generatedFiles.add(result);
          successCount++;
        } else {
          skippedCount++;
        }
      } catch (e) {
        errors.add('${p.relative(filePath, from: absoluteDir)}: $e');
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('Morphy generation completed:');
    buffer.writeln('  Generated: $successCount files');
    buffer.writeln('  Skipped: $skippedCount files (no morphy annotations)');
    if (errors.isNotEmpty) {
      buffer.writeln('  Errors: ${errors.length}');
      for (final error in errors) {
        buffer.writeln('    - $error');
      }
    }
    if (verbose && generatedFiles.isNotEmpty) {
      buffer.writeln('\nGenerated files:');
      for (final file in generatedFiles) {
        buffer.writeln('  - ${p.relative(file, from: absoluteDir)}');
      }
    }

    return GenerateResult(
      message: buffer.toString(),
      generatedFiles: generatedFiles,
    );
  }

  /// Run the analyze command
  Future<String> _runAnalyze(Map<String, dynamic> args) async {
    final directory = args['directory'] as String? ?? Directory.current.path;
    final includePatterns =
        (args['include'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        ['lib/src/domain/entities/**.dart'];

    final absoluteDir = p.normalize(p.absolute(directory));

    if (!Directory(absoluteDir).existsSync()) {
      throw Exception('Directory not found: $absoluteDir');
    }

    final excludePatterns = [
      '**/*.g.dart',
      '**/*.morphy.dart',
      '**/*.freezed.dart',
    ];
    final files = await _findFiles(
      absoluteDir,
      includePatterns,
      excludePatterns,
    );

    if (files.isEmpty) {
      return 'No files found matching the include patterns in $absoluteDir';
    }

    final collection = AnalysisContextCollection(
      includedPaths: [absoluteDir],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );

    final buffer = StringBuffer();
    buffer.writeln('Morphy Analysis Report');
    buffer.writeln('=' * 50);
    buffer.writeln('Directory: $absoluteDir');
    buffer.writeln('Files scanned: ${files.length}');
    buffer.writeln('');

    final morphyChecker = TypeChecker.fromRuntime(Morphy);
    final morphy2Checker = TypeChecker.fromRuntime(Morphy2);

    var totalAnnotated = 0;

    for (final filePath in files) {
      try {
        final context = collection.contextFor(filePath);
        final result = await context.currentSession.getResolvedLibrary(
          filePath,
        );

        if (result is! ResolvedLibraryResult) continue;

        final library = result.element;
        final annotatedClasses = <String>[];

        for (final unit in library.units) {
          for (final classElement in unit.classes) {
            if (morphyChecker.hasAnnotationOf(classElement) ||
                morphy2Checker.hasAnnotationOf(classElement)) {
              annotatedClasses.add(classElement.name);
              totalAnnotated++;
            }
          }
        }

        if (annotatedClasses.isNotEmpty) {
          buffer.writeln('${p.relative(filePath, from: absoluteDir)}:');
          for (final className in annotatedClasses) {
            buffer.writeln('  - $className');
          }
        }
      } catch (e) {
        buffer.writeln(
          '${p.relative(filePath, from: absoluteDir)}: Error - $e',
        );
      }
    }

    buffer.writeln('');
    buffer.writeln('Total annotated classes: $totalAnnotated');

    return buffer.toString();
  }

  /// Run the watch command
  Future<String> _runWatch(Map<String, dynamic> args) async {
    // Watch mode requires a long-running process which doesn't fit well
    // with the request-response MCP model. Return instructions instead.
    return '''
Watch mode is not directly supported via MCP as it requires a long-running process.

To use watch mode, run the morphy CLI directly:

  dart run zikzak_morphy:morphy --watch

Or use the generate tool periodically after making changes.
''';
  }

  /// Run the from-json command
  Future<GenerateResult> _runFromJson(Map<String, dynamic> args) async {
    final jsonData = args['json'] as Map<String, dynamic>?;
    final jsonFilePath = args['json_file'] as String?;
    final entityName = args['name'] as String?;
    final outputDir =
        args['output_dir'] as String? ?? 'lib/src/domain/entities';
    final generateJson = args['generate_json'] as bool? ?? false;
    final generateCompare = args['generate_compare'] as bool? ?? true;

    if (jsonData == null && jsonFilePath == null) {
      throw Exception('Either "json" or "json_file" must be provided');
    }

    final absoluteOutputDir = p.normalize(p.absolute(outputDir));

    GenerateFromJsonResult result;

    if (jsonFilePath != null) {
      // Generate from file
      final absoluteJsonPath = p.normalize(p.absolute(jsonFilePath));

      if (!File(absoluteJsonPath).existsSync()) {
        throw Exception('JSON file not found: $absoluteJsonPath');
      }

      result = await generateEntityFromJsonFile(
        jsonFilePath: absoluteJsonPath,
        outputDir: absoluteOutputDir,
        entityName: entityName,
        generateJson: generateJson,
        generateCompareTo: generateCompare,
      );
    } else {
      // Generate from JSON object
      if (entityName == null || entityName.isEmpty) {
        throw Exception('"name" is required when using "json" directly');
      }

      final fileName = _toSnakeCase(entityName) + '.dart';
      final outputPath = p.join(absoluteOutputDir, fileName);

      // Create directory if it doesn't exist
      await Directory(absoluteOutputDir).create(recursive: true);

      final genResult = generateEntityFromJsonString(
        jsonString: jsonEncode(jsonData),
        entityName: entityName,
        outputFileName: fileName,
        generateJson: generateJson,
        generateCompareTo: generateCompare,
      );

      // Write the file
      await File(outputPath).writeAsString(genResult.content);

      result = GenerateFromJsonResult(
        entityName: genResult.entityName,
        filePath: outputPath,
        content: genResult.content,
        nestedEntityNames: genResult.nestedEntityNames,
      );
    }

    final buffer = StringBuffer();
    buffer.writeln('Generated morphy entity from JSON:');
    buffer.writeln('  Entity: ${result.entityName}');
    buffer.writeln('  File: ${result.filePath}');
    if (result.nestedEntityNames.isNotEmpty) {
      buffer.writeln(
        '  Nested entities: ${result.nestedEntityNames.join(', ')}',
      );
    }
    buffer.writeln('');
    buffer.writeln('Next steps:');
    buffer.writeln('  1. Run: morphy generate');
    buffer.writeln(
      '  2. Or: dart run build_runner build --delete-conflicting-outputs',
    );

    return GenerateResult(
      message: buffer.toString(),
      generatedFiles: [result.filePath],
    );
  }

  /// Convert PascalCase to snake_case
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

  /// Run the clean command
  Future<String> _runClean(Map<String, dynamic> args) async {
    final directory = args['directory'] as String? ?? Directory.current.path;
    final dryRun = args['dry_run'] as bool? ?? false;

    final absoluteDir = p.normalize(p.absolute(directory));

    if (!Directory(absoluteDir).existsSync()) {
      throw Exception('Directory not found: $absoluteDir');
    }

    final morphyFiles = <String>[];
    final glob = Glob('**.morphy.dart');

    await for (final entity in glob.list(root: absoluteDir)) {
      if (entity is File) {
        morphyFiles.add(entity.path);
      }
    }

    if (morphyFiles.isEmpty) {
      return 'No .morphy.dart files found in $absoluteDir';
    }

    if (dryRun) {
      final buffer = StringBuffer();
      buffer.writeln('Dry run - would delete ${morphyFiles.length} files:');
      for (final file in morphyFiles) {
        buffer.writeln('  - ${p.relative(file, from: absoluteDir)}');
      }
      return buffer.toString();
    }

    var deletedCount = 0;
    final errors = <String>[];

    for (final filePath in morphyFiles) {
      try {
        await File(filePath).delete();
        deletedCount++;
      } catch (e) {
        errors.add('${p.relative(filePath, from: absoluteDir)}: $e');
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('Cleaned $deletedCount .morphy.dart files');
    if (errors.isNotEmpty) {
      buffer.writeln('Errors:');
      for (final error in errors) {
        buffer.writeln('  - $error');
      }
    }

    return buffer.toString();
  }

  /// Find files matching include patterns but not exclude patterns
  Future<List<String>> _findFiles(
    String directory,
    List<String> includePatterns,
    List<String> excludePatterns,
  ) async {
    final files = <String>[];
    final excluded = <String>{};

    // Collect excluded files
    for (final pattern in excludePatterns) {
      final glob = Glob(pattern);
      await for (final entity in glob.list(root: directory)) {
        if (entity is File) {
          excluded.add(p.normalize(entity.path));
        }
      }
    }

    // Collect included files
    for (final pattern in includePatterns) {
      final glob = Glob(pattern);
      await for (final entity in glob.list(root: directory)) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final normalized = p.normalize(entity.path);
          if (!excluded.contains(normalized)) {
            files.add(normalized);
          }
        }
      }
    }

    return files.toSet().toList()..sort();
  }

  /// Process a single file and generate morphy code
  Future<String?> _processFile(
    String filePath,
    AnalysisContextCollection collection,
    String baseDir,
    bool deleteConflicting,
    bool verbose,
  ) async {
    final context = collection.contextFor(filePath);
    final result = await context.currentSession.getResolvedLibrary(filePath);

    if (result is! ResolvedLibraryResult) {
      return null;
    }

    final library = result.element;

    final morphyChecker = TypeChecker.fromRuntime(Morphy);
    final morphy2Checker = TypeChecker.fromRuntime(Morphy2);

    final annotatedElements = <_AnnotatedElement>[];

    for (final unit in library.units) {
      for (final classElement in unit.classes) {
        if (morphyChecker.hasAnnotationOf(classElement)) {
          final annotation = morphyChecker.firstAnnotationOf(classElement);
          if (annotation != null) {
            annotatedElements.add(
              _AnnotatedElement(
                element: classElement,
                annotation: ConstantReader(annotation),
              ),
            );
          }
        } else if (morphy2Checker.hasAnnotationOf(classElement)) {
          final annotation = morphy2Checker.firstAnnotationOf(classElement);
          if (annotation != null) {
            annotatedElements.add(
              _AnnotatedElement(
                element: classElement,
                annotation: ConstantReader(annotation),
              ),
            );
          }
        }
      }
    }

    if (annotatedElements.isEmpty) {
      return null;
    }

    // Collect all class elements for context
    final allClasses = <ClassElement>[];
    for (final unit in library.units) {
      allClasses.addAll(unit.classes);
    }

    // Generate code
    final generator = MorphyStandaloneGenerator();
    final output = StringBuffer();

    output.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    output.writeln('');
    output.writeln("part of '${p.basenameWithoutExtension(filePath)}.dart';");
    output.writeln('');
    output.writeln('// ignore_for_file: UNNECESSARY_CAST');
    output.writeln('// ignore_for_file: type=lint');
    output.writeln('');

    for (final annotated in annotatedElements) {
      final generated = await generator.generateForAnnotatedElement(
        annotated.element,
        annotated.annotation,
        allClasses,
      );

      if (generated.isNotEmpty) {
        output.writeln(generated);
        output.writeln('');
      }
    }

    // Write output file
    final outputPath = filePath.replaceAll('.dart', '.morphy.dart');

    if (deleteConflicting && File(outputPath).existsSync()) {
      await File(outputPath).delete();
    }

    await File(outputPath).writeAsString(output.toString());

    return outputPath;
  }

  /// List available resources (generated morphy files)
  Future<Map<String, dynamic>> _listResources(dynamic id) async {
    try {
      final resources = <Map<String, dynamic>>[];

      // Scan common directories for morphy files
      final directories = [
        'lib/src/domain/entities',
        'lib/src/domain',
        'lib/src',
        'lib',
        'test',
      ];

      for (final dirPath in directories) {
        try {
          final dir = Directory(dirPath);
          if (await dir.exists()) {
            await for (final entity in dir.list(recursive: true)) {
              try {
                if (entity is File && entity.path.endsWith('.morphy.dart')) {
                  final relativePath = entity.path;
                  final name = p.basenameWithoutExtension(
                    p.basenameWithoutExtension(relativePath),
                  );

                  resources.add({
                    'uri': 'file://${p.absolute(entity.path)}',
                    'name': name,
                    'description': 'Generated morphy file: $relativePath',
                    'mimeType': 'text/x-dart',
                  });
                }
              } catch (e) {
                stderr.writeln('Warning: Could not process file: $e');
              }
            }
          }
        } catch (e) {
          stderr.writeln('Warning: Could not scan directory $dirPath: $e');
        }
      }

      return {
        'jsonrpc': '2.0',
        'result': {'resources': resources},
        'id': id,
      };
    } catch (e) {
      stderr.writeln('Error listing resources: $e');
      return _error(id, -32603, 'Failed to list resources: ${e.toString()}');
    }
  }

  /// Read a resource's contents
  Future<Map<String, dynamic>> _readResource(
    dynamic id,
    Map<String, dynamic> params,
  ) async {
    final uri = params['uri'] as String?;

    if (uri == null) {
      return _error(id, -32602, 'Missing uri parameter');
    }

    try {
      final file = File(uri.replaceFirst('file://', ''));
      if (!await file.exists()) {
        return _error(id, -32602, 'Resource not found: $uri');
      }

      final contents = await file.readAsString();

      return {
        'jsonrpc': '2.0',
        'result': {
          'contents': [
            {'uri': uri, 'mimeType': 'text/x-dart', 'text': contents},
          ],
        },
        'id': id,
      };
    } catch (e) {
      return _error(id, -32603, 'Error reading resource: ${e.toString()}');
    }
  }

  /// Create a success response
  Map<String, dynamic> _success(dynamic id, Map<String, dynamic> result) {
    return {'jsonrpc': '2.0', 'result': result, 'id': id};
  }

  /// Create an error response
  Map<String, dynamic> _error(dynamic id, int code, String message) {
    return {
      'jsonrpc': '2.0',
      'error': {'code': code, 'message': message},
      'id': id,
    };
  }

  /// Send resource change notification
  void _sendResourceNotification(String changeType, String uri) {
    final notification = {
      'jsonrpc': '2.0',
      'method': 'notifications/resources/list_changed',
      'params': {
        'changes': [
          {'type': changeType, 'uri': 'file://$uri'},
        ],
      },
    };
    stdout.writeln(jsonEncode(notification));
  }
}

/// Result of a generate operation
class GenerateResult {
  final String message;
  final List<String> generatedFiles;

  GenerateResult({required this.message, required this.generatedFiles});
}

/// Internal class to hold annotated element info
class _AnnotatedElement {
  final ClassElement element;
  final ConstantReader annotation;

  _AnnotatedElement({required this.element, required this.annotation});
}
