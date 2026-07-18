import 'package:drift/drift.dart';

import 'transactions.dart';

@DataClassName('TransactionAttachmentLinkData')
@TableIndex(
  name: 'idx_transaction_attachment_link_transaction',
  columns: {#transactionId},
)
class TransactionAttachmentLinks extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId =>
      text().named('transaction_id').references(Transactions, #id)();
  TextColumn get url => text()();
  TextColumn get linkType => text()
      .named('link_type')
      .withDefault(const Constant('remote_reference'))();
  BoolColumn get attachmentBytesMigrated => boolean()
      .named('attachment_bytes_migrated')
      .withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (link_type IN (\'remote_reference\', \'local_attachment\'))',
  ];
}
