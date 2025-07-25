// ignore_for_file: unnecessary_cast

import 'package:test/test.dart';
import 'package:zikzak_morphy_annotation/morphy_annotation.dart';

part 'ex46_json_test.g.dart';
part 'ex46_json_test.morphy.dart';

main() {
  test("1 toJson", () {
    var a = Pet(kind: "cat");

    expect(a.toJson(), {'kind': 'cat', '_className_': 'Pet'});
  });

  test("2 fromJson", () {
    var a = Pet.fromJson({'kind': 'cat', '_className_': 'Pet'});

    expect(a.toString(), '(Pet-kind:cat)');
  });
}

@Morphy(generateJson: true)
abstract class $Pet {
  String get kind;
}
