import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/domain/use_cases/parse_nl.dart';
import 'package:lootr/domain/value_objects/result.dart';
import 'package:lootr/domain/value_objects/parsed_transaction.dart';
import 'package:lootr/domain/value_objects/field_types.dart';

void main() {
  late ParseNL useCase;

  setUp(() {
    useCase = ParseNL();
  });

  group('ParseNL', () {
    group('amount extraction', () {
      test('should extract integer amount', () {
        final result = useCase('mcdo 250 gcash');

        expect(result.isSuccess, isTrue);
        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.amount, 250);
      });

      test('should extract amount with comma separators', () {
        final result = useCase('rent 15,000 bank');

        expect(result.isSuccess, isTrue);
        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.amount, 15000);
      });

      test('should handle peso sign', () {
        final result = useCase('groceries ₱500 cash');

        expect(result.isSuccess, isTrue);
        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.amount, 500);
      });

      test('should handle dollar sign', () {
        final result = useCase('subscription \$10 card');

        expect(result.isSuccess, isTrue);
        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.amount, 10);
      });

      test('should handle k abbreviation', () {
        final result = useCase('laptop 50k bank');

        expect(result.isSuccess, isTrue);
        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.amount, 50000);
      });

      test('should handle m abbreviation', () {
        final result = useCase('house 2m bank');

        expect(result.isSuccess, isTrue);
        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.amount, 2000000);
      });

      test('should handle decimal amounts', () {
        final result = useCase('coffee 150.50 cash');

        expect(result.isSuccess, isTrue);
        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.amount, 150.50);
      });

      test('should handle leading decimal like .99', () {
        final result = useCase('snack .99 gcash');

        expect(result.isSuccess, isTrue);
        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.amount, 0.99);
      });

      test('should handle negative amounts', () {
        final result = useCase('refund -500 gcash');

        expect(result.isSuccess, isTrue);
        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.amount, -500);
      });

      test('should handle k suffix with decimal like 0.5k', () {
        final result = useCase('item 0.5k cash');

        expect(result.isSuccess, isTrue);
        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.amount, 500);
      });

      test('should handle m suffix with decimal like 1.5m', () {
        final result = useCase('car 1.5m bank');

        expect(result.isSuccess, isTrue);
        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.amount, 1500000);
      });
    });

    group('payee extraction', () {
      test('should extract payee from mcdo 250 gcash', () {
        final result = useCase('mcdo 250 gcash');

        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.payee, 'mcdo');
      });

      test('should extract multi-word payee', () {
        final result = useCase('jollibee delivery 350 cash');

        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.payee, 'jollibee delivery');
      });
    });

    group('account extraction', () {
      test('should extract gcash account', () {
        final result = useCase('mcdo 250 gcash');

        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.account, 'gcash');
      });

      test('should extract maya account', () {
        final result = useCase('load 100 maya');

        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.account, 'maya');
      });

      test('should extract cash account', () {
        final result = useCase('food 200 cash');

        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.account, 'cash');
      });

      test('should extract bank account', () {
        final result = useCase('transfer 1000 bpi');

        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.account, 'bpi');
      });
    });

    group('category extraction', () {
      test('should extract food category', () {
        final result = useCase('food 200 gcash');

        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.category, 'Food');
      });

      test('should extract transport category', () {
        final result = useCase('transport 150 cash');

        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.category, 'Transport');
      });

      test('should extract gas as Transport', () {
        final result = useCase('gas 500 gcash');

        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.category, 'Transport');
      });
    });

    group('direction extraction', () {
      test('should default to expense', () {
        final result = useCase('mcdo 250 gcash');

        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.direction, TransactionDirection.expense);
      });

      test('should detect income from salary keyword', () {
        final result = useCase('salary 50000 bank');

        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.direction, TransactionDirection.income);
      });

      test('should detect income from received keyword', () {
        final result = useCase('received 1000 gcash');

        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.direction, TransactionDirection.income);
      });

      test('should detect income from refund keyword', () {
        final result = useCase('refund 500 gcash');

        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.direction, TransactionDirection.income);
      });
    });

    group('edge cases', () {
      test('should return Failure for empty input', () {
        final result = useCase('');

        expect(result.isFailure, isTrue);
        final failure = result as Failure<ParsedTransaction>;
        expect(failure.code, 'empty_input');
      });

      test('should return Failure for whitespace-only input', () {
        final result = useCase('   ');

        expect(result.isFailure, isTrue);
      });

      test('should return Failure for unparseable input', () {
        final result = useCase('hello world');

        expect(result.isFailure, isTrue);
        final failure = result as Failure<ParsedTransaction>;
        expect(failure.code, 'parse_failed');
      });

      test('should compute confidence correctly', () {
        final result = useCase('mcdo 250 gcash');

        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.confidence, greaterThan(0));
        expect(parsed.confidence, lessThanOrEqualTo(1));
      });
    });

    group('combined scenarios', () {
      test('mcdo 250 gcash -> amount=250 payee=mcdo account=gcash', () {
        final result = useCase('mcdo 250 gcash');

        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.amount, 250);
        expect(parsed.payee, 'mcdo');
        expect(parsed.account, 'gcash');
      });

      test('should parse with all fields', () {
        final result = useCase('jollibee delivery food 350 gcash');

        final parsed = (result as Success<ParsedTransaction>).value;
        expect(parsed.amount, 350);
        expect(parsed.payee, 'jollibee delivery');
        expect(parsed.account, 'gcash');
        expect(parsed.category, 'Food');
      });
    });
  });
}
