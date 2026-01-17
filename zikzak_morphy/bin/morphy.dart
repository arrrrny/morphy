import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:args/command_runner.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';
import 'package:zikzak_morphy_annotation/morphy_annotation.dart';

import 'morphy_cli.dart';
import 'morphy_json_parser.dart';
import 'morphy_standalone_generator.dart';

const String version = '2.9.1';

Future<void> main(List<String> arguments) async {
  final runner =
      CommandRunner<void>('morphy', 'Morphy - Fast code generator for Dart')
        ..addCommand(GenerateCommand())
        ..addCommand(FromJsonCommand())
        ..addCommand(CleanCommand())
        ..addCommand(AnalyzeCommand())
        ..argParser.addFlag(
          'version',
          abbr: 'v',
          negatable: false,
          help: 'Print the version.',
        );

  try {
    // Handle --version flag before running commands
    if (arguments.contains('--version') || arguments.contains('-v')) {
      print('morphy version $version');
      return;
    }

    // If no command specified, default to 'generate'
    if (arguments.isEmpty ||
        (!arguments.first.startsWith('-') &&
            ![
              'generate',
              'from-json',
              'clean',
              'analyze',
              'help',
            ].contains(arguments.first))) {
      // Treat first arg as directory for generate command
      await runner.run(['generate', ...arguments]);
    } else {
      await runner.run(arguments);
    }
  } on UsageException catch (e) {
    print(e);
    exit(1);
  } catch (e, stack) {
    stderr.writeln('Error: $e');
    stderr.writeln(stack);
    exit(1);
  }
}

/// Generate command - runs morphy code generation
class GenerateCommand extends Command<void> {
  @override
  final name = 'generate';

  @override
  final description = 'Generate morphy code for annotated Dart classes.';

  @override
  final aliases = ['gen', 'build'];

  GenerateCommand() {
    argParser
      ..addOption(
        'directory',
        abbr: 'd',
        help: 'The directory to process. Defaults to current directory.',
      )
      ..addFlag(
        'watch',
        abbr: 'w',
        negatable: false,
        help: 'Watch for file changes and regenerate.',
      )
      ..addFlag('verbose', negatable: false, help: 'Show verbose output.')
      ..addFlag(
        'delete-conflicting-outputs',
        negatable: false,
        defaultsTo: true,
        help: 'Delete conflicting outputs before generating.',
      )
      ..addMultiOption(
        'include',
        abbr: 'i',
        help: 'Glob patterns to include (can be specified multiple times).',
        defaultsTo: ['lib/src/domain/entities/**.dart'],
      )
      ..addMultiOption(
        'exclude',
        abbr: 'e',
        help: 'Glob patterns to exclude (can be specified multiple times).',
        defaultsTo: ['**/*.g.dart', '**/*.morphy.dart', '**/*.freezed.dart'],
      )
      ..addOption(
        'concurrency',
        abbr: 'j',
        help: 'Number of concurrent file processes.',
        defaultsTo: '4',
      );
  }

  @override
  Future<void> run() async {
    // Get the directory to process (--directory option takes precedence over positional arg)
    String directory;
    final directoryOption = argResults!['directory'] as String?;
    if (directoryOption != null && directoryOption.isNotEmpty) {
      directory = directoryOption;
    } else if (argResults!.rest.isNotEmpty) {
      directory = argResults!.rest.first;
    } else {
      directory = Directory.current.path;
    }

    // Resolve to absolute path
    directory = p.normalize(p.absolute(directory));

    if (!Directory(directory).existsSync()) {
      stderr.writeln('Error: Directory not found: $directory');
      exit(1);
    }

    final cli = MorphyCli(
      directory: directory,
      includePatterns: argResults!['include'] as List<String>,
      excludePatterns: argResults!['exclude'] as List<String>,
      verbose: argResults!['verbose'] as bool,
      deleteConflicting: argResults!['delete-conflicting-outputs'] as bool,
      concurrency: int.tryParse(argResults!['concurrency'] as String) ?? 4,
    );

    if (argResults!['watch'] as bool) {
      await cli.watch();
    } else {
      final stopwatch = Stopwatch()..start();
      final result = await cli.build();
      stopwatch.stop();

      if (result.success) {
        print('✓ Generation completed in ${stopwatch.elapsedMilliseconds}ms');
        exit(0);
      } else {
        stderr.writeln('✗ Generation failed');
        exit(1);
      }
    }
  }
}

/// From-JSON command - generates morphy entity from JSON file
class FromJsonCommand extends Command<void> {
  @override
  final name = 'from-json';

  @override
  final description =
      'Generate a morphy entity class from a JSON file.\n\n'
      'Creates entity in its own subdirectory (e.g., entities/product/product.dart)\n'
      'and automatically generates the .morphy.dart file.\n\n'
      'The JSON file defines the structure of the entity. Field names ending\n'
      'with "?" will be nullable (e.g., "lastName?": "Doe" becomes String? get lastName).\n\n'
      'Example JSON:\n'
      '  {\n'
      '    "id": "user_001",\n'
      '    "name": "John",\n'
      '    "lastName?": "Doe",\n'
      '    "age": 30,\n'
      '    "isActive": true\n'
      '  }';

  @override
  final aliases = ['json', 'fj'];

  FromJsonCommand() {
    argParser
      ..addOption(
        'name',
        abbr: 'n',
        help:
            'Entity name (PascalCase). Inferred from file name if not provided.',
      )
      ..addOption(
        'output',
        abbr: 'o',
        help:
            'Base output directory. Entity will be created in a subdirectory named after the entity.',
        defaultsTo: 'lib/src/domain/entities',
      )
      ..addFlag(
        'json',
        abbr: 'j',
        help:
            'Generate JSON serialization support (adds @Morphy(generateJson: true)).',
        defaultsTo: false,
      )
      ..addFlag(
        'compare',
        abbr: 'c',
        help: 'Generate compareTo support.',
        defaultsTo: true,
      )
      ..addFlag(
        'prefix-nested',
        abbr: 'p',
        help:
            'Prefix nested entity names with parent name (e.g., Order.customer becomes OrderCustomer).',
        defaultsTo: true,
      )
      ..addFlag('verbose', negatable: false, help: 'Show verbose output.');
  }

  @override
  String get invocation => '${runner!.executableName} $name <json-file>';

  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) {
      usageException('Missing required argument: <json-file>');
    }

    final jsonFilePath = argResults!.rest.first;
    final entityName = argResults!['name'] as String?;
    final outputDir = argResults!['output'] as String;
    final generateJson = argResults!['json'] as bool;
    final generateCompareTo = argResults!['compare'] as bool;
    final prefixNested = argResults!['prefix-nested'] as bool;
    final verbose = argResults!['verbose'] as bool;

    // Resolve paths
    final absoluteJsonPath = p.absolute(jsonFilePath);
    final absoluteOutputDir = p.absolute(outputDir);

    if (!File(absoluteJsonPath).existsSync()) {
      stderr.writeln('Error: JSON file not found: $absoluteJsonPath');
      exit(1);
    }

    if (verbose) {
      print('Reading JSON from: $absoluteJsonPath');
      print('Output directory: $absoluteOutputDir');
    }

    try {
      // Infer entity name from file if not provided
      final effectiveEntityName =
          entityName ?? _toPascalCase(p.basenameWithoutExtension(jsonFilePath));

      // Create entity subdirectory: entities/product/product.dart
      final entitySnakeCase = _toSnakeCase(effectiveEntityName);
      final entitySubDir = p.join(absoluteOutputDir, entitySnakeCase);

      await Directory(entitySubDir).create(recursive: true);

      final result = await generateEntityFromJsonFile(
        jsonFilePath: absoluteJsonPath,
        outputDir: entitySubDir,
        entityName: effectiveEntityName,
        generateJson: generateJson,
        generateCompareTo: generateCompareTo,
        prefixNestedEntities: prefixNested,
      );

      print('✓ Generated entity: ${result.entityName}');
      print('  File: ${result.filePath}');

      if (result.nestedEntityNames.isNotEmpty) {
        print('  Nested entities: ${result.nestedEntityNames.join(', ')}');
      }

      // Auto-generate the .morphy.dart file
      String? morphyFilePath;
      try {
        final collection = AnalysisContextCollection(
          includedPaths: [entitySubDir],
          resourceProvider: PhysicalResourceProvider.INSTANCE,
        );

        morphyFilePath = await _processEntityFile(result.filePath, collection);

        if (morphyFilePath != null) {
          print('  Morphy: $morphyFilePath');
        }
      } catch (e) {
        if (verbose) {
          print('  Warning: Could not auto-generate .morphy.dart: $e');
        }
      }

      // Auto-generate the .g.dart file using build_runner if generateJson is true
      if (generateJson) {
        try {
          // Find the project root (where pubspec.yaml is)
          var projectRoot = Directory(entitySubDir);
          while (!File(p.join(projectRoot.path, 'pubspec.yaml')).existsSync()) {
            final parent = projectRoot.parent;
            if (parent.path == projectRoot.path) {
              throw Exception(
                'Could not find pubspec.yaml in parent directories',
              );
            }
            projectRoot = parent;
          }

          print('  Running build_runner for JSON serialization...');

          // Run build_runner on the specific file
          final buildResult = await Process.run('dart', [
            'run',
            'build_runner',
            'build',
            '--build-filter=${p.relative(result.filePath, from: projectRoot.path)}',
            '--delete-conflicting-outputs',
          ], workingDirectory: projectRoot.path);

          if (buildResult.exitCode == 0) {
            final gDartFilePath = result.filePath.replaceAll(
              '.dart',
              '.g.dart',
            );
            if (File(gDartFilePath).existsSync()) {
              print('  JSON: $gDartFilePath');
            } else {
              print('  Warning: .g.dart file not created by build_runner');
            }
          } else {
            print('  Warning: build_runner failed: ${buildResult.stderr}');
          }
        } catch (e) {
          print('  Warning: Could not run build_runner for .g.dart: $e');
        }
      }

      if (verbose) {
        print('\nGenerated content:');
        print('─' * 50);
        print(result.content);
      }
    } catch (e) {
      stderr.writeln('Error: $e');
      exit(1);
    }
  }

  /// Convert snake_case to PascalCase
  String _toPascalCase(String input) {
    return input
        .split(RegExp(r'[_\-\s]+'))
        .map(
          (word) => word.isEmpty
              ? ''
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join('');
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

  /// Process entity file to generate .morphy.dart
  Future<String?> _processEntityFile(
    String filePath,
    AnalysisContextCollection collection,
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

    if (File(outputPath).existsSync()) {
      await File(outputPath).delete();
    }

    await File(outputPath).writeAsString(output.toString());

    return outputPath;
  }
}

class _AnnotatedElement {
  final ClassElement element;
  final ConstantReader annotation;

  _AnnotatedElement({required this.element, required this.annotation});
}

/// Clean command - removes generated .morphy.dart files
class CleanCommand extends Command<void> {
  @override
  final name = 'clean';

  @override
  final description = 'Remove all generated .morphy.dart files.';

  CleanCommand() {
    argParser
      ..addOption(
        'directory',
        abbr: 'd',
        help: 'The directory to clean. Defaults to current directory.',
      )
      ..addFlag(
        'dry-run',
        help: 'Preview files that would be deleted without deleting them.',
        defaultsTo: false,
      )
      ..addFlag('verbose', negatable: false, help: 'Show verbose output.');
  }

  @override
  Future<void> run() async {
    // Get the directory (--directory option takes precedence over positional arg)
    String directory;
    final directoryOption = argResults!['directory'] as String?;
    if (directoryOption != null && directoryOption.isNotEmpty) {
      directory = directoryOption;
    } else if (argResults!.rest.isNotEmpty) {
      directory = argResults!.rest.first;
    } else {
      directory = Directory.current.path;
    }

    directory = p.normalize(p.absolute(directory));

    if (!Directory(directory).existsSync()) {
      stderr.writeln('Error: Directory not found: $directory');
      exit(1);
    }

    final dryRun = argResults!['dry-run'] as bool;
    final verbose = argResults!['verbose'] as bool;

    final morphyFiles = <String>[];

    await for (final entity in Directory(directory).list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.morphy.dart')) {
        morphyFiles.add(entity.path);
      }
    }

    if (morphyFiles.isEmpty) {
      print('No .morphy.dart files found in $directory');
      return;
    }

    if (dryRun) {
      print('Dry run - would delete ${morphyFiles.length} files:');
      for (final file in morphyFiles) {
        print('  - ${p.relative(file, from: directory)}');
      }
      return;
    }

    var deletedCount = 0;
    for (final filePath in morphyFiles) {
      try {
        await File(filePath).delete();
        deletedCount++;
        if (verbose) {
          print('Deleted: ${p.relative(filePath, from: directory)}');
        }
      } catch (e) {
        stderr.writeln('Error deleting $filePath: $e');
      }
    }

    print('✓ Cleaned $deletedCount .morphy.dart files');
  }
}

/// Analyze command - lists classes with morphy annotations
class AnalyzeCommand extends Command<void> {
  @override
  final name = 'analyze';

  @override
  final description =
      'Analyze Dart files and list classes with morphy annotations.';

  AnalyzeCommand() {
    argParser
      ..addOption(
        'directory',
        abbr: 'd',
        help: 'The directory to analyze. Defaults to current directory.',
      )
      ..addMultiOption(
        'include',
        abbr: 'i',
        help: 'Glob patterns to include.',
        defaultsTo: ['lib/src/domain/entities/**.dart'],
      )
      ..addFlag('verbose', negatable: false, help: 'Show verbose output.');
  }

  @override
  Future<void> run() async {
    // Get the directory (--directory option takes precedence over positional arg)
    String directory;
    final directoryOption = argResults!['directory'] as String?;
    if (directoryOption != null && directoryOption.isNotEmpty) {
      directory = directoryOption;
    } else if (argResults!.rest.isNotEmpty) {
      directory = argResults!.rest.first;
    } else {
      directory = Directory.current.path;
    }

    directory = p.normalize(p.absolute(directory));

    if (!Directory(directory).existsSync()) {
      stderr.writeln('Error: Directory not found: $directory');
      exit(1);
    }

    final includePatterns = argResults!['include'] as List<String>;
    final verbose = argResults!['verbose'] as bool;
    final excludePatterns = [
      '**/*.g.dart',
      '**/*.morphy.dart',
      '**/*.freezed.dart',
    ];

    // Find files matching patterns
    final files = await _findFiles(directory, includePatterns, excludePatterns);

    if (files.isEmpty) {
      print('No files found matching patterns: $includePatterns');
      return;
    }

    print('Morphy Analysis Report');
    print('=' * 50);
    print('Directory: $directory');
    print('Files scanned: ${files.length}');
    print('');

    // Create analysis context
    final collection = AnalysisContextCollection(
      includedPaths: [directory],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );

    final morphyChecker = TypeChecker.fromRuntime(Morphy);
    final morphy2Checker = TypeChecker.fromRuntime(Morphy2);

    var totalAnnotated = 0;

    for (final filePath in files) {
      try {
        final context = collection.contextFor(filePath);
        final result = await context.currentSession.getResolvedLibrary(
          filePath,
        );

        if (result is! ResolvedLibraryResult) {
          if (verbose) {
            print(
              '${p.relative(filePath, from: directory)}: Could not resolve',
            );
          }
          continue;
        }

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
          print('${p.relative(filePath, from: directory)}:');
          for (final className in annotatedClasses) {
            print('  • $className');
          }
        } else if (verbose) {
          print('${p.relative(filePath, from: directory)}: No annotations');
        }
      } catch (e) {
        if (verbose) {
          print('${p.relative(filePath, from: directory)}: Error - $e');
        }
      }
    }

    print('');
    print('Total annotated classes: $totalAnnotated');
  }

  Future<List<String>> _findFiles(
    String directory,
    List<String> includePatterns,
    List<String> excludePatterns,
  ) async {
    final files = <String>[];
    final excluded = <String>{};

    // First, collect excluded files
    for (final pattern in excludePatterns) {
      final glob = Glob(pattern);
      await for (final entity in glob.list(root: directory)) {
        if (entity is File) {
          excluded.add(p.normalize(entity.path));
        }
      }
    }

    // Then collect included files
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
}
