import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:dartx/dartx.dart';
import 'package:source_gen/source_gen.dart';

import 'NameType.dart';
import 'classes.dart';

/// Extracts @JsonKey annotation information from a field element
JsonKeyInfo? extractJsonKeyInfo(FieldElement field) {
  try {
    // Try to find JsonKey annotation by checking for annotation name
    // First check the field's metadata
    var annotation = field.metadata.firstWhereOrNull((annotation) {
      final element = annotation.element;
      return element != null &&
          (element.displayName == 'JsonKey' ||
              element.displayName == 'jsonKey');
    });

    // If not found on field, check the getter's metadata
    // This is needed for abstract getters like: @JsonKey(name: 'x') String get x;
    if (annotation == null && field.getter != null) {
      annotation = field.getter!.metadata.firstWhereOrNull((annotation) {
        final element = annotation.element;
        return element != null &&
            (element.displayName == 'JsonKey' ||
                element.displayName == 'jsonKey');
      });
    }

    if (annotation == null) return null;

    // Parse the annotation
    final reader = ConstantReader(annotation.computeConstantValue());

    String? name;
    bool? ignore;
    dynamic defaultValue;
    bool? required;
    bool? includeIfNull;
    bool? includeFromJson;
    bool? includeToJson;
    String? toJson;
    String? fromJson;

    try {
      final nameValue = reader.read('name');
      if (!nameValue.isNull) {
        name = nameValue.stringValue;
      }
    } catch (_) {}

    try {
      final ignoreValue = reader.read('ignore');
      if (!ignoreValue.isNull) {
        ignore = ignoreValue.boolValue;
      }
    } catch (_) {}

    try {
      final defaultValueObj = reader.read('defaultValue');
      if (!defaultValueObj.isNull) {
        // Try to extract the default value
        if (defaultValueObj.isString) {
          defaultValue = defaultValueObj.stringValue;
        } else if (defaultValueObj.isBool) {
          defaultValue = defaultValueObj.boolValue;
        } else if (defaultValueObj.isInt) {
          defaultValue = defaultValueObj.intValue;
        } else if (defaultValueObj.isDouble) {
          defaultValue = defaultValueObj.doubleValue;
        } else {
          // For complex default values, convert to string representation
          defaultValue = defaultValueObj.objectValue.toString();
        }
      }
    } catch (_) {}

    try {
      final requiredValue = reader.read('required');
      if (!requiredValue.isNull) {
        required = requiredValue.boolValue;
      }
    } catch (_) {}

    try {
      final includeIfNullValue = reader.read('includeIfNull');
      if (!includeIfNullValue.isNull) {
        includeIfNull = includeIfNullValue.boolValue;
      }
    } catch (_) {}

    try {
      final includeFromJsonValue = reader.read('includeFromJson');
      if (!includeFromJsonValue.isNull) {
        includeFromJson = includeFromJsonValue.boolValue;
      }
    } catch (_) {}

    try {
      final includeToJsonValue = reader.read('includeToJson');
      if (!includeToJsonValue.isNull) {
        includeToJson = includeToJsonValue.boolValue;
      }
    } catch (_) {}

    try {
      final toJsonValue = reader.read('toJson');
      if (!toJsonValue.isNull) {
        toJson = toJsonValue.objectValue.toString();
      }
    } catch (_) {}

    try {
      final fromJsonValue = reader.read('fromJson');
      if (!fromJsonValue.isNull) {
        fromJson = fromJsonValue.objectValue.toString();
      }
    } catch (_) {}

    // Only return JsonKeyInfo if at least one parameter was found
    if (name != null ||
        ignore != null ||
        defaultValue != null ||
        required != null ||
        includeIfNull != null ||
        includeFromJson != null ||
        includeToJson != null ||
        toJson != null ||
        fromJson != null) {
      return JsonKeyInfo(
        name: name,
        ignore: ignore,
        defaultValue: defaultValue,
        required: required,
        includeIfNull: includeIfNull,
        includeFromJson: includeFromJson,
        includeToJson: includeToJson,
        toJson: toJson,
        fromJson: fromJson,
      );
    }
  } catch (e) {
    // If we can't parse the annotation, just return null
    return null;
  }

  return null;
}

/// [interfaces] a list of interfaces the class implements
///
/// [classComment] the comment of the class itself
String getClassComment(List<Interface> interfaces, String? classComment) {
  var a = interfaces
      .where((e) => e is InterfaceWithComment && e.comment != classComment) //
      .map((e) {
        var interfaceComment =
            e is InterfaceWithComment &&
                e.comment !=
                    null //
            ? "\n${e.comment}"
            : "";
        return "///implements [${e.interfaceName}]\n///\n$interfaceComment\n///";
      })
      .toList();

  if (classComment != null) //
    a.insert(0, classComment + "\n///");

  return a.join("\n").trim() + "\n";
}

MethodDetails<TMeta1> getMethodDetailsForFunctionType<TMeta1>(
  FunctionTypedElement fn,
  TMeta1 GetMetaData(ParameterElement parameterElement),
) {
  var returnType = typeToString(fn.returnType);

  var paramsPositional2 = fn.parameters.where((x) => x.isPositional);
  var paramsNamed2 = fn.parameters.where((x) => x.isNamed);

  var paramsPositional = paramsPositional2
      .map(
        (x) => NameTypeClassCommentData<TMeta1>(
          x.name.toString(),
          typeToString(x.type),
          null,
          comment: x.documentationComment,
          meta1: GetMetaData(x),
        ),
      )
      .toList();
  var paramsNamed = paramsNamed2
      .map(
        (x) => NameTypeClassCommentData<TMeta1>(
          x.name.toString(),
          typeToString(x.type),
          null,
          comment: x.documentationComment,
          meta1: GetMetaData(x),
        ),
      )
      .toList();

  var typeParameters2 = fn
      .typeParameters //
      .map((e) {
        final bound = e.bound;
        return GenericsNameType(
          e.name,
          bound == null ? null : typeToString(bound),
        );
      })
      .toList();

  return MethodDetails<TMeta1>(
    fn.documentationComment,
    fn.name ?? "",
    paramsPositional,
    paramsNamed,
    typeParameters2,
    returnType,
  );
}

List<NameTypeClassComment> getAllFields(
  List<InterfaceType> interfaceTypes,
  ClassElement element,
) {
  var superTypeFields =
      interfaceTypes //
          .where((x) => x.element.name != "Object")
          .flatMap(
            (st) => st.element.fields.map(
              (f) => //
              NameTypeClassComment(
                f.name,
                typeToString(f.type),
                st.element.name,
                comment: f.getter?.documentationComment,
                jsonKeyInfo: extractJsonKeyInfo(f),
                isEnum: f.type.element is EnumElement,
              ),
            ),
          )
          .toList();

  var classFields = element.fields
      .map(
        (f) => //
        NameTypeClassComment(
          f.name,
          typeToString(f.type),
          element.name,
          comment: f.getter?.documentationComment,
          jsonKeyInfo: extractJsonKeyInfo(f),
          isEnum: f.type.element is EnumElement,
        ),
      )
      .toList();

  //distinct, will keep classFields over superTypeFields
  return (classFields + superTypeFields).distinctBy((x) => x.name).toList();
}

String typeToString(DartType type) {
  final alias = type.alias;
  final manual = alias != null
      ? aliasToString(alias)
      : type is FunctionType
      ? functionToString(type)
      : type is RecordType
      ? recordToString(type)
      : type is ParameterizedType
      ? genericToString(type)
      : null;
  final nullMarker = type.nullabilitySuffix == NullabilitySuffix.question
      ? '?'
      : type.nullabilitySuffix == NullabilitySuffix.star
      ? '*'
      : '';
  return manual != null ? "$manual$nullMarker" : type.toString();
}

String aliasToString(InstantiatedTypeAliasElement alias) =>
    "${alias.element.name}${alias.typeArguments.isEmpty ? '' : "<${alias.typeArguments.map(typeToString).join(', ')}>"}";

String functionToString(FunctionType type) {
  final generics = type.typeFormals.isNotEmpty
      ? "<${type.typeFormals.map((param) {
          final bound = param.bound;
          return "${param.name}${bound == null ? "" : " = ${typeToString(bound)}"}";
        }).join(', ')}>"
      : '';
  final normal = type.parameters
      .where((param) => param.isRequiredPositional)
      .map((param) => "${typeToString(param.type)} ${param.name}")
      .join(', ');
  final named = type.parameters
      .where((param) => param.isNamed)
      .map(
        (param) =>
            "${param.isRequiredNamed ? 'required ' : ''}${typeToString(param.type)} ${param.name}",
      )
      .join(', ');
  final optional = type.parameters
      .where((param) => param.isOptionalPositional)
      .map((param) => "${typeToString(param.type)} ${param.name}")
      .join(', ');
  return "${typeToString(type.returnType)} Function$generics(${[if (normal.isNotEmpty) normal, if (named.isNotEmpty) "{$named}", if (optional.isNotEmpty) "[$optional]"].join(', ')})";
}

String recordToString(RecordType type) {
  final positional = type.positionalFields
      .map((e) => typeToString(e.type))
      .join(', ');
  final named = type.namedFields
      .map((e) => "${typeToString(e.type)} ${e.name}")
      .join(', ');
  final trailing =
      type.positionalFields.length == 1 && type.namedFields.length == 0
      ? ','
      : '';
  return "(${[if (positional.isNotEmpty) positional, if (named.isNotEmpty) "{$named}"].join(', ')}$trailing)";
}

String genericToString(ParameterizedType type) {
  final arguments = type.typeArguments.isEmpty
      ? ''
      : "<${type.typeArguments.map(typeToString).join(', ')}>";
  return "${type.element!.name}$arguments";
}
