import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Enhanced network service with better resilience and timeout handling
class EnhancedNetworkService {
  static final EnhancedNetworkService _instance = EnhancedNetworkService._internal();
  factory EnhancedNetworkService() => _instance;
  EnhancedNetworkService._internal();

  // Network status tracking
  static bool _isConnected = true;
  static final List<VoidCallback> _connectionListeners = [];
  
  // Retry configuration
  static const int maxRetries = 3;
  static const Duration baseDelay = Duration(seconds: 1);
  static const Duration maxDelay = Duration(seconds: 30);
  
  /// Initialize network monitoring
  static Future<void> initialize() async {
    try {
      // Check initial connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      _isConnected = _isConnectivityResultConnected(connectivityResult.first);
      
      // Listen for connectivity changes
      Connectivity().onConnectivityChanged.listen((result) {
        final wasConnected = _isConnected;
        _isConnected = _isConnectivityResultConnected(result.first);
        
        // Notify listeners if connection status changed
        if (wasConnected != _isConnected) {
          _notifyConnectionListeners();
        }
      });
    } catch (e) {
      debugPrint('Error initializing network service: $e');
    }
  }
  
  /// Check if connectivity result indicates connected state
  static bool _isConnectivityResultConnected(ConnectivityResult result) {
    return result != ConnectivityResult.none;
  }
  
  /// Add connection status listener
  static void addConnectionListener(VoidCallback listener) {
    _connectionListeners.add(listener);
  }
  
  /// Remove connection status listener
  static void removeConnectionListener(VoidCallback listener) {
    _connectionListeners.remove(listener);
  }
  
  /// Notify all connection listeners
  static void _notifyConnectionListeners() {
    // Create a copy to avoid concurrent modification
    final listeners = List<VoidCallback>.from(_connectionListeners);
    for (final listener in listeners) {
      try {
        listener();
      } catch (e) {
        debugPrint('Error notifying connection listener: $e');
      }
    }
  }
  
  /// Check if device is currently connected to the internet
  static Future<bool> isConnected() async {
    try {
      // First check our internal state
      if (!_isConnected) return false;
      
      // Double-check with actual connectivity check
      final result = await Connectivity().checkConnectivity();
      _isConnected = _isConnectivityResultConnected(result.first);
      return _isConnected;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }
  
  /// Execute a network operation with enhanced resilience
  static Future<T> executeWithResilience<T>(
    Future<T> Function() operation, {
    Duration timeout = const Duration(seconds: 30),
    bool retryOnTimeout = true,
    bool retryOnNetworkError = true,
    void Function(int attempt, Object error)? onError,
  }) async {
    int attempt = 0;
    Object? lastError;
    
    while (attempt <= maxRetries) {
      try {
        // Check network connectivity before attempting
        if (!(await isConnected())) {
          throw const NetworkException('No internet connection');
        }
        
        // Execute operation with timeout
        return await operation().timeout(timeout);
        
      } on TimeoutException catch (e) {
        lastError = e;
        attempt++;
        
        // Call error callback
        onError?.call(attempt, e);
        
        // Don't retry if retryOnTimeout is false or we've reached max retries
        if (!retryOnTimeout || attempt > maxRetries) {
          throw NetworkException('Operation timed out after $attempt attempts: ${e.message}');
        }
        
        // Wait before retrying with exponential backoff
        await _delayWithJitter(attempt);
        
      } on NetworkException catch (e) {
        lastError = e;
        attempt++;
        
        // Call error callback
        onError?.call(attempt, e);
        
        // Don't retry if retryOnNetworkError is false or we've reached max retries
        if (!retryOnNetworkError || attempt > maxRetries) {
          throw e;
        }
        
        // Wait before retrying with exponential backoff
        await _delayWithJitter(attempt);
        
      } catch (e) {
        lastError = e;
        attempt++;
        
        // Call error callback
        onError?.call(attempt, e);
        
        // For other exceptions, don't retry
        throw NetworkException('Operation failed: $e');
      }
    }
    
    // If we get here, we've exhausted all retries
    throw NetworkException('Operation failed after $attempt attempts. Last error: $lastError');
  }
  
  /// Delay with exponential backoff and jitter
  static Future<void> _delayWithJitter(int attempt) async {
    // Calculate exponential backoff: baseDelay * 2^(attempt-1)
    final delaySeconds = min(
      baseDelay.inSeconds * pow(2, attempt - 1).toInt(),
      maxDelay.inSeconds,
    );
    
    // Add jitter: random delay between 0 and 50% of calculated delay
    final jitter = Random().nextInt((delaySeconds * 0.5).toInt() + 1);
    final totalDelay = Duration(seconds: delaySeconds + jitter);
    
    await Future.delayed(totalDelay);
  }
  
  /// Execute a batch of network operations with resilience
  static Future<List<T>> executeBatchWithResilience<T>(
    List<Future<T> Function()> operations, {
    Duration timeout = const Duration(seconds: 30),
    bool continueOnError = false,
  }) async {
    final results = <T>[];
    final errors = <Object>[];
    
    for (final operation in operations) {
      try {
        final result = await executeWithResilience(
          operation,
          timeout: timeout,
        );
        results.add(result);
      } catch (e) {
        errors.add(e);
        if (!continueOnError) {
          throw NetworkException('Batch operation failed: $e');
        }
      }
    }
    
    if (errors.isNotEmpty && !continueOnError) {
      throw NetworkException('Batch operations had ${errors.length} failures');
    }
    
    return results;
  }
  
  /// Get network status information
  static Future<Map<String, dynamic>> getNetworkStatus() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      return {
        'connected': _isConnectivityResultConnected(connectivityResult.first),
        'connectionType': connectivityResult.first.toString(),
        'lastChecked': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'connected': false,
        'connectionType': 'unknown',
        'lastChecked': DateTime.now().toIso8601String(),
        'error': e.toString(),
      };
    }
  }
}

/// Custom network exception with more detailed information
class NetworkException implements Exception {
  final String message;
  final String? code;
  final Object? underlyingError;
  
  const NetworkException(this.message, {this.code, this.underlyingError});
  
  @override
  String toString() {
    if (code != null) {
      return 'NetworkException($code): $message';
    }
    return 'NetworkException: $message';
  }
}

/// Enhanced timeout wrapper for individual operations
class EnhancedTimeout {
  /// Execute an operation with timeout and fallback
  static Future<T> withFallback<T>(
    Future<T> Function() primaryOperation,
    Future<T> Function() fallbackOperation, {
    Duration timeout = const Duration(seconds: 15),
    Duration fallbackTimeout = const Duration(seconds: 10),
  }) async {
    try {
      // Try primary operation with timeout
      return await primaryOperation().timeout(timeout);
    } on TimeoutException {
      debugPrint('Primary operation timed out, trying fallback');
      try {
        // Try fallback operation with its own timeout
        return await fallbackOperation().timeout(fallbackTimeout);
      } on TimeoutException {
        throw NetworkException('Both primary and fallback operations timed out');
      }
    }
  }
  
  /// Execute an operation with progressive timeout strategy
  static Future<T> withProgressiveTimeout<T>(
    Future<T> Function() operation, {
    List<Duration> timeouts = const [
      Duration(seconds: 5),
      Duration(seconds: 10),
      Duration(seconds: 15),
    ],
  }) async {
    Object? lastError;
    
    for (int i = 0; i < timeouts.length; i++) {
      try {
        return await operation().timeout(timeouts[i]);
      } on TimeoutException catch (e) {
        lastError = e;
        // If this is the last timeout, rethrow
        if (i == timeouts.length - 1) {
          throw NetworkException('Operation timed out after ${timeouts.length} attempts: ${e.message}');
        }
        // Otherwise, continue to next timeout
        debugPrint('Operation timed out with ${timeouts[i]}, trying longer timeout');
      }
    }
    
    // If we get here, rethrow the last error
    throw NetworkException('Operation failed: $lastError');
  }
}