# @JsonKey Support Implementation

## Overview

This document describes the implementation of full `@JsonKey` annotation support in the ZikZak Morphy code generation package. The builder now correctly extracts, stores, and applies `@JsonKey` annotations from field definitions to the generated code.

## What Was Fixed

### Problem
Previously, the Morphy builder did not recognize or process `@JsonKey` annotations on abstract class fields. This meant that:
- Custom JSON field names (via `@JsonKey(name: 'custom_name')`) were ignored
- Default values were not applied
- Field ignore flags were not honored
- Custom serialization/deserialization functions were not passed through

### Solution
Implemented comprehensive `@JsonKey` support by:

1. **Added JsonKeyInfo class** (`lib/src/common/NameType.dart`)
   - Stores all `@JsonKey` parameters: `name`, `ignore`, `defaultValue`, `required`, `includeIfNull`, `toJson`, `fromJson`
   - Provides `toAnnotationString()` method to regenerate the annotation

2. **Modified NameTypeClassComment** to include `jsonKeyInfo` field
   - Stores extracted JsonKey information alongside field metadata

3. **Created extractJsonKeyInfo() helper** (`lib/src/common/helpers.dart`)
   - Extracts `@JsonKey` annotations from FieldElement using analyzer API
   - Safely handles all JsonKey parameters
   - Returns null if no JsonKey annotation is present

4. **Updated getAllFields()** to extract JsonKey info
   - Calls `extractJsonKeyInfo()` for each field
   - Stores result in NameTypeClassComment

5. **Updated getDistinctFields()** to preserve JsonKey info
   - Ensures jsonKeyInfo is not lost when processing fields

6. **Modified getProperties() and getPropertiesAbstract()**
   - Apply `@JsonKey` annotations to generated properties
   - Preserves all original annotation parameters

## Usage Example

### Input (Abstract Class Definition)

```dart
import 'package:zikzak_morphy_annotation/morphy_annotation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'user.morphy.dart';
part 'user.g.dart';

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
```

### Generated Output

```dart
@JsonSerializable(explicitToJson: true)
class User implements $User {
  final String id;

  @JsonKey(name: 'user_name')
  final String userName;

  @JsonKey(name: 'email', defaultValue: 'no-email@example.com')
  final String emailAddress;

  // ... rest of generated code
}

@JsonSerializable(explicitToJson: true)
class Profile implements $Profile {
  final String userId;
  final String displayName;

  @JsonKey(ignore: true)
  final String internalToken;

  // ... rest of generated code
}
```

### JSON Serialization Behavior

```dart
// Creating a user
var user = User(
  id: "123",
  userName: "john_doe",
  emailAddress: "john@example.com",
);

// Serializing to JSON
var json = user.toJson();
// Result: {
//   "id": "123",
//   "user_name": "john_doe",  // Uses custom name from @JsonKey
//   "email": "john@example.com",  // Uses custom name from @JsonKey
//   "_className_": "User"
// }

// Deserializing from JSON with missing field
var json2 = {
  "id": "456",
  "user_name": "jane_doe",
  // email is missing - will use defaultValue
  "_className_": "User"
};
var user2 = User.fromJson(json2);
// user2.emailAddress will be "no-email@example.com" (defaultValue)

// Profile with ignored field
var profile = Profile(
  userId: "user123",
  displayName: "John Doe",
  internalToken: "secret-token-12345",
);

var profileJson = profile.toJson();
// internalToken is NOT included in JSON due to ignore: true
// Result: {
//   "userId": "user123",
//   "displayName": "John Doe",
//   "_className_": "Profile"
// }
```

## Supported @JsonKey Parameters

All standard `@JsonKey` parameters are now fully supported:

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `name` | String | Custom JSON field name | `@JsonKey(name: 'user_name')` |
| `ignore` | bool | Exclude field from JSON | `@JsonKey(ignore: true)` |
| `defaultValue` | dynamic | Default value when missing | `@JsonKey(defaultValue: 'default')` |
| `required` | bool | Mark field as required | `@JsonKey(required: true)` |
| `includeIfNull` | bool | Include null values in JSON | `@JsonKey(includeIfNull: false)` |
| `toJson` | Function | Custom serialization | `@JsonKey(toJson: _dateToJson)` |
| `fromJson` | Function | Custom deserialization | `@JsonKey(fromJson: _dateFromJson)` |

## Technical Implementation Details

### Files Modified

1. **`zikzak_morphy/lib/src/common/NameType.dart`**
   - Added `JsonKeyInfo` class
   - Added `jsonKeyInfo` field to `NameTypeClassComment`

2. **`zikzak_morphy/lib/src/common/helpers.dart`**
   - Added `extractJsonKeyInfo()` function
   - Updated `getAllFields()` to extract JsonKey info

3. **`zikzak_morphy/lib/src/helpers.dart`**
   - Updated `getDistinctFields()` to preserve jsonKeyInfo
   - Updated `getProperties()` to apply JsonKey annotations
   - Updated `getPropertiesAbstract()` to apply JsonKey annotations

### How It Works

1. **Extraction Phase**: When analyzing abstract class fields, the builder:
   - Checks each field's metadata for `@JsonKey` annotations
   - Extracts all parameter values using the analyzer's ConstantReader API
   - Stores the information in a `JsonKeyInfo` object

2. **Processing Phase**: During field processing:
   - JsonKeyInfo is preserved through all field transformations
   - Distinct field operations maintain the JsonKey metadata
   - Generic type resolution keeps JsonKey info intact

3. **Generation Phase**: When generating the final class:
   - Properties are annotated with reconstructed `@JsonKey` annotations
   - All original parameters are preserved exactly as specified
   - json_serializable then processes these annotations normally

## Benefits

1. **Full json_serializable Compatibility**: Works seamlessly with json_serializable's code generation
2. **Type Safety**: All JsonKey parameters are properly typed and validated
3. **Zero Breaking Changes**: Existing code without @JsonKey continues to work
4. **Clean Code**: Generated code looks hand-written with proper formatting
5. **Error Handling**: Gracefully handles missing or malformed JsonKey annotations

## Testing

A comprehensive test file has been created at `/example/test/jsonkey_test.dart` that demonstrates:
- Custom field names with `@JsonKey(name: ...)`
- Default values with `@JsonKey(defaultValue: ...)`
- Ignored fields with `@JsonKey(ignore: true)`
- Round-trip serialization/deserialization

## Dependencies

No new dependencies required. The implementation uses:
- `json_annotation: ^4.9.0` (already in zikzak_morphy_annotation)
- `analyzer` (already in zikzak_morphy)
- `source_gen` (already in zikzak_morphy)

## Migration Guide

For existing projects, no migration is needed! Simply:

1. Update to the latest zikzak_morphy version
2. Add `@JsonKey` annotations to your abstract class fields as needed
3. Run `dart run build_runner build` to regenerate

The builder maintains full backward compatibility with classes that don't use @JsonKey.

## Future Enhancements

Possible future improvements:
- Validation of JsonKey parameters at build time
- Better error messages for invalid JsonKey usage
- Support for custom JsonKey subclasses
- Integration with code completion tools

## Conclusion

The @JsonKey support implementation brings Morphy's JSON serialization capabilities to parity with hand-written json_serializable code, while maintaining all the benefits of Morphy's powerful code generation features.
