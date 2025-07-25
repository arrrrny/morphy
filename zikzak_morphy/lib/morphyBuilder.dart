import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:zikzak_morphy_annotation/morphy_annotation.dart';
import 'package:zikzak_morphy/src/MorphyGenerator.dart';

Builder morphyBuilder(BuilderOptions options) => //
PartBuilder(
  [MorphyGenerator<Morphy>()],
  '.morphy.dart',
  header: '''
// ignore_for_file: UNNECESSARY_CAST
// ignore_for_file: type=lint
''',
);
