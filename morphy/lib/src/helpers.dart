//import 'package:analyzer_models/analyzer_models.dart';
import 'package:dartx/dartx.dart';
import 'package:morphy/src/common/NameType.dart';
import 'package:morphy/src/common/classes.dart';
// import 'package:meta/meta.dart';

String getClassComment(List<Interface> interfaces, String classComment) {
  var a = interfaces
      .where((e) => e is InterfaceWithComment && e.comment != classComment) //
      .map((e) {
    var interfaceComment = e is InterfaceWithComment && e.comment != null //
        ? "\n${e.comment}"
        : "";
    return "///implements [${e.interfaceName}]\n///\n$interfaceComment\n///";
  }).toList();

  a.insert(0, classComment + "\n///");

  return a.join("\n").trim() + "\n";
}

/// remove dollars from the property type allowing for functions where
/// the dollars need to remain
String removeDollarsFromPropertyType(String propertyType) {
  var regex = RegExp("Function\((.*)\)");
  var result = regex.allMatches(propertyType);

  if (result.isNotEmpty) {
    return propertyType;
  }

  return propertyType.replaceAll(RegExp(r"(?<!<)(?<!<\$)\$\$?"), "");
}

List<NameTypeClassComment> getDistinctFields(
  List<NameTypeClassComment> fieldsRaw,
  List<InterfaceWithComment> interfaces,
) {
  var fields = fieldsRaw.map((f) => NameTypeClassComment(
      f.name, f.type, f.className?.replaceAll("\$", ""),
      comment: f.comment));

  var interfaces2 = interfaces //
      .map((x) => Interface.fromGenerics(
            x.interfaceName.replaceAll("\$", ""),
            x.typeParams,
            x.fields,
          ))
      .toList();
//
//    return Interface2(interface.type.replaceAll("\$", ""), result);
//  }).toList();

  var sortedFields =
      fields.sortedBy((element) => element.className ?? "").toList();
  var distinctFields =
      sortedFields.distinctBy((element) => element.name).toList();

  var adjustedFields = distinctFields.map((classField) {
    var i = interfaces2
        .where((x) => x.interfaceName == classField.className)
        .take(1)
        .toList();
    if (i.length > 0) {
      var paramNameType = i[0]
          .typeParams
          .where((interfaceGeneric) => //
              interfaceGeneric.name == classField.type)
          .toList();
      if (paramNameType.length > 0) {
        var name = removeDollarsFromPropertyType(paramNameType[0].type!);
        return NameTypeClassComment(classField.name, name, null,
            comment: classField.comment);
      }
    }

    var type = removeDollarsFromPropertyType(classField.type!);
    return NameTypeClassComment(classField.name, type, null,
        comment: classField.comment);
  }).toList();

  return adjustedFields;
}

String getClassDefinition({
  required bool isAbstract,
  required bool nonSealed,
  required String className,
}) {
  var _className = className.replaceAll("\$", "");

  if (isAbstract) {
    if (!nonSealed) {
      // Just generate a sealed class for $$-prefixed classes
      return "sealed class $_className";
    }
    return "abstract class $_className";
  }

  return "class $_className";
}

String getClassGenerics(List<NameType> generics) {
  if (generics.isEmpty) {
    return "";
  }

  var _generics = generics.map((e) {
    if (e.type == null) {
      return e.name;
    }

    return "${e.name} extends ${e.type}";
  }).joinToString(separator: ", ");

  return "<$_generics>";
}

String getExtendsGenerics(List<NameType> generics) {
  if (generics.isEmpty) {
    return "";
  }

  var _generics = generics //
      .map((e) => e.name)
      .joinToString(separator: ", ");

  return "<$_generics>";
}

String getImplements(List<Interface> interfaces, String className) {
  if (interfaces.isEmpty) {
    return "";
  }

  var types = interfaces.map((e) {
    var type = e.interfaceName.replaceAll("\$", "");

    if (e.typeParams.isEmpty) {
      return type;
    }

    return "${type}<${e.typeParams.map((e) => e.type).joinToString(separator: ", ")}>";
  }).joinToString(separator: ", ");

  return " implements $types";
}

String getEnumPropertyList(
    List<NameTypeClassComment> fields, String className) {
  if (fields.isEmpty) return '';

  String classNameTrim = '${className.replaceAll("\$", "")}';
  String enumName = '${classNameTrim}\$';

  var sb = StringBuffer();

  // Generate enum
  sb.writeln("enum $enumName {");
  sb.writeln(fields
      .map((e) => e.name.startsWith("_") ? e.name.substring(1) : e.name)
      .join(","));
  sb.writeln("}\n");

  // Generate patch class
  sb.writeln("class ${classNameTrim}Patch {");
  sb.writeln("  final Map<$enumName, dynamic> _patch = {};");
  sb.writeln();

  // Static factory methods
  sb.writeln(
      "  static ${classNameTrim}Patch create([Map<String, dynamic>? diff]) {");
  sb.writeln("    final patch = ${classNameTrim}Patch();");
  sb.writeln("    if (diff != null) {");
  sb.writeln("      diff.forEach((key, value) {");
  sb.writeln("        try {");
  sb.writeln(
      "          final enumValue = $enumName.values.firstWhere((e) => e.name == key);");
  sb.writeln("          if (value is Function) {");
  sb.writeln("            patch._patch[enumValue] = value();");
  sb.writeln("          } else {");
  sb.writeln("            patch._patch[enumValue] = value;");
  sb.writeln("          }");
  sb.writeln("        } catch (_) {}");
  sb.writeln("      });");
  sb.writeln("    }");
  sb.writeln("    return patch;");
  sb.writeln("  }");
  sb.writeln();

  // Convert to map method
  sb.writeln("  Map<$enumName, dynamic> toPatch() => Map.from(_patch);");
  sb.writeln();

  // Add toJson method
  sb.writeln("  Map<String, dynamic> toJson() {");
  sb.writeln("    final json = <String, dynamic>{};");
  sb.writeln("    _patch.forEach((key, value) {");
  sb.writeln("      if (value != null) {");
  sb.writeln("        if (value is DateTime) {");
  sb.writeln("          json[key.name] = value.toIso8601String();");
  sb.writeln("        } else if (value is List) {");
  sb.writeln(
      "          json[key.name] = value.map((e) => e?.toJson ?? e).toList();");
  sb.writeln("        } else {");
  sb.writeln("          json[key.name] = value?.toJson ?? value;");
  sb.writeln("        }");
  sb.writeln("      }");
  sb.writeln("    });");
  sb.writeln("    return json;");
  sb.writeln("  }");
  sb.writeln();

  // Add fromJson factory
  sb.writeln(
      "  static ${classNameTrim}Patch fromJson(Map<String, dynamic> json) {");
  sb.writeln("    return create(json);");
  sb.writeln("  }");
  sb.writeln();

  // Generate with methods
  for (var field in fields) {
    var name =
        field.name.startsWith("_") ? field.name.substring(1) : field.name;
    var type = getDataTypeWithoutDollars(field.type ?? "dynamic");

    sb.writeln("  ${classNameTrim}Patch with$name($type value) {");
    sb.writeln("    _patch[$enumName.$name] = value;");
    sb.writeln("    return this;");
    sb.writeln("  }");
    sb.writeln();
  }

  sb.writeln("}");

  return sb.toString();
}

/// remove dollars from the dataType except for function types
String getDataTypeWithoutDollars(String type) {
  var regex = RegExp("Function\((.*)\)");
  var result = regex.allMatches(type);

  if (result.isNotEmpty) {
    return type;
  }

  return type.replaceAll("\$", "");
}

String getProperties(List<NameTypeClassComment> fields) {
  return fields.map((e) {
    var line = "final ${getDataTypeWithoutDollars(e.type ?? "")} ${e.name};";
    var result = e.comment == null ? line : "${e.comment}\n$line";
    return result;
  }).join("\n");
}

String getPropertiesAbstract(List<NameTypeClassComment> fields) => //
    fields
        .map((e) => //
            e.comment == null
                ? "${getDataTypeWithoutDollars(e.type ?? "")} get ${e.name};" //
                : "${e.comment}\n${e.type} get ${e.name};")
        .join("\n");

String getConstructorRows(List<NameType> fields) => //
    fields
        .map((e) {
          var required =
              e.type!.substring(e.type!.length - 1) == "?" ? "" : "required ";
          var thisOrType = e.name.startsWith("_") ? "${e.type} " : "this.";
          var propertyName = e.name[0] == '_' ? e.name.substring(1) : e.name;
          return "$required$thisOrType$propertyName,";
        })
        .join("\n")
        .trim();

String getInitializer(List<NameType> fields) {
  var result = fields
      .where((e) => e.name.startsWith('_'))
      .map((e) {
        return "${e.name} = ${e.name.substring(1)}";
      })
      .join(",")
      .trim();

  var result2 = result.length > 0 ? " : $result" : "";
  return result2;
}

String getToString(List<NameType> fields, String className) {
  if (fields.isEmpty) {
    return """String toString() => "($className-)""";
  }

  var items = fields
      .map((e) => "${e.name}:\${${e.name}.toString()}")
      .joinToString(separator: "|");
  return """String toString() => "($className-$items)";""";
}

String getHashCode(List<NameType> fields) {
  if (fields.isEmpty) {
    return "";
  }

  var items =
      fields.map((e) => "${e.name}.hashCode").joinToString(separator: ", ");
  return """int get hashCode => hashObjects([$items]);""";
}

String getEquals(List<NameType> fields, String className) {
  var sb = StringBuffer();

  sb.write(
      "bool operator ==(Object other) => identical(this, other) || other is $className && runtimeType == other.runtimeType");

  sb.writeln(fields.isEmpty ? "" : " &&");

  sb.write(fields.map((e) {
    if ((e.type!.characters.take(5).string == "List<" ||
        e.type!.characters.take(4).string == "Set<")) {
      //todo: hack here, a nullable entry won't compare properly to an empty list
      if (e.type!.characters.last == "?") {
        return "(${e.name}??[]).equalUnorderedD(other.${e.name}??[])";
      } else {
        return "(${e.name}).equalUnorderedD(other.${e.name})";
      }
    }

    return "${e.name} == other.${e.name}";
  }).joinToString(separator: " && "));

  sb.write(";");

  return sb.toString();
}

String createJsonHeader(String className, List<NameType> classGenerics,
    bool privateConstructor, bool explicitToJson, bool generateCompareTo) {
  var sb = StringBuffer();

  if (!className.startsWith("\$\$")) {
    var jsonConstructorName =
        privateConstructor ? "constructor: 'forJsonDoNotUse'" : "";

    if (classGenerics.length > 0) //
      sb.writeln(
          "@JsonSerializable(explicitToJson: $explicitToJson, genericArgumentFactories: true, $jsonConstructorName)");
    else
      sb.writeln(
          "@JsonSerializable(explicitToJson: $explicitToJson, $jsonConstructorName)");
  }

  return sb.toString();
}

///[classFields] & [interfaceFields] should be renamed
/// for changeTo [classFields] and [className] is what we are copying from
/// and [interfaceFields] and [interfaceName] is what we are copying to
/// [classFields] can be an interface & [interfaceFields] can be a class!
String getCopyWith({
  required List<NameType> classFields,
  required List<NameType> interfaceFields,
  required String interfaceName,
  required String className,
  required bool isClassAbstract,
  required List<NameType> interfaceGenerics,
  bool isExplicitSubType = false,
}) {
  var sb = StringBuffer();
  var classNameTrimmed = className.replaceAll("\$", "");
  var interfaceNameTrimmed = interfaceName.replaceAll("\$", "");

  // var interfaceGenericString = interfaceGenerics //
  //     .map((e) => e.type == null //
  //         ? e.name
  //         : "${e.name} extends ${e.type}")
  //     .joinToString(separator: ", ");

  var interfaceGenericStringWithExtends = interfaceGenerics //
      .map((e) => e.type == null //
          ? e.name
          : "${e.name} extends ${e.type}")
      .joinToString(separator: ", ");

  if (interfaceGenericStringWithExtends.length > 0) {
    interfaceGenericStringWithExtends = "<$interfaceGenericStringWithExtends>";
  }

  var interfaceGenericStringNoExtends = interfaceGenerics //
      .map((e) => e.name)
      .joinToString(separator: ", ");

  if (interfaceGenericStringNoExtends.length > 0) {
    interfaceGenericStringNoExtends = "<$interfaceGenericStringNoExtends>";
  }

  isExplicitSubType //
      ? sb.write(
          "$interfaceNameTrimmed$interfaceGenericStringNoExtends changeTo$interfaceNameTrimmed$interfaceGenericStringWithExtends")
      : sb.write(
          "$interfaceNameTrimmed$interfaceGenericStringNoExtends copyWith$interfaceNameTrimmed$interfaceGenericStringWithExtends");

  // if (interfaceGenerics.isNotEmpty) {
  //   var generic = interfaceGenerics //
  //       .map((e) => e.type == null //
  //           ? e.name
  //           : "${e.name} extends ${e.type}")
  //       .joinToString(separator: ", ");
  //   sb.write("<$generic>");
  // }

  sb.write("(");

  //where property name of interface is the same as the one in the class
  //use the type of the class

  var fieldsForSignature = classFields //
      .where((element) =>
          interfaceFields.map((e) => e.name).contains(element.name));

  // identify fields in the interface not in the class
  var requiredFields = isExplicitSubType //
      ? interfaceFields //
          .where((x) => classFields.none((cf) => cf.name == x.name))
          .toList()
      : <NameType>[];

  if (fieldsForSignature.isNotEmpty || requiredFields.isNotEmpty) //
    sb.write("{");

  sb.writeln();

  sb.write(requiredFields.map((e) {
    var interfaceType =
        interfaceFields.firstWhere((element) => element.name == e.name).type;
    return "required ${getDataTypeWithoutDollars(interfaceType!)} ${e.name},\n";
  }).join());

  sb.write(fieldsForSignature.map((e) {
    var interfaceType = interfaceFields
        .firstWhere(
          (element) => element.name == e.name,
        )
        .type;

    var name = e.name.startsWith("_") ? e.name.substring(1) : e.name;

    return "${getDataTypeWithoutDollars(interfaceType!)} Function()? $name,\n";
  }).join());

  if (fieldsForSignature.isNotEmpty || requiredFields.isNotEmpty) //
    sb.write("}");

  if (isClassAbstract && !isExplicitSubType) {
    sb.write(");");
    return sb.toString();
  }

  sb.writeln(") {");

  if (isExplicitSubType) {
    // Use public constructor if changing to a different type
    var usePrivateConstructor = interfaceNameTrimmed == classNameTrimmed;
    sb.writeln(
        "return ${getDataTypeWithoutDollars(interfaceName)}${usePrivateConstructor ? '._' : ''}(");
  } else {
    sb.writeln("return $classNameTrimmed._(");
  }

  sb.write(requiredFields //
      .map((e) {
    var name = e.name.startsWith("_") ? e.name.substring(1) : e.name;
    var classType = getDataTypeWithoutDollars(e.type!);
    return "$name: $name as $classType,\n";
  }).join());

  sb.write(fieldsForSignature //
      .map((e) {
    var name = e.name.startsWith("_") ? e.name.substring(1) : e.name;

    var classType = getDataTypeWithoutDollars(
        classFields.firstWhere((element) => element.name == e.name).type!);
    return "$name: $name == null ? this.${e.name} as $classType : $name() as $classType,\n";
  }).join());

  var fieldsNotInSignature = classFields //
      .where((element) =>
          !interfaceFields.map((e) => e.name).contains(element.name));

  sb.write(fieldsNotInSignature //
      .map((e) =>
          "${e.name.startsWith('_') ? e.name.substring(1) : e.name}: (this as $classNameTrimmed).${e.name},\n")
      .join());

  sb.write(") as $interfaceNameTrimmed$interfaceGenericStringNoExtends;");

  // if (isExplicitSubType) {
  //   sb.write(") as $interfaceNameTrimmed;");
  // } else {
  //   sb.write(") as $interfaceNameTrimmed$interfaceGenericStringNoExtends;");
  // }
  sb.write("}");

  return sb.toString();
}

//String getCopyWithSignature(List<NameType> fields, String trimmedClassName) {
//  var paramList = "\n" + fields.map((e) => "required ${e.type} ${e.name}").joinToString(separator: ",\n") + ",\n";
//  return "$trimmedClassName cw$trimmedClassName({$paramList}) {";
//}

//List<Interface> getValueTImplements(List<Interface> interfaces, String trimmedClassName, List<NameType> fields) {
//  return [
//    ...interfaces //
//        .where((element) => element.type.startsWith("\$"))
//        .toList(),
//    Interface(trimmedClassName, typeArgsTypes, fields)
//  ];
//}

//class Interface2 {
//  final String type;
//  final List<NameType> paramNameType;
//
//  Interface2(this.type, this.paramNameType);
//
//  toString() => "${this.type}|${this.paramNameType}";
//}

String getConstructorName(String trimmedClassName, bool hasCustomConstructor) {
  return hasCustomConstructor //
      ? "$trimmedClassName._"
      : trimmedClassName;
}

String generateFromJsonHeader(String className) {
  var _className = "${className.replaceFirst("\$", "")}";
  return "factory ${_className.replaceFirst("\$", "")}.fromJson(Map<String, dynamic> json) {";
}

String generateFromJsonBody(
    String className, List<NameType> generics, List<Interface> interfaces) {
  var _class = Interface(className, generics.map((e) => e.type ?? "").toList(),
      generics.map((e) => e.name).toList(), []);
  var _classes = [...interfaces, _class];
  var _className = className.replaceAll("\$", "");

  var body = """if (json['_className_'] == null) {
      return _\$${_className}FromJson(json);
    }
""";

  // Add interface checks
  var interfaceChecks = _classes
      .where((c) => !c.interfaceName.startsWith("\$\$"))
      .mapIndexed((i, c) {
    var _interfaceName = "${c.interfaceName.replaceFirst("\$", "")}";
    var genericTypes = c.typeParams.map((e) => "'_${e.name}_'").join(",");
    var isCurrentClass = _interfaceName == className.replaceAll("\$", "");
    var prefix = i == 0 ? "if" : "} else if";

    if (c.typeParams.length > 0) {
      return """$prefix (json['_className_'] == "$_interfaceName") {
      var fn_fromJson = getFromJsonToGenericFn(
        ${_interfaceName}_Generics_Sing().fns,
        json,
        [$genericTypes],
      );
      return fn_fromJson(json);""";
    } else {
      return """$prefix (json['_className_'] == "$_interfaceName") {
      return ${isCurrentClass ? "_\$" : ""}${_interfaceName}${isCurrentClass ? "FromJson" : ".fromJson"}(json);""";
    }
  }).join("\n");

  body += interfaceChecks;
  if (interfaceChecks.isNotEmpty) body += "\n}";

  body += """
    throw UnsupportedError("The _className_ '\${json['_className_']}' is not supported by the ${_className}.fromJson constructor.");
    }""";

  return body;
}

String generateToJson(String className, List<NameType> generics) {
  if (className.startsWith("\$\$")) {
    return "Map<String, dynamic> toJsonCustom([Map<Type, Object? Function(Never)>? fns]);";
  }

  var _className = "${className.replaceFirst("\$", "")}";

  var getGenericFn = generics.isEmpty
      ? ""
      : generics
              .map((e) =>
                  "    var fn_${e.name} = getGenericToJsonFn(_fns, ${e.name});")
              .join("\n") +
          "\n";

  var toJsonParams = generics.isEmpty
      ? ""
      : generics
              .map((e) => "      fn_${e.name} as Object? Function(${e.name})")
              .join(",\n") +
          "\n";

  var recordType = generics.isEmpty
      ? ""
      : generics
              .map((e) => "      data['_${e.name}_'] = ${e.name}.toString();")
              .join("\n") +
          "\n";

  var result = """
  // ignore: unused_field\n
  Map<Type, Object? Function(Never)> _fns = {};

  Map<String, dynamic> toJsonCustom([Map<Type, Object? Function(Never)>? fns]){
    _fns = fns ?? {};
    return toJson();
  }

  Map<String, dynamic> toJson() {
$getGenericFn    final Map<String, dynamic> data = _\$${_className}ToJson(this${generics.isEmpty ? "" : ",\n$toJsonParams"});

      data['_className_'] = '$_className';${recordType.isEmpty ? "" : "\n$recordType"}

    return data;
  }""";

  return result;
}

String generateToJsonLean(String className) {
  if (className.startsWith("\$\$")) {
    return "";
  }

  var _className = "${className.replaceFirst("\$", "")}";
  var result = """

  Map<String, dynamic> toJsonLean() {
    final Map<String, dynamic> data = _\$${_className}ToJson(this,);
    return _sanitizeJson(data);
  }

  dynamic _sanitizeJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      json.remove('_className_');
      return json..forEach((key, value) {
        json[key] = _sanitizeJson(value);
      });
    } else if (json is List) {
      return json.map((e) => _sanitizeJson(e)).toList();
    }
    return json;
  }""";

  return result;
}

String createJsonSingleton(String classNameTrim, List<NameType> generics) {
  if (generics.length == 0) //
    return "";

  var objects = generics.map((e) => "Object").join(", ");

  var result = """
class ${classNameTrim}_Generics_Sing {
  Map<List<String>, $classNameTrim<${objects}> Function(Map<String, dynamic>)> fns = {};

  factory ${classNameTrim}_Generics_Sing() => _singleton;
  static final ${classNameTrim}_Generics_Sing _singleton = ${classNameTrim}_Generics_Sing._internal();

  ${classNameTrim}_Generics_Sing._internal() {}
}
    """;

  return result;
}

String commentEveryLine(String multilineString) {
  return multilineString.split('\n').map((line) => '//' + line).join('\n');
}

String generateCompareExtension(
  bool isAbstract,
  String className,
  String classNameTrim,
  List<NameTypeClassComment> allFields,
  List<Interface> knownInterfaces, // Add these parameters
  List<String> knownClasses, // Add these parameters
  bool generateCompareTo,
) {
  var sb = StringBuffer();
  String enumClassName = "${classNameTrim}\$";
  sb.writeln();
  sb.writeln("extension \$${classNameTrim}CompareE on \$${classNameTrim} {");

  // First version with String keys
  sb.writeln('''
      Map<String, dynamic> compareTo$classNameTrim($classNameTrim other) {
        final Map<String, dynamic> diff = {};

        ${_generateCompareFieldsLogic(allFields, knownInterfaces, knownClasses, useEnumKeys: false)}

        return diff;
      }
    ''');

  // Second version with Enum keys
  // sb.writeln('''
  //     ${classNameTrim}Patch compareToEnum$classNameTrim($classNameTrim other) {
  //       final ${classNameTrim}Patch diff = {};

  //       ${_generateCompareFieldsLogic(allFields, knownInterfaces, knownClasses, useEnumKeys: true, enumClassName: enumClassName)}

  //       return diff;
  //     }
  //   ''');

  sb.writeln("}");
  return sb.toString();
}

String _generateCompareFieldsLogic(List<NameTypeClassComment> allFields,
    List<Interface> knownInterfaces, List<String> knownClasses,
    {required bool useEnumKeys, String? enumClassName}) {
  return allFields
      .map((field) {
        final type = field.type ?? '';
        final name = field.name;
        final isNullable = type.endsWith('?');
        final keyString =
            useEnumKeys ? '$enumClassName.${field.name}' : "'${field.name}'";
        final methodName = useEnumKeys ? 'compareToEnum' : 'compareTo';
        final baseType = type.replaceAll('?', ''); // Remove nullable indicator

        // Skip functions
        if (type.contains('Function')) {
          return '';
        }

        // Handle different types
        if (type.startsWith('List<') || type.startsWith('Set<')) {
          return _generateCollectionComparison(
              name, type, keyString, isNullable);
        }

        if (type.startsWith('Map<')) {
          return _generateMapComparison(name, keyString, isNullable);
        }

        if (type.contains('DateTime')) {
          return _generateDateTimeComparison(name, keyString, isNullable);
        }

        // Check if type is a known interface or class
        final isKnownType =
            knownInterfaces.any((i) => i.interfaceName == baseType) ||
                knownClasses.contains(baseType);

        if (isKnownType) {
          return _generateKnownTypeComparison(
              name, baseType, keyString, methodName, isNullable);
        }

        // Direct comparison for all other types
        return _generateSimpleComparison(name, keyString);
      })
      .where((s) => s.isNotEmpty)
      .join('\n    ');
}

String _generateCollectionComparison(
    String name, String type, String keyString, bool isNullable) {
  if (isNullable) {
    return '''
    if ($name != other.$name) {
      if ($name != null && other.$name != null) {
        if ($name!.length != other.$name!.length) {
          diff[$keyString] = () => other.$name;
        } else {
          var hasDiff = false;
          for (var i = 0; i < $name!.length; i++) {
            if ($name![i] != other.$name![i]) {
              hasDiff = true;
              break;
            }
          }
          if (hasDiff) {
            diff[$keyString] = () => other.$name;
          }
        }
      } else {
        diff[$keyString] = () => other.$name;
      }
    }''';
  }

  return '''
    if ($name != other.$name) {
      if ($name.length != other.$name.length) {
        diff[$keyString] = () => other.$name;
      } else {
        var hasDiff = false;
        for (var i = 0; i < $name.length; i++) {
          if ($name[i] != other.$name[i]) {
            hasDiff = true;
            break;
          }
        }
        if (hasDiff) {
          diff[$keyString] = () => other.$name;
        }
      }
    }''';
}

String _generateMapComparison(String name, String keyString, bool isNullable) {
  if (isNullable) {
    return '''
    if ($name != other.$name) {
      if ($name != null && other.$name != null) {
        if ($name!.length != other.$name!.length ||
           !$name!.keys.every((k) => other.$name!.containsKey(k) && $name![k] == other.$name![k])) {
          diff[$keyString] = () => other.$name;
        }
      } else {
        diff[$keyString] = () => other.$name;
      }
    }''';
  }

  return '''
    if ($name != other.$name) {
      if ($name.length != other.$name.length ||
         !$name.keys.every((k) => other.$name.containsKey(k) && $name[k] == other.$name[k])) {
        diff[$keyString] = () => other.$name;
      }
    }''';
}

String _generateDateTimeComparison(
    String name, String keyString, bool isNullable) {
  if (isNullable) {
    return '''
    if ($name != other.$name) {
      if ($name != null && other.$name != null) {
        if (!$name!.isAtSameMomentAs(other.$name!)) {
          diff[$keyString] = () => other.$name;
        }
      } else {
        diff[$keyString] = () => other.$name;
      }
    }''';
  }

  return '''
    if ($name != other.$name) {
      if (!$name.isAtSameMomentAs(other.$name)) {
        diff[$keyString] = () => other.$name;
      }
    }''';
}

String _generateKnownTypeComparison(String name, String baseType,
    String keyString, String methodName, bool isNullable) {
  if (isNullable) {
    return '''
    if ($name != other.$name) {
      if ($name != null && other.$name != null) {
        diff[$keyString] = () => $name!.$methodName${baseType.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}(other.$name!);
      } else {
        diff[$keyString] = () => other.$name;
      }
    }''';
  }

  return '''
    if ($name != other.$name) {
      diff[$keyString] = () => $name.$methodName${baseType.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')}(other.$name);
    }''';
}

String _generateSimpleComparison(String name, String keyString) {
  return '''
    if ($name != other.$name) {
      diff[$keyString] = () => other.$name;
    }''';
}
