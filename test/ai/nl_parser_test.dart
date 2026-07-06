import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/ai/nl_parser.dart';
import 'package:lootr/domain/value_objects/field_types.dart';

void main() {
  late NLParser parser;

  setUp(() {
    parser = const NLParser();
  });

  group('NLParser', () {
    group('amount extraction', () {
      test('extracts integer amount', () {
        final result = parser.parse('mcdo 250 gcash');
        expect(result, isNotNull);
        expect(result!.parsed.amount, 250);
      });

      test('extracts amount with comma separators', () {
        final result = parser.parse('rent 15,000 bank');
        expect(result, isNotNull);
        expect(result!.parsed.amount, 15000);
      });

      test('handles peso sign', () {
        final result = parser.parse('groceries \u20B1500 cash');
        expect(result, isNotNull);
        expect(result!.parsed.amount, 500);
      });

      test('handles dollar sign', () {
        final result = parser.parse('subscription \$10 card');
        expect(result, isNotNull);
        expect(result!.parsed.amount, 10);
      });

      test('handles euro sign', () {
        final result = parser.parse('hotel \u20AC200 card');
        expect(result, isNotNull);
        expect(result!.parsed.amount, 200);
      });

      test('handles pound sign', () {
        final result = parser.parse('pub \u00A350 cash');
        expect(result, isNotNull);
        expect(result!.parsed.amount, 50);
      });

      test('handles k abbreviation', () {
        final result = parser.parse('laptop 50k bank');
        expect(result, isNotNull);
        expect(result!.parsed.amount, 50000);
      });

      test('handles uppercase K abbreviation', () {
        final result = parser.parse('laptop 50K bank');
        expect(result, isNotNull);
        expect(result!.parsed.amount, 50000);
      });

      test('handles m abbreviation', () {
        final result = parser.parse('house 2m bank');
        expect(result, isNotNull);
        expect(result!.parsed.amount, 2000000);
      });

      test('handles uppercase M abbreviation', () {
        final result = parser.parse('house 2M bank');
        expect(result, isNotNull);
        expect(result!.parsed.amount, 2000000);
      });

      test('handles decimal amounts', () {
        final result = parser.parse('coffee 150.50 cash');
        expect(result, isNotNull);
        expect(result!.parsed.amount, 150.50);
      });

      test('handles leading decimal', () {
        final result = parser.parse('snack .99 gcash');
        expect(result, isNotNull);
        expect(result!.parsed.amount, 0.99);
      });

      test('handles negative amounts', () {
        final result = parser.parse('refund -500 gcash');
        expect(result, isNotNull);
        expect(result!.parsed.amount, -500);
      });

      test('handles 0.5k', () {
        final result = parser.parse('item 0.5k cash');
        expect(result, isNotNull);
        expect(result!.parsed.amount, 500);
      });

      test('handles 1.5m', () {
        final result = parser.parse('car 1.5m bank');
        expect(result, isNotNull);
        expect(result!.parsed.amount, 1500000);
      });
    });

    group('payee extraction', () {
      test('extracts payee from mcdo 250 gcash', () {
        final result = parser.parse('mcdo 250 gcash');
        expect(result!.parsed.payee, 'mcdo');
      });

      test('extracts multi-word payee', () {
        final result = parser.parse('jollibee delivery 350 cash');
        expect(result!.parsed.payee, 'jollibee delivery');
      });

      test('extracts payee without account keyword', () {
        final result = parser.parse('starbucks 200');
        expect(result!.parsed.payee, 'starbucks');
      });

      test('salary can be a payee for income', () {
        final result = parser.parse('salary 50000 bank');
        expect(result!.parsed.payee, 'salary');
      });

      test('freelance can be a payee', () {
        final result = parser.parse('freelance 30000 bank');
        expect(result!.parsed.payee, 'freelance');
      });

      test('return null when only keywords remain', () {
        final result = parser.parse('transport 150 cash');
        expect(result!.parsed.payee, null);
      });

      test('strips leading "at" connector left after category token removal', () {
        final result = parser.parse('Coffee at Starbucks 180');
        expect(result!.parsed.payee, 'Starbucks');
      });

      test('strips leading connector case-insensitively', () {
        final result = parser.parse('Dining At Antonios 900 card');
        expect(result!.parsed.payee, 'Antonios');
      });

      test('returns null when only a connector remains', () {
        final result = parser.parse('coffee at 180');
        expect(result!.parsed.payee, null);
      });

      test('keeps connector words inside the payee', () {
        final result = parser.parse('dine in diner 300 cash');
        expect(result!.parsed.payee, 'dine in diner');
      });
    });

    group('account extraction', () {
      test('extracts gcash account', () {
        final result = parser.parse('mcdo 250 gcash');
        expect(result!.parsed.account, 'gcash');
      });

      test('extracts maya account', () {
        final result = parser.parse('load 100 maya');
        expect(result!.parsed.account, 'maya');
      });

      test('extracts cash account', () {
        final result = parser.parse('food 200 cash');
        expect(result!.parsed.account, 'cash');
      });

      test('extracts bank account', () {
        final result = parser.parse('salary 50000 bank');
        expect(result!.parsed.account, 'bank');
      });

      test('extracts bpi account', () {
        final result = parser.parse('transfer 1000 bpi');
        expect(result!.parsed.account, 'bpi');
      });

      test('extracts bdo account', () {
        final result = parser.parse('payment 500 bdo');
        expect(result!.parsed.account, 'bdo');
      });

      test('extracts gotyme account', () {
        final result = parser.parse('load 200 gotyme');
        expect(result!.parsed.account, 'gotyme');
      });

      test('extracts seabank account', () {
        final result = parser.parse('deposit 1000 seabank');
        expect(result!.parsed.account, 'seabank');
      });

      test('extracts credit_card from credit keyword', () {
        final result = parser.parse('shopping 1000 credit');
        expect(result!.parsed.account, 'credit_card');
      });

      test('extracts credit_card from card keyword', () {
        final result = parser.parse('dinner 500 card');
        expect(result!.parsed.account, 'credit_card');
      });

      test('extracts ewallet from wallet keyword', () {
        final result = parser.parse('topup 200 wallet');
        expect(result!.parsed.account, 'ewallet');
      });

      test('extracts savings account', () {
        final result = parser.parse('deposit 1000 savings');
        expect(result!.parsed.account, 'savings');
      });

      test('prefers known account over keyword', () {
        final customParser = NLParser(knownAccounts: ['MyGcash']);
        final result = customParser.parse('mcdo 250 MyGcash');
        expect(result!.parsed.account, 'MyGcash');
      });
    });

    group('category extraction', () {
      test('extracts food category', () {
        final result = parser.parse('food 200 gcash');
        expect(result!.parsed.category, 'Food');
      });

      test('extracts Transport from transport keyword', () {
        final result = parser.parse('transport 150 cash');
        expect(result!.parsed.category, 'Transport');
      });

      test('extracts Transport from gas keyword', () {
        final result = parser.parse('gas 500 gcash');
        expect(result!.parsed.category, 'Transport');
      });

      test('extracts Transport from fare keyword', () {
        final result = parser.parse('fare 20 cash');
        expect(result!.parsed.category, 'Transport');
      });

      test('extracts Utilities from utilities keyword', () {
        final result = parser.parse('utilities 2000 bank');
        expect(result!.parsed.category, 'Utilities');
      });

      test('extracts Utilities from electric keyword', () {
        final result = parser.parse('electric 1500 gcash');
        expect(result!.parsed.category, 'Utilities');
      });

      test('extracts Utilities from water keyword', () {
        final result = parser.parse('water 500 gcash');
        expect(result!.parsed.category, 'Utilities');
      });

      test('extracts Utilities from internet keyword', () {
        final result = parser.parse('internet 1500 bank');
        expect(result!.parsed.category, 'Utilities');
      });

      test('extracts Shopping category', () {
        final result = parser.parse('shopping 1000 card');
        expect(result!.parsed.category, 'Shopping');
      });

      test('extracts Health category', () {
        final result = parser.parse('health 500 gcash');
        expect(result!.parsed.category, 'Health');
      });

      test('extracts Dining category', () {
        final result = parser.parse('dining 800 card');
        expect(result!.parsed.category, 'Dining');
      });

      test('extracts Income category from salary keyword', () {
        final result = parser.parse('salary 50000 bank');
        expect(result!.parsed.category, 'Income');
      });

      test('extracts Rent category', () {
        final result = parser.parse('rent 8000 bank');
        expect(result!.parsed.category, 'Rent');
      });
    });

    group('direction extraction', () {
      test('defaults to expense', () {
        final result = parser.parse('mcdo 250 gcash');
        expect(result!.parsed.direction, TransactionDirection.expense);
      });

      test('detects income from salary keyword', () {
        final result = parser.parse('salary 50000 bank');
        expect(result!.parsed.direction, TransactionDirection.income);
      });

      test('detects income from received keyword', () {
        final result = parser.parse('received 1000 gcash');
        expect(result!.parsed.direction, TransactionDirection.income);
      });

      test('detects income from got keyword', () {
        final result = parser.parse('got 500 cash');
        expect(result!.parsed.direction, TransactionDirection.income);
      });

      test('detects income from earned keyword', () {
        final result = parser.parse('earned 3000 bank');
        expect(result!.parsed.direction, TransactionDirection.income);
      });

      test('detects income from refund keyword', () {
        final result = parser.parse('refund 500 gcash');
        expect(result!.parsed.direction, TransactionDirection.income);
      });

      test('detects income from income keyword', () {
        final result = parser.parse('income 10000 bank');
        expect(result!.parsed.direction, TransactionDirection.income);
      });
    });

    group('transfers', () {
      test('detects transfer with "transfer X from A to B"', () {
        final result = parser.parse('transfer 1000 from gcash to bank');
        expect(result!.isTransfer, isTrue);
        expect(result.sourceAccount, 'gcash');
        expect(result.destAccount, 'bank');
        expect(result.parsed.direction, TransactionDirection.transfer);
      });

      test('detects transfer with "send X from A to B"', () {
        final result = parser.parse('send 500 gcash to maya');
        expect(result!.isTransfer, isTrue);
        expect(result.sourceAccount, 'gcash');
        expect(result.destAccount, 'maya');
      });

      test('detects transfer with "sent X from A to B"', () {
        final result = parser.parse('sent 1000 from bank to gcash');
        expect(result!.isTransfer, isTrue);
        expect(result.sourceAccount, 'bank');
        expect(result.destAccount, 'gcash');
      });

      test('detects transfer with "transfer X to B"', () {
        final result = parser.parse('transfer 500 to maya');
        expect(result!.isTransfer, isTrue);
        expect(result.destAccount, 'maya');
        expect(result.parsed.direction, TransactionDirection.transfer);
      });

      test('detects transfer with "move X from A to B"', () {
        final result = parser.parse('move 2000 from bdo to bpi');
        expect(result!.isTransfer, isTrue);
        expect(result.sourceAccount, 'bdo');
        expect(result.destAccount, 'bpi');
      });

      test('does not match number as account in transfer', () {
        final result = parser.parse('transfer 1000 bpi');
        expect(result!.isTransfer, isTrue);
        expect(result.parsed.account, 'bpi');
      });

      test('handles transfer with known accounts', () {
        final customParser = NLParser(knownAccounts: ['MyBank', 'MyWallet']);
        final result = customParser.parse('transfer 500 from MyBank to MyWallet');
        expect(result!.isTransfer, isTrue);
        expect(result.sourceAccount, 'MyBank');
        expect(result.destAccount, 'MyWallet');
      });
    });

    group('edge cases', () {
      test('returns null for empty input', () {
        expect(parser.parse(''), isNull);
      });

      test('returns null for whitespace-only input', () {
        expect(parser.parse('   '), isNull);
      });

      test('returns null for unparseable input', () {
        expect(parser.parse('hello world'), isNull);
      });

      test('computes confidence correctly', () {
        final result = parser.parse('mcdo 250 gcash');
        expect(result!.parsed.confidence, greaterThan(0));
        expect(result.parsed.confidence, lessThanOrEqualTo(1));
      });

      test('higher confidence with more fields', () {
        final result3 = parser.parse('mcdo 250 gcash');
        final result4 = parser.parse('jollibee delivery 100 cash food');
        expect(result4!.parsed.confidence, greaterThan(result3!.parsed.confidence));
      });

      test('handles text with extra whitespace', () {
        final result = parser.parse('  mcdo   250   gcash  ');
        expect(result!.parsed.payee, 'mcdo');
        expect(result.parsed.amount, 250);
        expect(result.parsed.account, 'gcash');
      });
    });

    group('combined scenarios', () {
      test('mcdo 250 gcash -> amount=250 payee=mcdo account=gcash expense', () {
        final result = parser.parse('mcdo 250 gcash');
        expect(result!.parsed.amount, 250);
        expect(result.parsed.payee, 'mcdo');
        expect(result.parsed.account, 'gcash');
        expect(result.parsed.direction, TransactionDirection.expense);
      });

      test('salary 50000 bank -> amount=50000 payee=salary account=bank income', () {
        final result = parser.parse('salary 50000 bank');
        expect(result!.parsed.amount, 50000);
        expect(result.parsed.payee, 'salary');
        expect(result.parsed.account, 'bank');
        expect(result.parsed.direction, TransactionDirection.income);
        expect(result.parsed.category, 'Income');
      });

      test('parses with payee, amount, account, and category', () {
        final result = parser.parse('jollibee delivery food 350 gcash');
        expect(result!.parsed.amount, 350);
        expect(result.parsed.payee, 'jollibee delivery');
        expect(result.parsed.account, 'gcash');
        expect(result.parsed.category, 'Food');
      });

      test('parses income with full context', () {
        final result = parser.parse('received freelnce payment 25000 gcash');
        expect(result!.parsed.direction, TransactionDirection.income);
        expect(result.parsed.amount, 25000);
        expect(result.parsed.account, 'gcash');
      });

      test('parses with known payee preferred', () {
        final customParser = NLParser(knownPayees: ['Jollibee Delivery']);
        final result = customParser.parse('jollibee delivery food 350 gcash');
        expect(result!.parsed.payee, 'Jollibee Delivery');
      });

      test('parses with payeeCategoryHistory', () {
        final customParser = NLParser(
          payeeCategoryHistory: {'starbucks': 'Dining'},
        );
        final result = customParser.parse('starbucks 150 gcash');
        expect(result!.parsed.payee, 'starbucks');
      });
    });
  });
}
