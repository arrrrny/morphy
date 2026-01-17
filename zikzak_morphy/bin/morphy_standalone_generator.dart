import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:dartx/dartx.dart';
import 'package:source_gen/source_gen.dart';
import 'package:zikzak_morphy/src/common/NameType.dart';
import 'package:zikzak_morphy/src/common/classes.dart';
import 'package:zikzak_morphy/src/common/helpers.dart';
import 'package:zikzak_morphy/src/createMorphy.dart';
import 'package:zikzak_morphy/src/factory_method.dart';
import 'package:zikzak_morphy/src/helpers.dart';

/// Standalone generator that works without build_runner
class MorphyStandaloneGenerator {
  static final Map<String, ClassElement> _allAnnotatedClasses = {};
  static final Map<String, List<InterfaceType>> _allImplementedInterfaces = {};

  /// Clear cached state between runs
  void clearCache() {
    _allAnnotatedClasses.clear();
    _allImplementedInterfaces.clear();
  }

  /// Register a class element for cross-referencing
  void registerClass(ClassElement element) {
    _allAnnotatedClasses[element.name] = element;
    _allImplementedInterfaces[element.name] = element.interfaces;
  }

  FutureOr<String> generateForAnnotatedElement(
    ClassElement element,
    ConstantReader annotation,
    List<ClassElement> allClasses,
  ) {
    var sb = StringBuffer();

    _allAnnotatedClasses[element.name] = element;

    var hasConstConstructor = element.constructors.any((e) => e.isConst);
    var nonSealed = annotation.read('nonSealed').boolValue;
    var isAbstract = element.name.startsWith("\$\$") && !nonSealed;

    // Validate sealed class implementation location
    for (var interface in element.interfaces) {
      var interfaceName = interface.element.name;
      if (interfaceName.startsWith("\$\$") && !element.name.startsWith("\$")) {
        var sealedLibrary = interface.element.library;
        var implementationLibrary = element.library;

        var isSameLibrary =
            sealedLibrary == implementationLibrary ||
            implementationLibrary.definingCompilationUnit.library ==
                sealedLibrary ||
            sealedLibrary.definingCompilationUnit.library ==
                implementationLibrary;

        if (!isSameLibrary) {
          throw Exception(
            'Class ${element.name} must be in the same library as its sealed superclass $interfaceName. '
            'Either move it to the same library or use "part of" directive.',
          );
        }
      }
    }

    if (element.supertype?.element.name != "Object") {
      throw Exception("you must use implements, not extends");
    }

    var docComment = element.documentationComment;

    // Collect all interfaces including the inheritance chain
    var allInterfaces = <InterfaceType>[];
    var processedInterfaces = <String>{};

    void addInterface(InterfaceType interface) {
      if (processedInterfaces.contains(interface.element.name)) return;
      processedInterfaces.add(interface.element.name);
      allInterfaces.add(interface);

      interface.element.interfaces.forEach(addInterface);
      interface.element.allSupertypes
          .where((t) => t.element.name != 'Object')
          .forEach(addInterface);
    }

    element.interfaces.forEach(addInterface);

    var interfaces = allInterfaces.map((e) {
      var interfaceName = e.element.name;
      var implementedName = interfaceName.startsWith("\$\$")
          ? interfaceName.replaceAll("\$\$", "")
          : interfaceName.replaceAll("\$", "");

      return InterfaceWithComment(
        implementedName,
        e.typeArguments.map(typeToString).toList(),
        e.element.typeParameters.map((x) => x.name).toList(),
        e.element.fields
            .map((e) => NameType(e.name, typeToString(e.type)))
            .toList(),
        comment: e.element.documentationComment,
        isSealed: interfaceName.startsWith("\$\$"),
        hidePublicConstructor: _getHidePublicConstructorForInterface(
          e.element as ClassElement,
        ),
      );
    }).toList();

    var allFields = _getAllFieldsIncludingSubtypes(element);
    var allFieldsDistinct = getDistinctFields(allFields, interfaces);

    var factoryMethods = _getFactoryMethods(element);

    var classGenerics = element.typeParameters.map((e) {
      final bound = e.bound;
      return NameTypeClassComment(
        e.name,
        bound == null ? null : typeToString(bound),
        null,
      );
    }).toList();

    var typesExplicit = <Interface>[];
    if (!annotation.read('explicitSubTypes').isNull) {
      typesExplicit = annotation.read('explicitSubTypes').listValue.map((x) {
        if (x.toTypeValue()?.element is! ClassElement) {
          throw Exception("each type for the copywith def must all be classes");
        }

        var el = x.toTypeValue()?.element as ClassElement;
        _allAnnotatedClasses[el.name] = el;

        return Interface.fromGenerics(
          el.name,
          el.typeParameters.map((TypeParameterElement x) {
            final bound = x.bound;
            return NameType(x.name, bound == null ? null : typeToString(bound));
          }).toList(),
          _getAllFieldsIncludingSubtypes(
            el,
          ).where((x) => x.name != "hashCode").toList(),
          true,
        );
      }).toList();
    }

    var allValueTInterfaces = allInterfaces
        .map(
          (e) => Interface.fromGenerics(
            e.element.name.startsWith("\$\$")
                ? e.element.name.replaceAll("\$\$", "")
                : e.element.name.replaceAll("\$", ""),
            e.typeArguments.asMap().entries.map((entry) {
              final index = entry.key;
              final typeArg = entry.value;
              final paramName = e.element.typeParameters.length > index
                  ? e.element.typeParameters[index].name
                  : 'T$index';
              return NameType(paramName, typeToString(typeArg));
            }).toList(),
            _getAllFieldsIncludingSubtypes(
              e.element as ClassElement,
            ).where((x) => x.name != "hashCode").toList(),
            false,
            e.element.name.startsWith("\$\$"),
            _getHidePublicConstructorForInterface(e.element as ClassElement),
          ),
        )
        .union(typesExplicit)
        .distinctBy((element) => element.interfaceName)
        .toList();

    sb.writeln(
      createMorphy(
        isAbstract,
        allFieldsDistinct,
        element.name,
        docComment ?? "",
        interfaces,
        allValueTInterfaces,
        classGenerics,
        hasConstConstructor,
        annotation.read('generateJson').boolValue,
        annotation.read('hidePublicConstructor').boolValue,
        typesExplicit,
        nonSealed,
        annotation.read('explicitToJson').boolValue,
        annotation.read('generateCompareTo').boolValue,
        annotation.read('generateCopyWithFn').boolValue,
        factoryMethods,
        _allAnnotatedClasses,
      ),
    );

    return sb.toString();
  }

  List<NameTypeClassComment> _getAllFieldsIncludingSubtypes(
    ClassElement element,
  ) {
    var fields = <NameTypeClassComment>[];
    var processedTypes = <String>{};

    void addFields(ClassElement element) {
      if (processedTypes.contains(element.name)) return;
      processedTypes.add(element.name);

      fields.addAll(
        getAllFields(
          element.allSupertypes,
          element,
        ).where((x) => x.name != "hashCode"),
      );

      for (var interface in element.interfaces) {
        if (_allAnnotatedClasses.containsKey(interface.element.name)) {
          addFields(_allAnnotatedClasses[interface.element.name]!);
        }
      }
    }

    addFields(element);
    return fields.distinctBy((f) => f.name).toList();
  }

  bool _getHidePublicConstructorForInterface(ClassElement element) {
    return element.name.endsWith("_");
  }

  List<FactoryMethodInfo> _getFactoryMethods(ClassElement element) {
    var factoryMethods = <FactoryMethodInfo>[];

    for (var constructor in element.constructors) {
      if (constructor.isFactory && constructor.name.isNotEmpty) {
        var methodName = constructor.name;
        var parameters = constructor.parameters.map((param) {
          var paramType = param.type.toString();

          if (paramType.contains('InvalidType') || paramType == 'dynamic') {
            paramType = _fixSelfReferencingType(param, element);
          }

          return FactoryParameterInfo(
            name: param.name,
            type: paramType,
            isRequired: param.isRequired,
            isNamed: param.isNamed,
            hasDefaultValue: param.hasDefaultValue,
            defaultValue: param.defaultValueCode,
          );
        }).toList();

        var bodyCode = _extractFactoryBody(constructor, element);

        factoryMethods.add(
          FactoryMethodInfo(
            name: methodName,
            className: element.name,
            parameters: parameters,
            bodyCode: bodyCode,
          ),
        );
      }
    }

    return factoryMethods;
  }

  String _fixSelfReferencingType(ParameterElement param, ClassElement element) {
    var source = element.source.contents.data;
    var paramOffset = param.nameOffset;

    var searchStart = paramOffset > 100 ? paramOffset - 100 : 0;
    var searchEnd = paramOffset < source.length
        ? paramOffset
        : source.length - 1;
    var beforeParam = source.substring(searchStart, searchEnd);

    var typeMatch = RegExp(r'(\w+(?:<[^>]+>)?)\s+$').firstMatch(beforeParam);
    if (typeMatch != null) {
      return typeMatch.group(1)!;
    }

    return param.type.toString();
  }

  String _extractFactoryBody(
    ConstructorElement constructor,
    ClassElement element,
  ) {
    var source = element.source.contents.data;

    var nameEnd = constructor.nameEnd;
    if (nameEnd == null) {
      return 'return ${element.name.replaceAll('\$', '')}._();';
    }

    var afterConstructor = source.substring(nameEnd);

    var arrowMatch = RegExp(
      r'^\s*\([^)]*\)\s*=>\s*',
    ).firstMatch(afterConstructor);
    if (arrowMatch != null) {
      var afterArrow = afterConstructor.substring(arrowMatch.end);
      var semicolonIndex = afterArrow.indexOf(';');
      if (semicolonIndex != -1) {
        var body = afterArrow.substring(0, semicolonIndex).trim();
        return 'return $body;';
      }
    }

    var bodyMatch = RegExp(r'^\s*\([^)]*\)\s*\{').firstMatch(afterConstructor);
    if (bodyMatch != null) {
      var afterBrace = afterConstructor.substring(bodyMatch.end);
      var braceCount = 1;
      var bodyEnd = 0;
      for (var i = 0; i < afterBrace.length && braceCount > 0; i++) {
        if (afterBrace[i] == '{') braceCount++;
        if (afterBrace[i] == '}') braceCount--;
        bodyEnd = i;
      }
      return afterBrace.substring(0, bodyEnd).trim();
    }

    return 'return ${element.name.replaceAll('\$', '')}._();';
  }
}
