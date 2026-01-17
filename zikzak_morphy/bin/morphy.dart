import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'morphy_cli.dart';
import 'morphy_json_parser.dart';

const String version = '2.9.0';

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
    // Get the directory to process
    String directory;
    if (argResults!.rest.isEmpty) {
      directory = Directory.current.path;
    } else {
      directory = argResults!.rest.first;
    }

    // Resolve to absolute path
    directory = p.absolute(directory);

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
      final success = await cli.build();
      stopwatch.stop();

      if (success) {
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
        help: 'Output directory for generated entity file.',
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
      final result = await generateEntityFromJsonFile(
        jsonFilePath: absoluteJsonPath,
        outputDir: absoluteOutputDir,
        entityName: entityName,
        generateJson: generateJson,
        generateCompareTo: generateCompareTo,
      );

      print('✓ Generated entity: ${result.entityName}');
      print('  File: ${result.filePath}');

      if (result.nestedEntityNames.isNotEmpty) {
        print('  Nested entities: ${result.nestedEntityNames.join(', ')}');
      }

      if (verbose) {
        print('\nGenerated content:');
        print('─' * 50);
        print(result.content);
      }

      print('\n📝 Next steps:');
      print(
        '   1. Run: dart run build_runner build --delete-conflicting-outputs',
      );
      print('   2. Or use: morphy generate');
    } catch (e) {
      stderr.writeln('Error: $e');
      exit(1);
    }
  }
}

/// Clean command - removes generated .morphy.dart files
class CleanCommand extends Command<void> {
  @override
  final name = 'clean';

  @override
  final description = 'Remove all generated .morphy.dart files.';

  CleanCommand() {
    argParser
      ..addFlag(
        'dry-run',
        help: 'Preview files that would be deleted without deleting them.',
        defaultsTo: false,
      )
      ..addFlag('verbose', negatable: false, help: 'Show verbose output.');
  }

  @override
  Future<void> run() async {
    String directory;
    if (argResults!.rest.isEmpty) {
      directory = Directory.current.path;
    } else {
      directory = argResults!.rest.first;
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
    String directory;
    if (argResults!.rest.isEmpty) {
      directory = Directory.current.path;
    } else {
      directory = argResults!.rest.first;
    }

    directory = p.normalize(p.absolute(directory));

    if (!Directory(directory).existsSync()) {
      stderr.writeln('Error: Directory not found: $directory');
      exit(1);
    }

    final cli = MorphyCli(
      directory: directory,
      includePatterns: argResults!['include'] as List<String>,
      excludePatterns: ['**/*.g.dart', '**/*.morphy.dart', '**/*.freezed.dart'],
      verbose: argResults!['verbose'] as bool,
      deleteConflicting: false,
      concurrency: 4,
    );

    // Note: MorphyCli.analyze() would need to be implemented
    // For now, just run build with dry-run behavior
    print('Analyzing $directory...');
    print('(Use morphy generate --verbose for detailed analysis)');
  }
}
