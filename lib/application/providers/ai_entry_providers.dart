import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../../ai/categorizer.dart';
import '../../ai/nl_parser.dart';
import '../../ai/ocr_pipeline.dart';
import '../ai/smart_entry_assistance.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/transaction_repo.dart';
import '../../domain/use_cases/parse_nl.dart';
import '../../domain/use_cases/run_ocr.dart';
import 'accounts_provider.dart';
import 'ai_settings_provider.dart';
import 'payees_provider.dart';
import 'repo_providers.dart';

/// The latest confirmed category for each normalized payee name.
///
/// This is local ledger history only. It never creates or updates a
/// transaction; [Categorizer] uses it to prefill a reviewable suggestion.
final payeeCategoryHistoryProvider = StreamProvider<Map<String, String>>((ref) {
  final transactionRepo = ref.watch(transactionRepoProvider);
  final payeeRepo = ref.watch(payeeRepoProvider);

  return Rx.combineLatest2<
    List<TransactionData>,
    List<PayeeData>,
    Map<String, String>
  >(
    transactionRepo.watchFiltered(const TransactionRepoFilters()),
    payeeRepo.watchAll(),
    (transactions, payees) {
      final payeesById = {for (final payee in payees) payee.id: payee};
      final newestFirst = [...transactions]
        ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
      final history = <String, String>{};

      for (final transaction in newestFirst) {
        final payeeId = transaction.payeeId;
        final categoryId = transaction.categoryId;
        if (payeeId == null || categoryId == null) continue;
        final payee = payeesById[payeeId];
        if (payee == null) continue;
        history.putIfAbsent(payee.normalizedName, () => categoryId);
        final displayName = payee.displayName?.trim().toLowerCase();
        if (displayName != null && displayName.isNotEmpty) {
          history.putIfAbsent(displayName, () => categoryId);
        }
      }

      return Map.unmodifiable(history);
    },
  );
});

final nlParserProvider = Provider<NLParser>((ref) {
  final accounts = ref.watch(accountsProvider).asData?.value ?? const [];
  final payees = ref.watch(payeesProvider).asData?.value ?? const [];
  return NLParser(
    knownAccounts: accounts.map((account) => account.name).toList(),
    knownPayees: payees.map((payee) => payee.resolvedName).toList(),
    logRepo: ref.watch(aiProcessingLogRepoProvider),
    aiEnabled: ref.watch(aiEnabledProvider),
  );
});

final parseNLProvider = Provider<ParseNL>((ref) {
  return ParseNL(
    parser: ref.watch(nlParserProvider),
    aiEnabled: ref.watch(aiEnabledProvider),
  );
});

final ocrPipelineProvider = Provider<OCRPipeline>((ref) {
  return OCRPipeline(
    nlParser: ref.watch(nlParserProvider),
    logRepo: ref.watch(aiProcessingLogRepoProvider),
    aiEnabled: ref.watch(aiEnabledProvider),
  );
});

final runOCRProvider = Provider<RunOCR>((ref) {
  return RunOCR(
    pipeline: ref.watch(ocrPipelineProvider),
    aiEnabled: ref.watch(aiEnabledProvider),
  );
});

final categorizerProvider = FutureProvider<Categorizer>((ref) async {
  final history = await ref.watch(payeeCategoryHistoryProvider.future);
  return Categorizer(
    payeeCategoryHistory: history,
    logRepo: ref.watch(aiProcessingLogRepoProvider),
    aiEnabled: ref.watch(aiEnabledProvider),
  );
});

final smartEntryAssistanceProvider = FutureProvider<SmartEntryAssistance>((
  ref,
) async {
  return SmartEntryAssistance(
    ref.watch(parseNLProvider),
    await ref.watch(categorizerProvider.future),
  );
});
