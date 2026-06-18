import 'package:drift/drift.dart';

class TypeConverters extends TypeConverter<String, String> {
  const TypeConverters();

  @override
  String fromSql(String fromDb) => fromDb;

  @override
  String toSql(String value) => value;
}
