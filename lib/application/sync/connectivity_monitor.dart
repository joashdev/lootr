import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityMonitor {
  final Connectivity _connectivity;

  ConnectivityMonitor({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  Stream<bool> get onlineStream {
    return _connectivity.onConnectivityChanged.map((results) {
      if (results.isEmpty) return false;
      return results.any((result) => result != ConnectivityResult.none);
    });
  }

  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    if (results.isEmpty) return false;
    return results.any((result) => result != ConnectivityResult.none);
  }
}
