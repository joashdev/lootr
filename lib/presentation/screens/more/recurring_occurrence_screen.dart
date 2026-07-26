import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../application/providers/recurring_detail_provider.dart';
import 'recurring_detail_screen.dart';

class RecurringOccurrenceScreen extends ConsumerWidget {
  const RecurringOccurrenceScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(recurringOccurrenceProvider(id))
        .when(
          data: (occurrence) {
            if (occurrence == null) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'This occurrence is no longer available. No ledger data changed.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return RecurringDetailScreen(
              id: occurrence.recurringTemplateId,
              highlightedOccurrenceId: occurrence.id,
            );
          },
          error: (_, _) => const Scaffold(
            body: Center(child: Text('The occurrence could not be opened.')),
          ),
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
        );
  }
}
