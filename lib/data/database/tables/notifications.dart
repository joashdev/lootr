import 'package:drift/drift.dart';

@DataClassName('NotificationData')
@TableIndex(name: 'idx_notifications_scheduled', columns: {#scheduledAt})
@TableIndex(name: 'idx_notifications_type', columns: {#notificationType})
class Notifications extends Table {
  TextColumn get id => text()();
  TextColumn get notificationType => text().named('notification_type')();
  TextColumn get relatedEntityId => text().named('related_entity_id').nullable()();
  DateTimeColumn get scheduledAt => dateTime().named('scheduled_at')();
  BoolColumn get isCompleted => boolean().named('is_completed').withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
