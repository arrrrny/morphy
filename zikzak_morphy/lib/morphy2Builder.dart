import 'package:build/build.dart';
import 'package:zikzak_morphy/src/MorphyGenerator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:zikzak_morphy_annotation/morphy_annotation.dart';

Builder morphy2Builder(BuilderOptions options) => //
PartBuilder(
  [MorphyGenerator<Morphy2>()],
  '.morphy2.dart', // Keep as .morphy2.dart
  header: '''
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
    ''',
);
