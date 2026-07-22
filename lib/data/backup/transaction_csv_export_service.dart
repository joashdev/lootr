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
        'occurred_at,direction,account,currency,amount,'
        'destination_account,destination_currency,destination_amount,'
        'category,payee,title,note',
      );
      final rows = await database
          .customSelect(
            '''
        SELECT
          t.id AS entry_id,
          t.occurred_at,
          t.transaction_direction,
          a.name AS account_name,
          COALESCE(t.currency_code, a.currency_code) AS currency_code,
          t.amount_atoms,
          t.amount_scale,
          t.amount,
          NULL AS destination_account_name,
          NULL AS destination_currency_code,
          NULL AS destination_amount_atoms,
          NULL AS destination_amount_scale,
          NULL AS destination_amount,
          c.name AS category_name,
          COALESCE(p.display_name, p.normalized_name) AS payee_name,
          t.title,
          t.note
        FROM transactions t
        JOIN accounts a ON a.id = t.account_id
        LEFT JOIN categories c ON c.id = t.category_id
        LEFT JOIN payees p ON p.id = t.payee_id
        WHERE t.deleted_at IS NULL
        UNION ALL
        SELECT
          tr.id AS entry_id,
          tr.occurred_at,
          'transfer' AS transaction_direction,
          source.name AS account_name,
          COALESCE(tr.source_currency_code, source.currency_code)
            AS currency_code,
          tr.source_amount_atoms AS amount_atoms,
          tr.source_amount_scale AS amount_scale,
          tr.amount,
          destination.name AS destination_account_name,
          COALESCE(tr.destination_currency_code, destination.currency_code)
            AS destination_currency_code,
          tr.destination_amount_atoms,
          tr.destination_amount_scale,
          tr.amount AS destination_amount,
          NULL AS category_name,
          NULL AS payee_name,
          NULL AS title,
          tr.note
        FROM transfers tr
        JOIN accounts source ON source.id = tr.source_account_id
        JOIN accounts destination ON destination.id = tr.destination_account_id
        WHERE tr.deleted_at IS NULL
        ORDER BY occurred_at, entry_id
        ''',
            readsFrom: {
              database.transactions,
              database.transfers,
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
        final destinationAtoms = row.readNullable<String>(
          'destination_amount_atoms',
        );
        final destinationScale = row.readNullable<int>(
          'destination_amount_scale',
        );
        final destinationProjection = row.readNullable<double>(
          'destination_amount',
        );
        final destinationAmount =
            destinationAtoms != null && destinationScale != null
            ? _formatAtoms(destinationAtoms, destinationScale)
            : destinationProjection?.toString();
        sink.writeln(
          <Object?>[
            row.read<DateTime>('occurred_at').toUtc().toIso8601String(),
            row.read<String>('transaction_direction'),
            row.read<String>('account_name'),
            row.read<String>('currency_code'),
            amount,
            row.readNullable<String>('destination_account_name'),
            row.readNullable<String>('destination_currency_code'),
            destinationAmount,
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
