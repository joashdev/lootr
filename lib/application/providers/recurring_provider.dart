import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/mappers.dart';
import '../../domain/entities/recurring_template.dart';
import 'repo_providers.dart';

final recurringProvider = StreamProvider<List<RecurringTemplate>>((ref) {
  final repo = ref.watch(recurringRepoProvider);
  return repo.watchAll().map((rows) {
    final entities = rows.map((r) => r.toEntity()).toList();
    entities.sort((a, b) {
      if (a.nextOccurrenceAt == null && b.nextOccurrenceAt == null) return 0;
      if (a.nextOccurrenceAt == null) return 1;
      if (b.nextOccurrenceAt == null) return -1;
      return a.nextOccurrenceAt!.compareTo(b.nextOccurrenceAt!);
    });
    return entities;
  });
});
