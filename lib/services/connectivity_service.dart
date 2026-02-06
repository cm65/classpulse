import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for connectivity status
final connectivityProvider = StreamProvider<ConnectivityStatus>((ref) {
  return ref.watch(connectivityServiceProvider).statusStream;
});

/// Provider for connectivity service
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService();
});

enum ConnectivityStatus {
  online,
  offline;

  bool get isOnline => this == ConnectivityStatus.online;
  bool get isOffline => this == ConnectivityStatus.offline;
}

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectivityStatus> _statusController =
      StreamController<ConnectivityStatus>.broadcast();

  ConnectivityStatus _currentStatus = ConnectivityStatus.online;
  DateTime? _lastOnlineAt;

  ConnectivityService() {
    _init();
  }

  void _init() {
    // Check initial connectivity
    _checkConnectivity();

    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  Future<void> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    final hasConnection = results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);

    final newStatus =
        hasConnection ? ConnectivityStatus.online : ConnectivityStatus.offline;

    if (newStatus != _currentStatus) {
      // Track when we go offline
      if (_currentStatus.isOnline && newStatus.isOffline) {
        _lastOnlineAt = DateTime.now();
      }
      // Clear last online time when back online
      if (newStatus.isOnline) {
        _lastOnlineAt = null;
      }
      _currentStatus = newStatus;
      _statusController.add(newStatus);
    }
  }

  /// Current connectivity status
  ConnectivityStatus get currentStatus => _currentStatus;

  /// Stream of connectivity status changes
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  /// When we were last online (only set when offline)
  DateTime? get lastOnlineAt => _lastOnlineAt;

  /// Check if currently online
  bool get isOnline => _currentStatus.isOnline;

  /// Check if currently offline
  bool get isOffline => _currentStatus.isOffline;

  /// Manually refresh connectivity status
  Future<void> refresh() => _checkConnectivity();

  void dispose() {
    _statusController.close();
  }
}
