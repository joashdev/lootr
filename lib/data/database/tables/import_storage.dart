import 'package:drift/drift.dart';

@DataClassName('ImportRunData')
@TableIndex(name: 'idx_import_run_fingerprint', columns: {#sourceFingerprint})
@TableIndex(name: 'idx_import_run_state', columns: {#state})
class ImportRuns extends Table {
  TextColumn get id => text()();
  TextColumn get sourceSystem => text().named('source_system')();
  TextColumn get sourceFingerprint => text().named('source_fingerprint')();
  TextColumn get sourceFilename => text().named('source_filename').nullable()();
  IntColumn get sourceSchemaVersion =>
      integer().named('source_schema_version')();
  TextColumn get assumedTimezone =>
      text().named('assumed_timezone').nullable()();
  TextColumn get state => text()();
  TextColumn get policyJson => text().named('policy_json').nullable()();
  TextColumn get countsJson => text().named('counts_json').nullable()();
  TextColumn get stagingToken => text().named('staging_token').nullable()();
  TextColumn get cleanupStatus =>
      text().named('cleanup_status').withDefault(const Constant('pending'))();
  IntColumn get cleanupAttempts =>
      integer().named('cleanup_attempts').withDefault(const Constant(0))();
  DateTimeColumn get startedAt =>
      dateTime().named('started_at').withDefault(currentDateAndTime)();
  DateTimeColumn get completedAt =>
      dateTime().named('completed_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (state IN (\'selected\', \'validating\', \'validated\', \'staged\', \'needs_review\', \'ready\', \'applying\', \'verifying\', \'complete\', \'cancel_requested\', \'cancelled\', \'interrupted\', \'failed\', \'rolled_back\'))',
    'CHECK (cleanup_status IN (\'pending\', \'in_progress\', \'complete\', \'best_effort_incomplete\'))',
    'CHECK (cleanup_attempts >= 0)',
  ];
}

@DataClassName('ImportSourceRecordData')
@TableIndex(
  name: 'uq_import_source_record',
  columns: {#importRunId, #sourceTable, #sourceEntityId},
  unique: true,
)
@TableIndex(
  name: 'idx_import_source_record_disposition',
  columns: {#importRunId, #disposition},
)
class ImportSourceRecords extends Table {
  TextColumn get id => text()();
  TextColumn get importRunId =>
      text().named('import_run_id').references(ImportRuns, #id)();
  TextColumn get sourceTable => text().named('source_table')();
  TextColumn get sourceEntityId => text().named('source_entity_id')();
  TextColumn get sourcePayloadSha256 => text().named('source_payload_sha256')();
  TextColumn get canonicalKind => text().named('canonical_kind').nullable()();
  TextColumn get canonicalPayloadSha256 =>
      text().named('canonical_payload_sha256').nullable()();
  TextColumn get disposition => text()();
  TextColumn get reasonCode => text().named('reason_code').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (disposition IN (\'exact_import\', \'transformed_import\', \'preserved_only\', \'review_required\', \'ignored_safe\', \'invalid_blocking\'))',
  ];
}

@DataClassName('ImportSourceRelationData')
@TableIndex(name: 'idx_import_source_relation_run', columns: {#importRunId})
class ImportSourceRelations extends Table {
  TextColumn get id => text()();
  TextColumn get importRunId =>
      text().named('import_run_id').references(ImportRuns, #id)();
  TextColumn get sourceFrom => text().named('source_from')();
  TextColumn get relationKind => text().named('relation_kind')();
  TextColumn get sourceTo => text().named('source_to')();
  TextColumn get disposition => text()();
  TextColumn get reasonCode => text().named('reason_code').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (disposition IN (\'exact_import\', \'transformed_import\', \'preserved_only\', \'review_required\', \'ignored_safe\', \'invalid_blocking\'))',
  ];
}

@DataClassName('ImportProvenanceData')
@TableIndex(
  name: 'uq_import_provenance_mapping',
  columns: {
    #sourceSystem,
    #sourceFingerprint,
    #sourceEntityType,
    #sourceEntityId,
    #targetTable,
    #targetId,
    #mappingRole,
  },
  unique: true,
)
@TableIndex(
  name: 'idx_import_provenance_target',
  columns: {#targetTable, #targetId},
)
class ImportProvenance extends Table {
  TextColumn get id => text()();
  TextColumn get importRunId =>
      text().named('import_run_id').references(ImportRuns, #id)();
  TextColumn get sourceSystem => text().named('source_system')();
  TextColumn get sourceFingerprint => text().named('source_fingerprint')();
  TextColumn get sourceEntityType => text().named('source_entity_type')();
  TextColumn get sourceEntityId => text().named('source_entity_id')();
  TextColumn get sourcePayloadSha256 => text().named('source_payload_sha256')();
  TextColumn get targetTable => text().named('target_table')();
  TextColumn get targetId => text().named('target_id')();
  TextColumn get mappingRole => text().named('mapping_role')();
  TextColumn get importedTargetSha256 =>
      text().named('imported_target_sha256')();
  DateTimeColumn get importedAt =>
      dateTime().named('imported_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ImportDiscrepancyData')
@TableIndex(
  name: 'idx_import_discrepancy_run_severity',
  columns: {#importRunId, #severity},
)
class ImportDiscrepancies extends Table {
  TextColumn get id => text()();
  TextColumn get importRunId =>
      text().named('import_run_id').references(ImportRuns, #id)();
  TextColumn get severity => text()();
  TextColumn get issueCode => text().named('issue_code')();
  TextColumn get sourceLocatorHash =>
      text().named('source_locator_hash').nullable()();
  TextColumn get messageCode => text().named('message_code')();
  TextColumn get redactedDetailsJson =>
      text().named('redacted_details_json').nullable()();
  BoolColumn get isResolved =>
      boolean().named('is_resolved').withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (severity IN (\'info\', \'warning\', \'review\', \'blocking\'))',
  ];
}

@DataClassName('ImportPreservedPayloadData')
@TableIndex(name: 'idx_import_preserved_payload_run', columns: {#importRunId})
class ImportPreservedPayloads extends Table {
  TextColumn get id => text()();
  TextColumn get importRunId =>
      text().named('import_run_id').references(ImportRuns, #id)();
  TextColumn get sourceLocator => text().named('source_locator')();
  IntColumn get payloadVersion =>
      integer().named('payload_version').withDefault(const Constant(1))();
  TextColumn get payloadJson => text().named('payload_json')();
  TextColumn get payloadSha256 => text().named('payload_sha256')();
  TextColumn get reasonCode => text().named('reason_code')();
  TextColumn get relatedTargetTable =>
      text().named('related_target_table').nullable()();
  TextColumn get relatedTargetId =>
      text().named('related_target_id').nullable()();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ImportCheckpointData')
@TableIndex(
  name: 'uq_import_checkpoint_stage',
  columns: {#importRunId, #stage, #sourceTable},
  unique: true,
)
class ImportCheckpoints extends Table {
  TextColumn get id => text()();
  TextColumn get importRunId =>
      text().named('import_run_id').references(ImportRuns, #id)();
  TextColumn get stage => text()();
  TextColumn get sourceTable => text().named('source_table')();
  TextColumn get lastSourceEntityHash =>
      text().named('last_source_entity_hash').nullable()();
  TextColumn get checkpointJson => text().named('checkpoint_json').nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('RollbackCheckpointData')
@TableIndex(
  name: 'uq_rollback_checkpoint_run',
  columns: {#importRunId},
  unique: true,
)
class RollbackCheckpoints extends Table {
  TextColumn get id => text()();
  TextColumn get importRunId =>
      text().named('import_run_id').references(ImportRuns, #id)();
  TextColumn get backupPath => text().named('backup_path')();
  TextColumn get backupSha256 => text().named('backup_sha256')();
  IntColumn get backupFormatVersion =>
      integer().named('backup_format_version')();
  TextColumn get keyAlias => text().named('key_alias')();
  TextColumn get state => text().withDefault(const Constant('ready'))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get restoredAt => dateTime().named('restored_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (state IN (\'creating\', \'ready\', \'restoring\', \'restored\', \'invalid\'))',
  ];
}
