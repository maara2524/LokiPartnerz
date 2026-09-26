import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class NetworkUtils {
  static const String connectionProblemMessage =
      'Unable to connect. Please check your internet connection and try again.';
  static const String timeoutMessage =
      'Connection timed out. Please check your internet connection and try again.';

  static final Connectivity _connectivity = Connectivity();

  // Checks whether the device currently has a network interface available.
  static Future<bool> hasInternetConnection() async {
    final result = await _connectivity.checkConnectivity();
    return _isConnected(result);
  }

  // Subscribe to connectivity changes
  static Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(_isConnected);
  }

  // Helper: true if any result is not none (connectivity_plus returns List)
  static bool _isConnected(ConnectivityResult result) {
    return result != ConnectivityResult.none;
  }

  // Check connectivity and throw exception if offline
  static Future<void> checkConnectivity() async {
    final hasConnection = await hasInternetConnection();
    if (!hasConnection) {
      throw NetworkException(
        'No internet connection. Please check your connection and try again.',
      );
    }
  }

  static bool isConnectionError(Object error) {
    if (error is NetworkException ||
        error is TimeoutException ||
        error is http.ClientException) {
      return true;
    }

    final message = error.toString().toLowerCase();
    return message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('connection failed') ||
        message.contains('connection refused') ||
        message.contains('connection reset') ||
        message.contains('network is unreachable');
  }

  static String friendlyMessageFor(Object error) {
    if (error is NetworkException) {
      return error.message;
    }
    if (error is TimeoutException) {
      return timeoutMessage;
    }
    if (isConnectionError(error)) {
      return connectionProblemMessage;
    }

    return 'Something went wrong. Please try again.';
  }
}

class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}
