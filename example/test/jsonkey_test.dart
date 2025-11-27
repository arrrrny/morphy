import 'package:test/test.dart';
import 'package:zikzak_morphy_annotation/morphy_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'jsonkey_test.g.dart';
part 'jsonkey_test.morphy.dart';

/// Test @JsonKey annotation support
main() {
  test("1 - @JsonKey with name parameter", () {
    var user = User(
      id: "123",
      userName: "john_doe",
      emailAddress: "john@example.com",
    );

    var json = user.toJson();
    print("JSON output: $json");

    // The JSON should use the @JsonKey name values
    expect(json['id'], '123');
    expect(json['user_name'], 'john_doe'); // Should be user_name, not userName
    expect(json['email'], 'john@example.com'); // Should be email, not emailAddress
    expect(json['_className_'], 'User');
  });

  test("2 - @JsonKey fromJson with name parameter", () {
    var json = {
      'id': '456',
      'user_name': 'jane_doe',
      'email': 'jane@example.com',
      '_className_': 'User'
    };

    var user = User.fromJson(json);
    print("User from JSON: ${user.toString()}");

    expect(user.id, '456');
    expect(user.userName, 'jane_doe');
    expect(user.emailAddress, 'jane@example.com');
  });

  test("3 - @JsonKey with defaultValue", () {
    var json = {
      'id': '789',
      'user_name': 'default_user',
      // email is missing, should use default value
      '_className_': 'User'
    };

    var user = User.fromJson(json);

    expect(user.id, '789');
    expect(user.userName, 'default_user');
    expect(user.emailAddress, 'no-email@example.com'); // Should use defaultValue
  });

  test("4 - @JsonKey with ignore", () {
    var profile = Profile(
      userId: "user123",
      displayName: "John Doe",
      internalToken: "secret-token-12345",
    );

    var json = profile.toJson();
    print("Profile JSON: $json");

    expect(json['userId'], 'user123');
    expect(json['displayName'], 'John Doe');
    // internalToken should NOT be in JSON due to ignore: true
    expect(json.containsKey('internalToken'), false);
  });
}

@Morphy(generateJson: true)
abstract class $User {
  String get id;

  @JsonKey(name: 'user_name')
  String get userName;

  @JsonKey(name: 'email', defaultValue: 'no-email@example.com')
  String get emailAddress;
}

@Morphy(generateJson: true)
abstract class $Profile {
  String get userId;
  String get displayName;

  @JsonKey(ignore: true)
  String get internalToken;
}
