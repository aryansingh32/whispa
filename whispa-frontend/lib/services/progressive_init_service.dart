import 'package:dio/dio.dart';
import 'dart:async';

/// ✅ FIXED: Progressive Initialization Service
/// Non-blocking startup with fallback options and retry logic
/// Allows app to function even if some services fail
class ProgressiveInitService {
  final String baseUrl;
  final bool useTor;
  final Dio _dio;

  // Initialization state
  bool _torAvailable = false;
  bool _identityReady = false;
  bool _keysReady = false;
  bool _websocketReady = false;

  // Callbacks for progressive updates
  Function(String step, bool success, String? message)? onStepComplete;
  Function(double progress)? onProgress;

  ProgressiveInitService({
    required this.baseUrl,
    this.useTor = false,
  }) : _dio = Dio(BaseOptions(baseUrl: baseUrl));

  /// ✅ Initialize with progressive feedback and fallback
  /// Returns true if minimum requirements met (identity + keys)
  Future<bool> initialize() async {
    final steps = <Future<void> Function()>[
      _initTor,
      _initIdentity,
      _initEncryption,
      _initWebSocket,
    ];

    int completedSteps = 0;
    final totalSteps = steps.length;

    try {
      for (final step in steps) {
        try {
          await step();
          completedSteps++;
          onProgress?.call(completedSteps / totalSteps);
        } catch (e) {
          print('⚠️ Step failed: $e');
          // Continue to next step instead of failing completely
          completedSteps++;
          onProgress?.call(completedSteps / totalSteps);
        }
      }

      // Check if minimum requirements are met
      final canOperate = _identityReady && _keysReady;
      
      if (canOperate) {
        print('✅ App can operate (${_getReadyServicesCount()}/4 services ready)');
        return true;
      } else {
        print('❌ Critical services failed');
        return false;
      }
    } catch (e) {
      print('❌ Initialization failed: $e');
      return false;
    }
  }

  /// Step 1: Initialize Tor (optional, non-blocking)
  /// ✅ If Tor fails, app continues with direct connection
  Future<void> _initTor() async {
    if (!useTor) {
      onStepComplete?.call('Tor', true, 'Skipped (disabled)');
      return;
    }

    print('🔒 Step 1/4: Checking Tor availability...');
    
    try {
      // Quick check if Tor proxy is available (timeout: 3 seconds)
      final available = await _checkTorAvailability().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );

      _torAvailable = available;

      if (_torAvailable) {
        print('✅ Tor available');
        onStepComplete?.call('Tor', true, 'Connected via Tor');
      } else {
        print('⚠️ Tor unavailable, using direct connection');
        onStepComplete?.call('Tor', false, 'Using direct connection');
      }
    } catch (e) {
      print('⚠️ Tor check failed: $e');
      _torAvailable = false;
      onStepComplete?.call('Tor', false, 'Failed, using direct');
    }
  }

  /// Step 2: Initialize Identity (critical)
  /// ✅ Retries up to 3 times with exponential backoff
  Future<void> _initIdentity() async {
    print('🆔 Step 2/4: Getting anonymous identity...');

    try {
      // Try to get existing identity first (fast)
      final existingId = await _getStoredIdentity();
      
      if (existingId != null) {
        // Verify it's still valid (with timeout)
        final valid = await _verifyIdentity(existingId).timeout(
          const Duration(seconds: 5),
          onTimeout: () => false,
        );

        if (valid) {
          _identityReady = true;
          print('✅ Using existing identity');
          onStepComplete?.call('Identity', true, 'Identity verified');
          return;
        }
      }

      // Need to register new identity (with retries)
      await _registerWithRetry();
      _identityReady = true;
      print('✅ Identity created');
      onStepComplete?.call('Identity', true, 'New identity created');
      
    } catch (e) {
      print('❌ Identity initialization failed: $e');
      _identityReady = false;
      onStepComplete?.call('Identity', false, 'Failed to get identity');
      rethrow; // Critical failure
    }
  }

  /// Step 3: Initialize Encryption (critical)
  /// ✅ Fast local operation, no network required
  Future<void> _initEncryption() async {
    print('🔐 Step 3/4: Setting up encryption...');

    try {
      // Check if keys exist (instant)
      final hasKeys = await _checkKeysExist();

      if (!hasKeys) {
        // Generate keys (takes ~1 second)
        await _generateKeys();
      }

      _keysReady = true;
      print('✅ Encryption ready');
      onStepComplete?.call('Encryption', true, 'E2EE enabled');
      
    } catch (e) {
      print('❌ Encryption initialization failed: $e');
      _keysReady = false;
      onStepComplete?.call('Encryption', false, 'E2EE unavailable');
      rethrow; // Critical failure
    }
  }

  /// Step 4: Initialize WebSocket (non-critical)
  /// ✅ If WebSocket fails, can retry later without blocking app
  Future<void> _initWebSocket() async {
    print('🔌 Step 4/4: Connecting WebSocket...');

    try {
      // Attempt WebSocket connection with timeout
      await _connectWebSocket().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('WebSocket timeout'),
      );

      _websocketReady = true;
      print('✅ WebSocket connected');
      onStepComplete?.call('WebSocket', true, 'Real-time enabled');
      
    } catch (e) {
      print('⚠️ WebSocket connection failed: $e');
      _websocketReady = false;
      onStepComplete?.call('WebSocket', false, 'Will retry in background');
      // Don't rethrow - app can work without immediate WebSocket
    }
  }

  /// ✅ Retry identity registration with exponential backoff
  Future<void> _registerWithRetry({int maxRetries = 3}) async {
    int attempt = 0;
    Duration delay = const Duration(seconds: 1);

    while (attempt < maxRetries) {
      try {
        await _dio.post('/api/identity/register');
        return; // Success
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;
        
        print('⚠️ Registration attempt $attempt failed, retrying in ${delay.inSeconds}s...');
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      }
    }
  }

  /// ✅ Retry WebSocket connection in background (non-blocking)
  Future<void> retryWebSocketInBackground() async {
    if (_websocketReady) return;

    print('🔄 Retrying WebSocket connection in background...');
    
    // Try every 10 seconds, max 5 times
    for (int i = 0; i < 5; i++) {
      await Future.delayed(const Duration(seconds: 10));
      
      try {
        await _connectWebSocket().timeout(const Duration(seconds: 5));
        _websocketReady = true;
        print('✅ WebSocket connected on retry ${i + 1}');
        onStepComplete?.call('WebSocket', true, 'Connected');
        return;
      } catch (e) {
        print('⚠️ Retry ${i + 1}/5 failed');
      }
    }
    
    print('❌ WebSocket reconnection failed after 5 attempts');
  }

  // ============ Helper Methods ============

  Future<bool> _checkTorAvailability() async {
    // Implementation depends on your TorService
    return false; // Placeholder
  }

  Future<String?> _getStoredIdentity() async {
    // Implementation depends on your IdentityService
    return null; // Placeholder
  }

  Future<bool> _verifyIdentity(String id) async {
    try {
      final response = await _dio.get('/api/identity/status',
        options: Options(headers: {'X-Anonymous-Code': id}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkKeysExist() async {
    // Implementation depends on your EncryptionService
    return false; // Placeholder
  }

  Future<void> _generateKeys() async {
    // Implementation depends on your EncryptionService
  }

  Future<void> _connectWebSocket() async {
    // Implementation depends on your WebSocketService
  }

  int _getReadyServicesCount() {
    int count = 0;
    if (_torAvailable) count++;
    if (_identityReady) count++;
    if (_keysReady) count++;
    if (_websocketReady) count++;
    return count;
  }

  // ============ Getters ============

  bool get isTorReady => _torAvailable;
  bool get isIdentityReady => _identityReady;
  bool get isEncryptionReady => _keysReady;
  bool get isWebSocketReady => _websocketReady;
  
  /// App can operate if identity and encryption are ready
  bool get canOperate => _identityReady && _keysReady;
  
  /// Get initialization status summary
  Map<String, bool> get status => {
    'tor': _torAvailable,
    'identity': _identityReady,
    'encryption': _keysReady,
    'websocket': _websocketReady,
  };
}
