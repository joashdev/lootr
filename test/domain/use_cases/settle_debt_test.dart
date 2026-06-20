import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:drift/drift.dart';
import 'package:lootr/data/repositories/debt_repo.dart';
import 'package:lootr/data/database/app_database.dart';
import 'package:lootr/domain/use_cases/settle_debt.dart';
import 'package:lootr/domain/value_objects/result.dart';

class MockDebtRepo extends Mock implements DebtRepo {}

void main() {
  late MockDebtRepo mockRepo;
  late SettleDebt useCase;

  final testDebt = DebtRecordData(
    id: 'dbt-1',
    ownerUserId: 'usr-1',
    counterpartyName: 'Alex',
    debtDirection: 'lent',
    amount: 500,
    remainingBalance: 500,
    status: 'active',
    syncStatus: 'local_only',
    createdAt: DateTime(2026, 6, 19),
    updatedAt: DateTime(2026, 6, 19),
  );

  setUp(() {
    mockRepo = MockDebtRepo();
    useCase = SettleDebt(mockRepo);
  });

  group('SettleDebt', () {
    test('should return Success on valid settlement', () async {
      when(() => mockRepo.watchById('dbt-1'))
          .thenAnswer((_) => Stream.value(testDebt));
      when(() => mockRepo.settle('dbt-1')).thenAnswer((_) async {});

      final result = await useCase('dbt-1');

      expect(result.isSuccess, isTrue);
    });

    test('should return Failure when debt not found', () async {
      when(() => mockRepo.watchById('dbt-1'))
          .thenAnswer((_) => Stream.value(null));

      final result = await useCase('dbt-1');

      expect(result.isFailure, isTrue);
      final failure = result as Failure<void>;
      expect(failure.code, 'not_found');
    });

    test('should return Failure when settle throws', () async {
      when(() => mockRepo.watchById('dbt-1'))
          .thenAnswer((_) => Stream.value(testDebt));
      when(() => mockRepo.settle('dbt-1'))
          .thenThrow(Exception('Not found'));

      final result = await useCase('dbt-1');

      expect(result.isFailure, isTrue);
      final failure = result as Failure<void>;
      expect(failure.code, 'settle_error');
    });
  });
}
