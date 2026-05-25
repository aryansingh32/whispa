import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'hybrid_encryption_service.dart';
import 'websocket_service.dart';
import 'key_rotation_scheduler.dart';

/// 🚀 PRODUCTION-READY: Complete Backend Service
/// Integrates all services: Identity, Encryption, WebSocket, Messages
class BackendService {
  final String baseUrl;
  final bool useTor;
  
  late final Dio _dio;
  late final HybridEncryptionService _encryptionService;
  late final WebSocketService _webSocketService;
  late final KeyRotationScheduler _keyRotationScheduler;
  final _secureStorage = const FlutterSecureStorage();
  
  // State
  String? _anonymousCode;
  bool _isInitialized = false;
  bool _isConnected = false;
  
  // Callbacks
  Function(Map<String, dynamic>)? onMessageReceived;
  Function()? onConnected;
  Function()? onDisconnected;
  Function(String)? onError;
  Function(String sender, bool isTyping)? onTypingIndicator;
  
  BackendService({
    required this.baseUrl,
    this.useTor = false,
  }) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
    
    _encryptionService = HybridEncryptionService();
    _webSocketService = WebSocketService(baseUrl: baseUrl, useTor: useTor);
    _keyRotationScheduler = KeyRotationScheduler(
      encryptionService: _encryptionService,
      rotationInterval: const Duration(hours: 1),
    );
  }

  // ============ Initialization ============

  /// Initialize all services with progressive feedback
  Future<bool> initialize() async {
    try {
      print('🚀 Starting backend initialization...');
      
      // Step 1: Get or create anonymous identity
      _anonymousCode = await _getOrCreateIdentity();
      if (_anonymousCode == null) {
        throw Exception('Failed to get anonymous identity');
      }
      print('✅ Identity ready: $_anonymousCode');
      
      // Step 2: Setup encryption keys
      await _encryptionService.generateKeyPair();
      print('✅ Encryption keys ready');
      
      // Step 3: Connect WebSocket
      await _connectWebSocket();
      print('✅ WebSocket connected');
      
      // Step 4: Start key rotation
      _keyRotationScheduler.startAutoRotation();
      print('✅ Key rotation scheduler started');
      
      _isInitialized = true;
      return true;
      
    } catch (e) {
      print('❌ Backend initialization failed: $e');
      onError?.call('Initialization failed: $e');
      return false;
    }
  }

  /// Get existing or create new anonymous identity
  Future<String?> _getOrCreateIdentity() async {
    // Try to get existing identity
    final existingCode = await _secureStorage.read(key: 'anonymous_code');
    
    if (existingCode != null) {
      // Verify it's still valid
      try {
        final response = await _dio.get(
          '/api/identity/status',
          options: Options(headers: {'X-Anonymous-Code': existingCode}),
        );
        
        if (response.statusCode == 200) {
          return existingCode; // Valid existing identity
        }
      } catch (e) {
        print('⚠️ Existing identity invalid, creating new one');
      }
    }
    
    // Register new identity
    try {
      final response = await _dio.post('/api/identity/register');
      final newCode = response.data['anonymousCode'] as String;
      
      // Save to secure storage
      await _secureStorage.write(key: 'anonymous_code', value: newCode);
      
      return newCode;
    } catch (e) {
      print('❌ Identity registration failed: $e');
      return null;
    }
  }

  /// Connect WebSocket with callbacks
  Future<void> _connectWebSocket() async {
    if (_anonymousCode == null) {
      throw Exception('Cannot connect WebSocket without anonymous code');
    }
    
    // Setup callbacks
    _webSocketService.onMessageReceived = _handleIncomingMessage;
    _webSocketService.onConnected = () {
      _isConnected = true;
      onConnected?.call();
    };
    _webSocketService.onDisconnected = () {
      _isConnected = false;
      onDisconnected?.call();
    };
    _webSocketService.onError = (error) {
      onError?.call('WebSocket error: $error');
    };
    _webSocketService.onTypingIndicator = (sender, isTyping) {
      onTypingIndicator?.call(sender, isTyping);
    };
    
    // Connect
    await _webSocketService.connect(_anonymousCode!);
  }

  /// Handle incoming encrypted message
  Future<void> _handleIncomingMessage(Map<String, dynamic> messageData) async {
    try {
      print('📨 Received message from ${messageData['sender']}');
      
      // Decrypt message
      final decryptedContent = await _encryptionService.decryptMessage(messageData);
      
      // Add decrypted content to message data
      messageData['decryptedContent'] = decryptedContent;
      
      // Forward to app
      onMessageReceived?.call(messageData);
      
    } catch (e) {
      print('❌ Failed to decrypt message: $e');
      // Still forward with error indicator
      messageData['decryptedContent'] = '[Decryption Failed]';
      messageData['decryptionError'] = e.toString();
      onMessageReceived?.call(messageData);
    }
  }

  // ============ Messaging ============

  /// Send encrypted message to peer
  Future<void> sendMessage(String peerCode, String plainText) async {
    if (!_isInitialized) {
      throw Exception('Backend not initialized');
    }
    
    if (!_isConnected) {
      throw Exception('WebSocket not connected');
    }
    
    try {
      // Encrypt message using hybrid encryption
      final encryptedData = await _encryptionService.encryptMessage(
        plainText,
        peerCode,
      );
      
      // Send via WebSocket
      _webSocketService.sendMessage(
        receiver: peerCode,
        encryptedContent: encryptedData['encryptedContent'] as String,
        encryptedSessionKey: encryptedData['encryptedSessionKey'] as String?,
        sessionId: encryptedData['sessionId'] as String?,
      );
      
      print('✅ Message sent to $peerCode');
      
    } catch (e) {
      print('❌ Failed to send message: $e');
      rethrow;
    }
  }

  /// Send typing indicator
  void sendTypingIndicator(String peerCode, bool isTyping) {
    if (_isConnected) {
      _webSocketService.sendTypingIndicator(
        receiver: peerCode,
        isTyping: isTyping,
      );
    }
  }

  // ============ Key Exchange ============

  /// Get my public key for sharing
  Future<String?> getPublicKey() async {
    return await _encryptionService.getPublicKey();
  }

  /// Store peer's public key (after QR scan or manual exchange)
  Future<void> storePeerPublicKey(String peerCode, String publicKey) async {
    await _encryptionService.storePeerPublicKey(peerCode, publicKey);
  }

  /// Get peer's public key
  Future<String?> getPeerPublicKey(String peerCode) async {
    return await _encryptionService.getPeerPublicKey(peerCode);
  }

  /// Check if we have peer's public key
  Future<bool> hasPeerPublicKey(String peerCode) async {
    final key = await getPeerPublicKey(peerCode);
    return key != null;
  }

  // ============ Session Management ============

  /// Manually rotate session keys (for security)
  void rotateSessionKeys() {
    _keyRotationScheduler.rotateNow();
  }

  /// Emergency: Clear all session keys
  void emergencyClearKeys() {
    _keyRotationScheduler.emergencyClearAllKeys();
  }

  /// Check session status with backend
  Future<Map<String, dynamic>> getSessionStatus() async {
    if (_anonymousCode == null) {
      throw Exception('No anonymous code available');
    }
    
    try {
      final response = await _dio.get(
        '/api/identity/status',
        options: Options(headers: {'X-Anonymous-Code': _anonymousCode}),
      );
      return response.data;
    } catch (e) {
      throw Exception('Failed to get session status: $e');
    }
  }

  // ============ Logout & Cleanup ============

  /// Logout and cleanup all data
  Future<void> logout() async {
    try {
      // Revoke identity on backend
      if (_anonymousCode != null) {
        await _dio.post(
          '/api/identity/revoke',
          options: Options(headers: {'X-Anonymous-Code': _anonymousCode}),
        );
      }
    } catch (e) {
      print('⚠️ Backend revocation failed: $e');
    }
    
    // Cleanup local data
    await cleanup();
  }

  /// Cleanup without backend revocation
  Future<void> cleanup() async {
    // Stop key rotation
    _keyRotationScheduler.dispose();
    
    // Disconnect WebSocket
    _webSocketService.disconnect();
    
    // Clear all keys and storage
    await _encryptionService.deleteAllKeys();
    await _secureStorage.deleteAll();
    
    // Reset state
    _isInitialized = false;
    _isConnected = false;
    _anonymousCode = null;
    
    print('🗑️ Backend cleanup complete');
  }

  // ============ Getters ============

  String? get anonymousCode => _anonymousCode;
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get hasKeys => _encryptionService != null;
  
  /// Get connection status details
  Map<String, bool> get connectionStatus => {
    'initialized': _isInitialized,
    'websocket': _isConnected,
    'encryption': hasKeys,
    'tor': useTor, // TODO: Check actual Tor status
  };

  void dispose() {
    _keyRotationScheduler.dispose();
    _webSocketService.disconnect();
  }
}