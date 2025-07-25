import '../common/NameType.dart';
import 'method_generator_commons.dart';

/// Generates constructor parameters for copyWith, patchWith, and changeTo methods
class ConstructorParameterGenerator {
  /// Generate constructor parameters for copyWith methods (simple assignment)
  static String generateCopyWithConstructorParams(
    List<NameType> targetClassFields,
    List<NameType> sourceInterfaceFields,
  ) {
    final sourceFieldNames = sourceInterfaceFields.map((f) => f.name).toSet();

    final constructorFields = targetClassFields.map((f) {
      final name = MethodGeneratorCommons.getCleanFieldName(f.name);
      final hasField = sourceFieldNames.contains(f.name);

      if (hasField) {
        // For interface fields, use parameter or current value with cast if needed
        final cleanType = FieldTypeAnalyzer.cleanType(f.type);
        final castType = cleanType.endsWith('?') ? cleanType : '$cleanType?';
        return '$name: $name as $castType ?? this.${f.name}';
      } else {
        // For class-only fields, keep current value
        return '$name: this.${f.name}';
      }
    });

    final result = constructorFields.join(',\n          ');
    return result.isEmpty ? '' : result;
  }

  /// Generate constructor parameters for patchWith methods (patch-based assignment)
  static String generatePatchWithConstructorParams(
    List<NameType> targetClassFields,
    List<NameType> sourceInterfaceFields,
    String targetClassName,
    List<NameType> genericParams,
    List<String> knownClasses,
  ) {
    final sourceFieldNames = sourceInterfaceFields.map((f) => f.name).toSet();
    // final genericTypeNames = genericParams
    //     .map((g) => FieldTypeAnalyzer.cleanType(g.type))
    //     .toSet();

    final constructorFields = targetClassFields.map((f) {
      final name = MethodGeneratorCommons.getCleanFieldName(f.name);
      final hasField = sourceFieldNames.contains(f.name);
      final baseType = FieldTypeAnalyzer.cleanType(f.type).replaceAll("?", "");
      final isEnum = f.isEnum;
      final isGenericType = TypeResolver.isGenericType(baseType, genericParams);

      if (hasField) {
        // Handle complex types that might need nested patch handling
        if (MethodGeneratorCommons.needsPatchHandling(
          baseType,
          isEnum,
          isGenericType,
          knownClasses,
        )) {
          final patchType = MethodGeneratorCommons.getPatchType(baseType);
          return '''$name: _patchMap.containsKey($targetClassName\$.$name)
            ? (_patchMap[$targetClassName\$.$name] is Function)
              ? _patchMap[$targetClassName\$.$name](this.${f.name})
              : (_patchMap[$targetClassName\$.$name] is $patchType)
                ? (this.${f.name}${f.type?.endsWith('?') == true ? '?' : ''}.patchWith$baseType(
                    patchInput: _patchMap[$targetClassName\$.$name]
                  )${f.type?.endsWith('?') == true ? ' ?? _patchMap[$targetClassName\$.$name]' : ''})
                : _patchMap[$targetClassName\$.$name]
            : this.${f.name}''';
        }
        return '''$name: _patchMap.containsKey($targetClassName\$.$name)
          ? (_patchMap[$targetClassName\$.$name] is Function)
            ? _patchMap[$targetClassName\$.$name](this.${f.name})
            : _patchMap[$targetClassName\$.$name]
          : this.${f.name}''';
      } else {
        // For class-only fields, keep current value
        return '$name: this.${f.name}';
      }
    });

    final result = constructorFields.join(',\n          ');
    return result.isEmpty ? '' : result;
  }

  /// Generate constructor parameters for changeTo methods
  static String generateChangeToConstructorParams(
    List<NameType> targetClassFields,
    List<NameType> sourceInterfaceFields,
    String targetClassName,
    List<NameType> genericParams,
    List<String> knownClasses,
  ) {
    final sourceFieldNames = sourceInterfaceFields.map((f) => f.name).toSet();
    // final genericTypeNames = genericParams
    //     .map((g) => FieldTypeAnalyzer.cleanType(g.type))
    //     .toSet();

    final constructorFields = targetClassFields.map((f) {
      final name = MethodGeneratorCommons.getCleanFieldName(f.name);
      final hasField = sourceFieldNames.contains(f.name);
      final baseType = FieldTypeAnalyzer.cleanType(f.type).replaceAll("?", "");
      final isEnum = f.isEnum;
      final isGenericType = TypeResolver.isGenericType(baseType, genericParams);

      if (hasField) {
        // Handle complex types that might need nested patch handling
        if (MethodGeneratorCommons.needsPatchHandling(
          baseType,
          isEnum,
          isGenericType,
          knownClasses,
        )) {
          final patchType = MethodGeneratorCommons.getPatchType(baseType);
          return '''$name: _patchMap.containsKey($targetClassName\$.$name)
            ? (_patchMap[$targetClassName\$.$name] is Function)
              ? _patchMap[$targetClassName\$.$name](this.${f.name})
              : (_patchMap[$targetClassName\$.$name] is $patchType)
                ? (this.${f.name}${f.type?.endsWith('?') == true ? '?' : ''}.patchWith$baseType(
                    patchInput: _patchMap[$targetClassName\$.$name]
                  )${f.type?.endsWith('?') == true ? ' ?? _patchMap[$targetClassName\$.$name]' : ''})
                : _patchMap[$targetClassName\$.$name]
            : this.${f.name}''';
        }
        return '''$name: _patchMap.containsKey($targetClassName\$.$name)
          ? (_patchMap[$targetClassName\$.$name] is Function)
            ? _patchMap[$targetClassName\$.$name](this.${f.name})
            : _patchMap[$targetClassName\$.$name]
          : this.${f.name}''';
      } else {
        // For fields that don't exist in source class, use only patch values
        return '$name: _patchMap[$targetClassName\$.$name]';
      }
    });

    final result = constructorFields.join(',\n          ');
    return result.isEmpty ? '' : result;
  }

  /// Generate simple constructor parameters (no patch logic)
  static String generateSimpleConstructorParams(
    List<NameType> targetClassFields,
    List<NameType> sourceInterfaceFields,
    String parameterPrefix,
  ) {
    final sourceFieldNames = sourceInterfaceFields.map((f) => f.name).toSet();

    final constructorFields = targetClassFields.map((f) {
      final name = MethodGeneratorCommons.getCleanFieldName(f.name);
      final hasField = sourceFieldNames.contains(f.name);

      if (hasField) {
        return '$name: $parameterPrefix$name ?? this.${f.name}';
      } else {
        return '$name: this.${f.name}';
      }
    });

    final result = constructorFields.join(',\n          ');
    return result.isEmpty ? '' : result;
  }
}
