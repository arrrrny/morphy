import 'package:zikzak_morphy_annotation/morphy_annotation.dart';
import 'package:test/test.dart';

// ignore_for_file: UNNECESSARY_CAST

part 'ex29_copywith_subclasses_test.morphy.dart';

///Copywith from subclass to superclass & superclass to subclass

//superclass
@Morphy(generateCopyWithFn: true)
abstract class $$A {
  String get a;
}

//subclass with a generic type and property of that same generic
@Morphy(generateCopyWithFn: true)
abstract class $B<T1> implements $$A {
  String get a;

  T1 get b;
}

//subclass of B with same generic
@Morphy(generateCopyWithFn: true)
abstract class $C<T1> implements $B<T1> {
  String get a;

  T1 get b;

  bool get c;
}

@Morphy(generateCopyWithFn: true)
abstract class $D<T1> implements $B<T1> {
  String get a;

  T1 get b;
}

@Morphy(generateCopyWithFn: true)
abstract class $$X {}

@Morphy(generateCopyWithFn: true)
abstract class $Y implements $$X {
  String get a;
}

main() {
  test("ba", () {
    A ba = B(b: 5, a: "A");
    A ba_copy = ba.copyWithAFn(a: () => "a");
    expect(ba_copy.toString(), "(B-a:a|b:5)");
  });

  test("bb", () {
    B bb = B(b: 5, a: "A");
    B bb_copy = bb.copyWithBFn(a: () => "a", b: () => 6);
    expect(bb_copy.toString(), "(B-a:a|b:6)");
  });

  test("ca", () {
    A ca = C(b: 5, a: "A", c: true);
    A ca_copy = ca.copyWithAFn(a: () => "a");
    expect(ca_copy.toString(), "(C-a:a|b:5|c:true)");
  });

  test("cb", () {
    B cb = C(b: 5, a: "A", c: true);
    B cb_copy = cb.copyWithBFn(a: () => "a", b: () => 6);
    expect(cb_copy.toString(), "(C-a:a|b:6|c:true)");
  });

  test("cc", () {
    C cc = C(b: 5, a: "A", c: true);
    var cc_copy = cc.copyWithCFn(a: () => "a", b: () => 6, c: () => false);
    expect(cc_copy.toString(), "(C-a:a|b:6|c:false)");
  });

  test("da", () {
    D da = D(b: 5, a: "A");
    var da_copy = da.copyWithAFn(a: () => "a");
    expect(da_copy.toString(), "(D-a:a|b:5)");
  });

  test("db", () {
    D db = D(b: 5, a: "A");
    var db_copy = db.copyWithBFn(a: () => "a", b: () => 6) as D;
    expect(db_copy.toString(), "(D-a:a|b:6)");
  });

  test("dd", () {
    D dd = D(b: 5, a: "A");
    var dd_copy = dd.copyWithDFn(a: () => "a", b: () => 6);
    expect(dd_copy.toString(), "(D-a:a|b:6)");
  });

  test("yY", () {
    Y yy = Y(a: "A");
    var yy_copy = yy.copyWithY(a: "a");
    expect(yy_copy.toString(), "(Y-a:a)");
  });
}
