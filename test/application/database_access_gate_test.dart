import 'package:flutter_test/flutter_test.dart';
import 'package:lootr/application/database_access_gate.dart';

void main() {
  test('exclusive access drains readers and rejects new shared work', () async {
    final gate = DatabaseAccessGate();
    final activeQuery = gate.tryAcquireShared();
    expect(activeQuery, isNotNull);

    var maintenanceStarted = false;
    final maintenance = gate.acquireExclusive().then((lease) {
      maintenanceStarted = true;
      return lease;
    });
    await Future<void>.delayed(Duration.zero);

    expect(maintenanceStarted, isFalse);
    expect(gate.tryAcquireShared(), isNull);

    activeQuery!.release();
    final maintenanceLease = await maintenance;
    expect(maintenanceStarted, isTrue);
    expect(gate.tryAcquireShared(), isNull);

    maintenanceLease.release();
    final nextQuery = gate.tryAcquireShared();
    expect(nextQuery, isNotNull);
    nextQuery!.release();
  });
}
