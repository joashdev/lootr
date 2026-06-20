import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/sync/conflict_applier.dart';

void main() {
  late ConflictApplier applier;

  setUp(() {
    applier = ConflictApplier();
  });

  group('ConflictApplier', () {
    group('serverWins', () {
      test('returns true when local is null (no local record)', () {
        expect(
          applier.serverWins(DateTime(2026, 6, 20), null),
          isTrue,
        );
      });

      test('returns true when server is newer', () {
        expect(
          applier.serverWins(
            DateTime(2026, 6, 20, 12),
            DateTime(2026, 6, 20, 10),
          ),
          isTrue,
        );
      });

      test('returns true when timestamps are equal (server wins ties)', () {
        final t = DateTime(2026, 6, 20, 12);
        expect(applier.serverWins(t, t), isTrue);
      });

      test('returns false when local is newer', () {
        expect(
          applier.serverWins(
            DateTime(2026, 6, 20, 10),
            DateTime(2026, 6, 20, 12),
          ),
          isFalse,
        );
      });
    });


  });
}
