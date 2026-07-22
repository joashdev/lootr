enum MigrationRunPhase {
  selected,
  analyzing,
  needsReview,
  reconciling,
  ready,
  applying,
  verifying,
  interrupted,
  failed,
  complete,
  cancelled,
  rolledBack,
}

enum MigrationIssueLevel { info, needsReview, blocking }

enum MigrationPartitionStatus { reconciled, needsReview, blocking }

enum MigrationTitlePolicy { preserveAndSuggest, preserveOnly, createPayees }

extension MigrationTitlePolicyCopy on MigrationTitlePolicy {
  String get label => switch (this) {
    MigrationTitlePolicy.preserveAndSuggest =>
      'Preserve titles and suggest payees',
    MigrationTitlePolicy.preserveOnly => 'Preserve titles only',
    MigrationTitlePolicy.createPayees => 'Create payees from titles',
  };

  String get description => switch (this) {
    MigrationTitlePolicy.preserveAndSuggest =>
      'Keeps every original title and makes reversible payee suggestions.',
    MigrationTitlePolicy.preserveOnly =>
      'Keeps exact titles without creating or suggesting payees.',
    MigrationTitlePolicy.createPayees =>
      'Creates payees while retaining the exact source title for reversal.',
  };
}

class MigrationSourceSelection {
  const MigrationSourceSelection({
    required this.opaqueToken,
    this.safeLabel = 'Selected Cashew backup',
  });

  /// An opaque handle understood only by the selected source adapter.
  ///
  /// Widgets must never render or log this value.
  final String opaqueToken;
  final String safeLabel;
}

enum MigrationPickerStatus { selected, cancelled, unavailable }

class MigrationPickerResult {
  const MigrationPickerResult._({
    required this.status,
    this.selection,
    this.message,
  });

  const MigrationPickerResult.selected(MigrationSourceSelection selection)
    : this._(status: MigrationPickerStatus.selected, selection: selection);

  const MigrationPickerResult.cancelled()
    : this._(status: MigrationPickerStatus.cancelled);

  const MigrationPickerResult.unavailable(String message)
    : this._(status: MigrationPickerStatus.unavailable, message: message);

  final MigrationPickerStatus status;
  final MigrationSourceSelection? selection;
  final String? message;
}

class MigrationDispositionCounts {
  const MigrationDispositionCounts({
    required this.exact,
    required this.transformed,
    required this.preserved,
    required this.review,
    required this.blocking,
  });

  final int exact;
  final int transformed;
  final int preserved;
  final int review;
  final int blocking;

  int get total => exact + transformed + preserved + review + blocking;
}

class MigrationReviewGroup {
  const MigrationReviewGroup({
    required this.id,
    required this.title,
    required this.description,
    required this.count,
    required this.level,
    this.resolved = false,
    this.items = const [],
  });

  final String id;
  final String title;
  final String description;
  final int count;
  final MigrationIssueLevel level;
  final bool resolved;
  final List<MigrationReviewItem> items;

  MigrationReviewGroup copyWith({bool? resolved}) {
    return MigrationReviewGroup(
      id: id,
      title: title,
      description: description,
      count: count,
      level: level,
      resolved: resolved ?? this.resolved,
      items: items,
    );
  }
}

class MigrationReviewItem {
  const MigrationReviewItem({
    required this.safeReference,
    required this.issueCode,
    required this.proposedResolution,
  });

  final String safeReference;
  final String issueCode;
  final String proposedResolution;
}

class MigrationCurrencyPartition {
  const MigrationCurrencyPartition({
    required this.id,
    required this.accountLabel,
    required this.currencyLabel,
    required this.precision,
    required this.status,
    required this.explanation,
  });

  final String id;
  final String accountLabel;
  final String currencyLabel;
  final int precision;
  final MigrationPartitionStatus status;
  final String explanation;
}

class MigrationRunProjection {
  const MigrationRunProjection({
    required this.id,
    required this.phase,
    required this.sourceLabel,
    required this.timezoneId,
    required this.timezoneLabel,
    required this.titlePolicy,
    required this.startedAt,
    required this.updatedAt,
    required this.progress,
    required this.progressLabel,
    required this.schemaVersion,
    required this.accountCount,
    required this.dateRangeLabel,
    required this.currencyLabels,
    required this.dispositions,
    required this.reviewGroups,
    required this.partitions,
    this.cancelRequested = false,
    this.canRollback = false,
    this.latestImportedMonth,
    this.preservedGroups = const [],
  });

  final String id;
  final MigrationRunPhase phase;
  final String sourceLabel;
  final String timezoneId;
  final String timezoneLabel;
  final MigrationTitlePolicy titlePolicy;
  final DateTime startedAt;
  final DateTime updatedAt;
  final double progress;
  final String progressLabel;
  final int? schemaVersion;
  final int accountCount;
  final String dateRangeLabel;
  final List<String> currencyLabels;
  final MigrationDispositionCounts dispositions;
  final List<MigrationReviewGroup> reviewGroups;
  final List<MigrationCurrencyPartition> partitions;
  final bool cancelRequested;
  final bool canRollback;
  final DateTime? latestImportedMonth;
  final List<MigrationPreservedGroup> preservedGroups;

  bool get isTerminal => switch (phase) {
    MigrationRunPhase.complete ||
    MigrationRunPhase.cancelled ||
    MigrationRunPhase.rolledBack => true,
    _ => false,
  };

  bool get canCancel => switch (phase) {
    MigrationRunPhase.selected ||
    MigrationRunPhase.analyzing ||
    MigrationRunPhase.needsReview ||
    MigrationRunPhase.reconciling ||
    MigrationRunPhase.ready => true,
    _ => false,
  };

  bool get blocksBackNavigation =>
      phase == MigrationRunPhase.applying ||
      phase == MigrationRunPhase.verifying;

  int get unresolvedReviewCount => reviewGroups
      .where((group) => !group.resolved)
      .fold(0, (total, group) => total + group.count);

  bool get hasBlockingIssues => reviewGroups.any(
    (group) => group.level == MigrationIssueLevel.blocking && !group.resolved,
  );

  MigrationRunProjection copyWith({
    MigrationRunPhase? phase,
    String? timezoneId,
    String? timezoneLabel,
    MigrationTitlePolicy? titlePolicy,
    DateTime? updatedAt,
    double? progress,
    String? progressLabel,
    int? schemaVersion,
    int? accountCount,
    String? dateRangeLabel,
    List<String>? currencyLabels,
    MigrationDispositionCounts? dispositions,
    List<MigrationReviewGroup>? reviewGroups,
    List<MigrationCurrencyPartition>? partitions,
    bool? cancelRequested,
    bool? canRollback,
    DateTime? Function()? latestImportedMonth,
    List<MigrationPreservedGroup>? preservedGroups,
  }) {
    return MigrationRunProjection(
      id: id,
      phase: phase ?? this.phase,
      sourceLabel: sourceLabel,
      timezoneId: timezoneId ?? this.timezoneId,
      timezoneLabel: timezoneLabel ?? this.timezoneLabel,
      titlePolicy: titlePolicy ?? this.titlePolicy,
      startedAt: startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      progress: progress ?? this.progress,
      progressLabel: progressLabel ?? this.progressLabel,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      accountCount: accountCount ?? this.accountCount,
      dateRangeLabel: dateRangeLabel ?? this.dateRangeLabel,
      currencyLabels: currencyLabels ?? this.currencyLabels,
      dispositions: dispositions ?? this.dispositions,
      reviewGroups: reviewGroups ?? this.reviewGroups,
      partitions: partitions ?? this.partitions,
      cancelRequested: cancelRequested ?? this.cancelRequested,
      canRollback: canRollback ?? this.canRollback,
      latestImportedMonth: latestImportedMonth != null
          ? latestImportedMonth()
          : this.latestImportedMonth,
      preservedGroups: preservedGroups ?? this.preservedGroups,
    );
  }
}

class MigrationPreservedGroup {
  const MigrationPreservedGroup({
    required this.sourceKind,
    required this.count,
  });

  final String sourceKind;
  final int count;
}

class MigrationTimezoneOption {
  const MigrationTimezoneOption({required this.id, required this.label});

  final String id;
  final String label;
}

class DataPortabilityResult {
  const DataPortabilityResult({required this.succeeded, required this.message});

  final bool succeeded;
  final String message;
}
