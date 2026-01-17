// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: type=lint, unnecessary_cast

part of 'ex8_enums_test.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Pet _$PetFromJson(Map<String, dynamic> json) => Pet(
  type: json['type'] as String,
  blim: $enumDecode(_$eBlimEnumMap, json['blim']),
);

Map<String, dynamic> _$PetToJson(Pet instance) => <String, dynamic>{
  'type': instance.type,
  'blim': _$eBlimEnumMap[instance.blim]!,
};

const _$eBlimEnumMap = {
  eBlim.one: 'one',
  eBlim.another: 'another',
  eBlim.andthis: 'andthis',
};
