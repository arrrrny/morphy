class NameType {
  final String name;
  final String? type;
  final bool isEnum;

  NameType(this.name, this.type, {this.isEnum = false});

  toString() => "${this.name}:${this.type}";
}

class NameTypeClass extends NameType {
  final String? className;

  NameTypeClass(
    String name,
    String? type,
    this.className, {
    bool isEnum = false,
  }) : super(name, type, isEnum: isEnum);

  toString() => "${this.name}:${this.type}:${this.className}";
  toStringNameType() => super.toString();
}

class NameTypeClassComment extends NameTypeClass {
  final String? comment;
  final JsonKeyInfo? jsonKeyInfo;

  NameTypeClassComment(
    String name,
    String? type,
    String? _class, {
    this.comment,
    this.jsonKeyInfo,
    bool isEnum = false,
  }) : super(name, type, _class, isEnum: isEnum);
}

/// Stores @JsonKey annotation information for a field
class JsonKeyInfo {
  final String? name;
  final bool? ignore;
  final dynamic defaultValue;
  final bool? required;
  final bool? includeIfNull;
  final bool? includeFromJson;
  final bool? includeToJson;
  final String? toJson;
  final String? fromJson;

  JsonKeyInfo({
    this.name,
    this.ignore,
    this.defaultValue,
    this.required,
    this.includeIfNull,
    this.includeFromJson,
    this.includeToJson,
    this.toJson,
    this.fromJson,
  });

  /// Returns the @JsonKey annotation string to be applied to a field
  String toAnnotationString() {
    if (ignore == true) {
      return '@JsonKey(ignore: true)';
    }

    List<String> params = [];

    if (name != null) {
      params.add("name: '$name'");
    }
    if (defaultValue != null) {
      if (defaultValue is String) {
        params.add("defaultValue: '$defaultValue'");
      } else {
        params.add("defaultValue: $defaultValue");
      }
    }
    if (required != null) {
      params.add("required: $required");
    }
    if (includeIfNull != null) {
      params.add("includeIfNull: $includeIfNull");
    }
    if (includeFromJson != null) {
      params.add("includeFromJson: $includeFromJson");
    }
    if (includeToJson != null) {
      params.add("includeToJson: $includeToJson");
    }
    if (toJson != null) {
      params.add("toJson: $toJson");
    }
    if (fromJson != null) {
      params.add("fromJson: $fromJson");
    }

    if (params.isEmpty) {
      return '';
    }

    return '@JsonKey(${params.join(', ')})';
  }
}

class NameTypeClassCommentData<TMeta1> extends NameTypeClassComment {
  final TMeta1? meta1;

  NameTypeClassCommentData(
    String name,
    String? type,
    String? _class, {
    this.meta1,
    String? comment,
    bool isEnum = false,
  }) : super(name, type, _class, comment: comment, isEnum: isEnum);
}
