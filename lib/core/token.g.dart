// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Token _$TokenFromJson(Map<String, dynamic> json) => Token(
      name: json['name'] as String,
      symbol: json['symbol'] as String,
      decimals: json['decimals'] as int,
    );

Map<String, dynamic> _$TokenToJson(Token instance) => <String, dynamic>{
      'name': instance.name,
      'symbol': instance.symbol,
      'decimals': instance.decimals,
    };
