import 'dart:async';

import 'connectivity_monitor.dart';
import 'sync_manager.dart';

class SyncTriggers {
  final SyncManager _syncManager;
  final ConnectivityMonitor _connectivityMonitor;

  Timer? _periodicTimer;
  Timer? _postMutationTimer;
  Timer? _connectivityTimer;
  DateTime? _lastSyncTime;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _disposed = false;

  SyncTriggers({
    required SyncManager syncManager,
    required ConnectivityMonitor connectivityMonitor,
  })  : _syncManager = syncManager,
        _connectivityMonitor = connectivityMonitor;

  void start({bool enablePeriodic = false}) {
    if (_disposed) return;

    if (enablePeriodic) {
      _startPeriodic();
    }

    _connectivitySubscription = _connectivityMonitor.onlineStream.listen((online) {
      if (online && !_disposed) {
        _connectivityTimer?.cancel();
        _connectivityTimer = Timer(const Duration(seconds: 5), () {
          if (!_disposed) {
            _syncManager.sync();
          }
        });
      }
    });

    _syncManager.onSyncComplete.listen((_) {
      _lastSyncTime = DateTime.now();
    });
  }

  void onAppResumed() {
    if (_disposed) return;

    final shouldSync = _lastSyncTime == null ||
        DateTime.now().difference(_lastSyncTime!) > const Duration(minutes: 5);

    if (shouldSync) {
      _syncManager.sync();
    }
  }

  void onPullToRefresh() {
    if (_disposed) return;
    _syncManager.sync();
  }

  void onPostMutation() {
    if (_disposed) return;

    _postMutationTimer?.cancel();
    _postMutationTimer = Timer(const Duration(seconds: 30), () {
      if (!_disposed) {
        _syncManager.sync();
      }
    });
  }

  void _startPeriodic() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!_disposed) {
        _syncManager.sync();
      }
    });
  }

  void updateLastSyncTime(DateTime time) {
    _lastSyncTime = time;
  }

  void dispose() {
    _disposed = true;
    _periodicTimer?.cancel();
    _postMutationTimer?.cancel();
    _connectivityTimer?.cancel();
    _connectivitySubscription?.cancel();
  }
}
