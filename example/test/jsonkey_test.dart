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
    expect(
      json['email'],
      'john@example.com',
    ); // Should be email, not emailAddress
    expect(json['_className_'], 'User');
  });

  test("2 - @JsonKey fromJson with name parameter", () {
    var json = {
      'id': '456',
      'user_name': 'jane_doe',
      'email': 'jane@example.com',
      '_className_': 'User',
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
      '_className_': 'User',
    };

    var user = User.fromJson(json);

    expect(user.id, '789');
    expect(user.userName, 'default_user');
    expect(
      user.emailAddress,
      'no-email@example.com',
    ); // Should use defaultValue
  });

  test("4 - @JsonKey with ignore", () {
    var profile = Profile(userId: "user123", displayName: "John Doe");

    var json = profile.toJson();
    print("Profile JSON: $json");

    expect(json['userId'], 'user123');
    expect(json['displayName'], 'John Doe');
    // internalToken should NOT be in JSON due to ignore: true
    expect(json.containsKey('internalToken'), false);
  });

  test("5 - @JsonKey with includeFromJson and includeToJson", () {
    var settings = Settings(theme: "dark", language: "en");

    var json = settings.toJson();
    print("Settings JSON: $json");

    // theme and language should be in JSON
    expect(json['theme'], 'dark');
    expect(json['language'], 'en');
    // debugMode should NOT be in JSON due to includeToJson: false
    expect(json.containsKey('debugMode'), false);
  });

  test("6 - @JsonKey with includeFromJson: false", () {
    var json = {
      'theme': 'light',
      'language': 'fr',
      'debugMode': true, // This should be ignored during deserialization
      '_className_': 'Settings',
    };

    var settings = Settings.fromJson(json);
    print("Settings from JSON: ${settings.toString()}");

    expect(settings.theme, 'light');
    expect(settings.language, 'fr');
    // debugMode should be null since includeFromJson: false
    expect(settings.debugMode, null);
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
  String? get internalToken;
}

@Morphy(generateJson: true)
abstract class $Settings {
  String get theme;
  String get language;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool? get debugMode;
}
