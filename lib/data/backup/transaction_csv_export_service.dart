import 'dart:io';

import '../database/app_database.dart';
import '../security/secure_file_lifecycle.dart';

/// Writes a user-requested, readable transaction export without creating an
/// untracked plaintext copy inside app storage.
class TransactionCsvExportService {
  const TransactionCsvExportService({
    this.secureFiles = const SecureFileLifecycle(),
  });

  final SecureFileLifecycle secureFiles;

  Future<int> export({
    required AppDatabase database,
    required File destination,
  }) async {
    final creating = File('${destination.path}.creating');
    await secureFiles.bestEffortDelete(creating);
    final sink = creating.openWrite(mode: FileMode.writeOnly);
    var count = 0;
    try {
      sink.writeln(
        'occurred_at,direction,account,currency,amount,category,payee,title,note',
      );
      final rows = await database
          .customSelect(
            '''
        SELECT
          t.occurred_at,
          t.transaction_direction,
          a.name AS account_name,
          COALESCE(t.currency_code, a.currency_code) AS currency_code,
          t.amount_atoms,
          t.amount_scale,
          t.amount,
          c.name AS category_name,
          COALESCE(p.display_name, p.normalized_name) AS payee_name,
          t.title,
          t.note
        FROM transactions t
        JOIN accounts a ON a.id = t.account_id
        LEFT JOIN categories c ON c.id = t.category_id
        LEFT JOIN payees p ON p.id = t.payee_id
        WHERE t.deleted_at IS NULL
        ORDER BY t.occurred_at, t.id
        ''',
            readsFrom: {
              database.transactions,
              database.accounts,
              database.categories,
              database.payees,
            },
          )
          .get();

      for (final row in rows) {
        final atoms = row.readNullable<String>('amount_atoms');
        final scale = row.readNullable<int>('amount_scale');
        final amount = atoms != null && scale != null
            ? _formatAtoms(atoms, scale)
            : row.read<double>('amount').toString();
        sink.writeln(
          <Object?>[
            row.read<DateTime>('occurred_at').toUtc().toIso8601String(),
            row.read<String>('transaction_direction'),
            row.read<String>('account_name'),
            row.read<String>('currency_code'),
            amount,
            row.readNullable<String>('category_name'),
            row.readNullable<String>('payee_name'),
            row.readNullable<String>('title'),
            row.readNullable<String>('note'),
          ].map(_escape).join(','),
        );
        count++;
      }
      await sink.flush();
    } catch (_) {
      await sink.close();
      await secureFiles.bestEffortDelete(creating);
      rethrow;
    }
    await sink.close();

    if (await destination.exists()) {
      await secureFiles.bestEffortDelete(destination);
    }
    await creating.rename(destination.path);
    return count;
  }
}

String _formatAtoms(String sourceAtoms, int scale) {
  final atoms = BigInt.parse(sourceAtoms);
  final negative = atoms.isNegative;
  final digits = atoms.abs().toString().padLeft(scale + 1, '0');
  if (scale == 0) return '${negative ? '-' : ''}$digits';
  final split = digits.length - scale;
  return '${negative ? '-' : ''}${digits.substring(0, split)}.'
      '${digits.substring(split)}';
}

String _escape(Object? value) {
  final text = value?.toString() ?? '';
  if (!text.contains(RegExp('[,"\\r\\n]'))) return text;
  return '"${text.replaceAll('"', '""')}"';
}
