//see example project in github for more examples

//THE SIMPLEST OF EXAMPLES

import 'package:zikzak_morphy/zikzak_morphy.dart';
part 'example.morphy.dart';
part 'example.g.dart';

@Morphy(generateJson: true)
abstract class $Pet {
  String get type;
}
