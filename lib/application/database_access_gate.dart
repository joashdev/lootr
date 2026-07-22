import 'dart:async';
import 'dart:collection';

/// Coordinates long-running database users with file-level maintenance.
///
/// Shared access is intentionally non-waiting: once exclusive maintenance is
/// active or queued, new background work should return and let its normal
/// trigger retry later. Exclusive access waits for every admitted shared user
/// to finish before it starts.
final class DatabaseAccessGate {
  final Queue<Completer<DatabaseAccessLease>> _exclusiveWaiters = Queue();
  var _sharedHolders = 0;
  var _exclusiveHeld = false;

  bool get isExclusivePendingOrHeld =>
      _exclusiveHeld || _exclusiveWaiters.isNotEmpty;

  DatabaseAccessLease? tryAcquireShared() {
    if (isExclusivePendingOrHeld) return null;
    _sharedHolders++;
    return DatabaseAccessLease._(_releaseShared);
  }

  Future<DatabaseAccessLease> acquireExclusive() {
    if (!_exclusiveHeld && _sharedHolders == 0) {
      _exclusiveHeld = true;
      return Future.value(DatabaseAccessLease._(_releaseExclusive));
    }

    final waiter = Completer<DatabaseAccessLease>();
    _exclusiveWaiters.add(waiter);
    return waiter.future;
  }

  void _releaseShared() {
    if (_sharedHolders == 0) {
      throw StateError('No shared database access is held.');
    }
    _sharedHolders--;
    if (_sharedHolders == 0) _grantNextExclusive();
  }

  void _releaseExclusive() {
    if (!_exclusiveHeld) {
      throw StateError('No exclusive database access is held.');
    }
    _exclusiveHeld = false;
    _grantNextExclusive();
  }

  void _grantNextExclusive() {
    if (_exclusiveHeld || _sharedHolders != 0 || _exclusiveWaiters.isEmpty) {
      return;
    }
    _exclusiveHeld = true;
    _exclusiveWaiters.removeFirst().complete(
      DatabaseAccessLease._(_releaseExclusive),
    );
  }
}

final class DatabaseAccessLease {
  DatabaseAccessLease._(this._release);

  final void Function() _release;
  var _released = false;

  void release() {
    if (_released) return;
    _released = true;
    _release();
  }
}
