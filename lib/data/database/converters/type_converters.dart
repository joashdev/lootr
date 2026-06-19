import 'dart:convert';
import 'package:drift/drift.dart';

class DateTimeConverter extends TypeConverter<DateTime, String> {
  const DateTimeConverter();

  @override
  DateTime fromSql(String fromDb) => DateTime.parse(fromDb);

  @override
  String toSql(DateTime value) => value.toUtc().toIso8601String();
}

class JsonConverter extends TypeConverter<Map<String, dynamic>, String> {
  const JsonConverter();

  @override
  Map<String, dynamic> fromSql(String fromDb) {
    if (fromDb.isEmpty) return {};
    return Map<String, dynamic>.from(json.decode(fromDb) as Map);
  }

  @override
  String toSql(Map<String, dynamic> value) {
    if (value.isEmpty) return '{}';
    return json.encode(value);
  }
}
