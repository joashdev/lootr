import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lootr/data/repositories/account_repo.dart';
import 'package:lootr/domain/use_cases/recalc_balance.dart';
import 'package:lootr/domain/value_objects/result.dart';

class MockAccountRepo extends Mock implements AccountRepo {}

void main() {
  late MockAccountRepo mockRepo;
  late RecalcBalance useCase;

  setUp(() {
    mockRepo = MockAccountRepo();
    useCase = RecalcBalance(mockRepo);
  });

  group('RecalcBalance', () {
    test('should return Success with new balance', () async {
      when(() => mockRepo.recalcBalance('acc-1')).thenAnswer((_) async {});
      when(() => mockRepo.getBalance('acc-1'))
          .thenAnswer((_) async => 750.0);

      final result = await useCase('acc-1');

      expect(result.isSuccess, isTrue);
      final success = result as Success<double>;
      expect(success.value, 750.0);
    });

    test('should return Failure when recalc throws', () async {
      when(() => mockRepo.recalcBalance('acc-1'))
          .thenThrow(Exception('DB error'));

      final result = await useCase('acc-1');

      expect(result.isFailure, isTrue);
      final failure = result as Failure<double>;
      expect(failure.code, 'recalc_error');
    });
  });
}
