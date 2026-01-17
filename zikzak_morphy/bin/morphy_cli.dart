import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;
import 'package:source_gen/source_gen.dart';
import 'package:watcher/watcher.dart';
import 'package:zikzak_morphy_annotation/morphy_annotation.dart';

import 'morphy_standalone_generator.dart';

class BuildResult {
  final bool success;
  final List<String> generatedFiles;
  final int successCount;
  final int skippedCount;
  final int errorCount;

  BuildResult({
    required this.success,
    required this.generatedFiles,
    required this.successCount,
    required this.skippedCount,
    required this.errorCount,
  });
}

class ProcessResult {
  final ProcessStatus status;
  final String? filePath;

  ProcessResult(this.status, [this.filePath]);
}

enum ProcessStatus { success, skipped, error }

class MorphyCli {
  final String directory;
  final List<String> includePatterns;
  final List<String> excludePatterns;
  final bool verbose;
  final bool deleteConflicting;
  final int concurrency;

  MorphyCli({
    required this.directory,
    required this.includePatterns,
    required this.excludePatterns,
    required this.verbose,
    required this.deleteConflicting,
    required this.concurrency,
  });

  void _log(String message) {
    if (verbose) {
      print('[morphy] $message');
    }
  }

  Future<BuildResult> build() async {
    _log('Starting build in $directory');

    // Find all matching files
    final files = await _findFiles();
    if (files.isEmpty) {
      print('No files found matching the include patterns.');
      return BuildResult(
        success: true,
        generatedFiles: [],
        successCount: 0,
        skippedCount: 0,
        errorCount: 0,
      );
    }

    _log('Found ${files.length} files to process');

    // Create analysis context
    final collection = AnalysisContextCollection(
      includedPaths: [directory],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );

    // Process files
    final generatedFiles = <String>[];
    var successCount = 0;
    var errorCount = 0;
    var skippedCount = 0;

    // Process in batches for concurrency control
    final batches = _batchFiles(files, concurrency);

    for (final batch in batches) {
      final futures = batch.map((file) async {
        try {
          final result = await _processFile(file, collection);
          if (result.status == ProcessStatus.success &&
              result.filePath != null) {
            generatedFiles.add(result.filePath!);
            successCount++;
          } else if (result.status == ProcessStatus.skipped) {
            skippedCount++;
          } else {
            errorCount++;
          }
        } catch (e, stack) {
          stderr.writeln('Error processing $file: $e');
          if (verbose) {
            stderr.writeln(stack);
          }
          errorCount++;
        }
      });

      await Future.wait(futures);
    }

    // Check if any generated .morphy.dart files contain JsonSerializable annotations
    // and run build_runner if needed
    final jsonSerializableFiles = <String>[];
    for (final morphyFile in generatedFiles) {
      if (morphyFile.endsWith('.morphy.dart')) {
        try {
          final content = await File(morphyFile).readAsString();
          if (content.contains('@JsonSerializable')) {
            final entityFile = morphyFile.replaceAll('.morphy.dart', '.dart');
            if (File(entityFile).existsSync()) {
              jsonSerializableFiles.add(entityFile);
            }
          }
        } catch (e) {
          // Ignore errors when checking file content
        }
      }
    }

    // Run build_runner for files with JSON serialization
    if (jsonSerializableFiles.isNotEmpty) {
      try {
        // Find the project root (where pubspec.yaml is)
        var projectRoot = Directory(directory);
        var searchDir = Directory(directory);
        const maxIterations = 50;
        var iterations = 0;

        // Search up the directory tree for pubspec.yaml
        while (iterations < maxIterations) {
          if (File(p.join(searchDir.path, 'pubspec.yaml')).existsSync()) {
            projectRoot = searchDir;
            break;
          }

          final parent = searchDir.parent;
          if (parent.path == searchDir.path || searchDir.path == '/') {
            throw Exception(
              'Could not find pubspec.yaml in parent directories starting from $directory',
            );
          }

          searchDir = parent;
          iterations++;
        }

        if (verbose) {
          print(
            'Running build_runner for JSON serialization from: ${projectRoot.path}...',
          );
          print('Files to process: ${jsonSerializableFiles.length}');
        }

        // Build filter for all JSON serializable files
        final buildFilters = jsonSerializableFiles
            .map(
              (file) =>
                  '--build-filter=${p.relative(file, from: projectRoot.path)}',
            )
            .toList();

        if (verbose) {
          print('Build filters: $buildFilters');
        }

        final buildResult = await Process.run('dart', [
          'run',
          'build_runner',
          'build',
          ...buildFilters,
          '--delete-conflicting-outputs',
        ], workingDirectory: projectRoot.path);

        if (verbose && buildResult.stdout.isNotEmpty) {
          print('build_runner stdout: ${buildResult.stdout}');
        }
        if (buildResult.stderr.isNotEmpty) {
          print('build_runner stderr: ${buildResult.stderr}');
        }

        if (buildResult.exitCode == 0) {
          // Check which .g.dart files were created
          for (final entityFile in jsonSerializableFiles) {
            final gDartFile = entityFile.replaceAll('.dart', '.g.dart');
            if (File(gDartFile).existsSync()) {
              generatedFiles.add(gDartFile);
              if (verbose) {
                print('  Generated: ${p.relative(gDartFile, from: directory)}');
              }
            }
          }
        } else {
          print(
            '  Warning: build_runner failed with exit code ${buildResult.exitCode}',
          );
          if (buildResult.stdout.isNotEmpty) {
            print('  stdout: ${buildResult.stdout}');
          }
          if (buildResult.stderr.isNotEmpty) {
            print('  stderr: ${buildResult.stderr}');
          }
        }
      } catch (e) {
        print('  Warning: Could not run build_runner for .g.dart: $e');
      }
    }

    print(
      'Generated: ${generatedFiles.length}, Skipped: $skippedCount, Errors: $errorCount',
    );

    return BuildResult(
      success: errorCount == 0,
      generatedFiles: generatedFiles,
      successCount: successCount,
      skippedCount: skippedCount,
      errorCount: errorCount,
    );
  }

  Future<void> watch() async {
    print('Watching for changes in $directory...');
    print('Press Ctrl+C to stop.');

    // Initial build
    await build().then((result) {
      if (!result.success) {
        stderr.writeln('Initial build failed');
        exit(1);
      }
    });

    // Watch for changes
    final watcher = DirectoryWatcher(directory);

    await for (final event in watcher.events) {
      final path = event.path;

      // Skip generated files
      if (path.endsWith('.morphy.dart') ||
          path.endsWith('.g.dart') ||
          path.endsWith('.freezed.dart')) {
        continue;
      }

      // Only process Dart files
      if (!path.endsWith('.dart')) {
        continue;
      }

      // Check if file matches include/exclude patterns
      if (!_shouldProcess(path)) {
        continue;
      }

      print('');
      print('Change detected: ${p.relative(path, from: directory)}');

      final stopwatch = Stopwatch()..start();

      try {
        // Recreate context for the changed file
        final collection = AnalysisContextCollection(
          includedPaths: [directory],
          resourceProvider: PhysicalResourceProvider.INSTANCE,
        );

        final result = await _processFile(path, collection);
        stopwatch.stop();

        if (result.status == ProcessStatus.success) {
          print('✓ Regenerated in ${stopwatch.elapsedMilliseconds}ms');
        } else if (result.status == ProcessStatus.skipped) {
          _log('No morphy annotations found, skipped');
        }
      } catch (e) {
        stopwatch.stop();
        stderr.writeln('✗ Error: $e');
      }
    }
  }

  Future<List<String>> _findFiles() async {
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

  bool _shouldProcess(String filePath) {
    final relativePath = p.relative(filePath, from: directory);

    // Check exclusions first
    for (final pattern in excludePatterns) {
      if (Glob(pattern).matches(relativePath)) {
        return false;
      }
    }

    // Check inclusions
    for (final pattern in includePatterns) {
      if (Glob(pattern).matches(relativePath)) {
        return true;
      }
    }

    return false;
  }

  List<List<String>> _batchFiles(List<String> files, int batchSize) {
    final batches = <List<String>>[];
    for (var i = 0; i < files.length; i += batchSize) {
      final end = (i + batchSize < files.length) ? i + batchSize : files.length;
      batches.add(files.sublist(i, end));
    }
    return batches;
  }

  Future<ProcessResult> _processFile(
    String filePath,
    AnalysisContextCollection collection,
  ) async {
    _log('Processing: ${p.relative(filePath, from: directory)}');

    final context = collection.contextFor(filePath);
    final result = await context.currentSession.getResolvedLibrary(filePath);

    if (result is! ResolvedLibraryResult) {
      _log('Could not resolve library: $filePath');
      return ProcessResult(ProcessStatus.error);
    }

    final library = result.element;

    // Check for morphy annotations
    final morphyChecker = TypeChecker.fromRuntime(Morphy);
    final morphy2Checker = TypeChecker.fromRuntime(Morphy2);

    final annotatedElements = <AnnotatedElement>[];

    for (final unit in library.units) {
      for (final classElement in unit.classes) {
        if (morphyChecker.hasAnnotationOf(classElement)) {
          final annotation = morphyChecker.firstAnnotationOf(classElement);
          if (annotation != null) {
            annotatedElements.add(
              AnnotatedElement(
                element: classElement,
                annotation: ConstantReader(annotation),
                annotationType: AnnotationType.morphy,
              ),
            );
          }
        } else if (morphy2Checker.hasAnnotationOf(classElement)) {
          final annotation = morphy2Checker.firstAnnotationOf(classElement);
          if (annotation != null) {
            annotatedElements.add(
              AnnotatedElement(
                element: classElement,
                annotation: ConstantReader(annotation),
                annotationType: AnnotationType.morphy2,
              ),
            );
          }
        }
      }
    }

    if (annotatedElements.isEmpty) {
      return ProcessResult(ProcessStatus.skipped);
    }

    _log('Found ${annotatedElements.length} annotated classes');

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

    _log('Generated: ${p.relative(outputPath, from: directory)}');

    return ProcessResult(ProcessStatus.success, outputPath);
  }
}

enum AnnotationType { morphy, morphy2 }

class AnnotatedElement {
  final ClassElement element;
  final ConstantReader annotation;
  final AnnotationType annotationType;

  AnnotatedElement({
    required this.element,
    required this.annotation,
    required this.annotationType,
  });
}
