import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/domain/value_objects/sync_health.dart';

void main() {
  group('SyncHealth', () {
    test('should construct with defaults', () {
      const health = SyncHealth();
      expect(health.lastSyncedAt, isNull);
      expect(health.pendingCount, 0);
      expect(health.failedCount, 0);
      expect(health.lastStatus, 'healthy');
    });

    test('should construct with values', () {
      final now = DateTime.now();
      final health = SyncHealth(
        lastSyncedAt: now,
        pendingCount: 5,
        failedCount: 2,
        lastStatus: 'warning',
      );

      expect(health.lastSyncedAt, now);
      expect(health.pendingCount, 5);
      expect(health.failedCount, 2);
      expect(health.lastStatus, 'warning');
    });

    test('isHealthy should return true when status is healthy', () {
      const health = SyncHealth(lastStatus: 'healthy');
      expect(health.isHealthy, isTrue);
    });

    test('isHealthy should return false when status is not healthy', () {
      const health = SyncHealth(lastStatus: 'warning');
      expect(health.isHealthy, isFalse);
    });

    test('hasPending should return true when pendingCount > 0', () {
      const health = SyncHealth(pendingCount: 3);
      expect(health.hasPending, isTrue);
    });

    test('hasPending should return false when pendingCount is 0', () {
      const health = SyncHealth(pendingCount: 0);
      expect(health.hasPending, isFalse);
    });

    test('hasFailed should return true when failedCount > 0', () {
      const health = SyncHealth(failedCount: 1);
      expect(health.hasFailed, isTrue);
    });

    test('hasFailed should return false when failedCount is 0', () {
      const health = SyncHealth(failedCount: 0);
      expect(health.hasFailed, isFalse);
    });

    test('should be equatable', () {
      const a = SyncHealth(pendingCount: 3, failedCount: 1, lastStatus: 'warning');
      const b = SyncHealth(pendingCount: 3, failedCount: 1, lastStatus: 'warning');
      expect(a, equals(b));
    });

    test('should not equal different values', () {
      const a = SyncHealth(pendingCount: 3);
      const b = SyncHealth(pendingCount: 5);
      expect(a, isNot(equals(b)));
    });
  });
}
