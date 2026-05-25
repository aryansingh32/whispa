import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

/// ✅ FIXED: Hybrid Encryption Service with Better Error Handling
/// Handles both encrypted and unencrypted messages gracefully
class HybridEncryptionService {
  final _secureStorage = const FlutterSecureStorage();
  
  static const String _publicKeyStorageKey = 'rsa_public_key';
  static const String _privateKeyStorageKey = 'rsa_private_key';
  
  final Map<String, _SessionKey> _sessionKeys = {};
  final Duration sessionKeyLifetime = const Duration(hours: 1);

  /// Generate RSA key pair
  Future<void> generateKeyPair() async {
    print('🔐 Generating RSA key pair...');
    
    final existingPublicKey = await _secureStorage.read(key: _publicKeyStorageKey);
    if (existingPublicKey != null) {
      print('⚠️ Keys already exist');
      return;
    }
    
    final keyGen = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.parse('65537'), 2048, 64),
          _getSecureRandom(),
        ),
      );

    final pair = keyGen.generateKeyPair();
    final publicKey = pair.publicKey as RSAPublicKey;
    final privateKey = pair.privateKey as RSAPrivateKey;

    await _secureStorage.write(
      key: _publicKeyStorageKey,
      value: _encodePublicKey(publicKey),
    );
    await _secureStorage.write(
      key: _privateKeyStorageKey,
      value: _encodePrivateKey(privateKey),
    );
    
    print('✅ RSA key pair generated');
  }

  /// Get or create session key for a peer
  Future<_SessionKey> _getOrCreateSessionKey(String peerCode) async {
    if (_sessionKeys.containsKey(peerCode) && !_sessionKeys[peerCode]!.isExpired) {
      return _sessionKeys[peerCode]!;
    }

    final secureRandom = _getSecureRandom();
    final key = secureRandom.nextBytes(32);
    final iv = secureRandom.nextBytes(16);
    
    final sessionKey = _SessionKey(key, iv);
    _sessionKeys[peerCode] = sessionKey;
    
    print('🔑 Generated new session key for $peerCode');
    
    return sessionKey;
  }

  /// ✅ FIXED: Encrypt message with better error handling
  Future<Map<String, dynamic>> encryptMessage(String message, String peerCode) async {
    try {
      final sessionKey = await _getOrCreateSessionKey(peerCode);
      
      final isNewSession = _sessionKeys[peerCode] == sessionKey && 
                          DateTime.now().difference(sessionKey.created).inSeconds < 5;
      
      final key = encrypt.Key(sessionKey.key);
      final iv = encrypt.IV(sessionKey.iv);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );

      final encrypted = encrypter.encrypt(message, iv: iv);
      
      String? encryptedSessionKey;
      if (isNewSession) {
        final peerPublicKey = await getPeerPublicKey(peerCode);
        if (peerPublicKey != null) {
          encryptedSessionKey = await _encryptSessionKey(
            sessionKey.key,
            sessionKey.iv,
            peerPublicKey,
          );
        }
      }

      return {
        'encryptedContent': encrypted.base64,
        'encryptedSessionKey': encryptedSessionKey,
        'sessionId': _generateSessionId(sessionKey),
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      print('❌ Encryption failed: $e');
      rethrow;
    }
  }

  /// ✅ FIXED: Decrypt message with fallback for unencrypted content
  Future<String> decryptMessage(Map<String, dynamic> encryptedData) async {
    try {
      // Check if this is an unencrypted message (from web interface)
      if (!encryptedData.containsKey('encryptedContent')) {
        print('⚠️ Received unencrypted message, using plain content');
        return encryptedData['content']?.toString() ?? '[Empty Message]';
      }

      final encryptedContent = encryptedData['encryptedContent'];
      
      // Handle both String and dynamic types
      final encryptedContentStr = encryptedContent is String 
          ? encryptedContent 
          : encryptedContent.toString();
      
      final encryptedSessionKey = encryptedData['encryptedSessionKey'];
      final sessionId = encryptedData['sessionId'];
      final sender = encryptedData['sender'];

      _SessionKey sessionKey;

      // If new session key is provided, decrypt it
      if (encryptedSessionKey != null && encryptedSessionKey is String) {
        try {
          sessionKey = await _decryptSessionKey(encryptedSessionKey);
          print('🔑 Received new session key');
          
          if (sender != null && sender is String) {
            _sessionKeys[sender] = sessionKey;
          }
        } catch (e) {
          print('⚠️ Failed to decrypt session key: $e');
          // Try to find existing session key
          sessionKey = _findSessionKeyByIdOrSender(sessionId, sender);
        }
      } else {
        // Use existing session key
        sessionKey = _findSessionKeyByIdOrSender(sessionId, sender);
      }

      // Decrypt message with AES
      final key = encrypt.Key(sessionKey.key);
      final iv = encrypt.IV(sessionKey.iv);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );

      final decrypted = encrypter.decrypt64(encryptedContentStr, iv: iv);
      
      return decrypted;
      
    } catch (e) {
      print('❌ Decryption failed: $e');
      print('📋 Message data: ${encryptedData.toString().substring(0, 100)}...');
      
      // Return a user-friendly error message
      return '[⚠️ Could not decrypt message - key exchange may be needed]';
    }
  }

  /// ✅ NEW: Find session key by ID or sender (more flexible)
  _SessionKey _findSessionKeyByIdOrSender(dynamic sessionId, dynamic sender) {
    // Try to find by session ID first
    if (sessionId != null && sessionId is String) {
      for (var entry in _sessionKeys.entries) {
        if (_generateSessionId(entry.value) == sessionId) {
          return entry.value;
        }
      }
    }
    
    // Try to find by sender
    if (sender != null && sender is String && _sessionKeys.containsKey(sender)) {
      print('🔍 Found session key by sender: $sender');
      return _sessionKeys[sender]!;
    }
    
    throw Exception('Session key not found - please exchange keys first');
  }

  /// Encrypt session key with RSA
  Future<String> _encryptSessionKey(
    Uint8List key,
    Uint8List iv,
    String recipientPublicKeyStr,
  ) async {
    final publicKey = _decodePublicKey(recipientPublicKeyStr);
    final cipher = OAEPEncoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

    final combined = Uint8List.fromList([...key, ...iv]);
    final encrypted = cipher.process(combined);
    
    return base64Encode(encrypted);
  }

  /// Decrypt session key with RSA
  Future<_SessionKey> _decryptSessionKey(String encryptedSessionKey) async {
    final privateKeyStr = await _secureStorage.read(key: _privateKeyStorageKey);
    if (privateKeyStr == null) throw Exception('Private key not found');

    final privateKey = _decodePrivateKey(privateKeyStr);
    final cipher = OAEPEncoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

    final encryptedBytes = base64Decode(encryptedSessionKey);
    final decrypted = cipher.process(encryptedBytes);
    
    final key = Uint8List.fromList(decrypted.sublist(0, 32));
    final iv = Uint8List.fromList(decrypted.sublist(32, 48));
    
    return _SessionKey(key, iv);
  }

  /// Generate session ID
  String _generateSessionId(_SessionKey sessionKey) {
    final hash = sha256.convert([...sessionKey.key, ...sessionKey.iv]);
    return hash.toString().substring(0, 16);
  }

  /// Rotate session keys
  void rotateSessionKeys() {
    final now = DateTime.now();
    _sessionKeys.removeWhere((key, value) {
      if (value.isExpired) {
        print('🔄 Rotated session key for $key');
        return true;
      }
      return false;
    });
  }

  /// Clear all session keys
  void clearSessionKeys() {
    _sessionKeys.clear();
    print('🗑️ All session keys cleared');
  }

  // ============ Public Key Management ============

  Future<String?> getPublicKey() async {
    return await _secureStorage.read(key: _publicKeyStorageKey);
  }

  Future<void> storePeerPublicKey(String peerCode, String publicKey) async {
    await _secureStorage.write(
      key: 'peer_public_key_$peerCode',
      value: publicKey,
    );
    print('✅ Stored public key for peer: $peerCode');
  }

  Future<String?> getPeerPublicKey(String peerCode) async {
    return await _secureStorage.read(key: 'peer_public_key_$peerCode');
  }

  Future<bool> hasKeys() async {
    final publicKey = await _secureStorage.read(key: _publicKeyStorageKey);
    return publicKey != null;
  }

  Future<void> deleteAllKeys() async {
    await _secureStorage.deleteAll();
    _sessionKeys.clear();
    print('🗑️ All keys deleted');
  }

  // ============ Helper Methods ============

  SecureRandom _getSecureRandom() {
    final secureRandom = SecureRandom('Fortuna');
    final random = Random.secure();
    final seeds = List<int>.generate(32, (_) => random.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  String _encodePublicKey(RSAPublicKey key) {
    return json.encode({
      'modulus': key.modulus.toString(),
      'exponent': key.exponent.toString(),
    });
  }

  String _encodePrivateKey(RSAPrivateKey key) {
    return json.encode({
      'modulus': key.modulus.toString(),
      'privateExponent': key.privateExponent.toString(),
      'p': key.p.toString(),
      'q': key.q.toString(),
    });
  }

  RSAPublicKey _decodePublicKey(String encoded) {
    final data = json.decode(encoded);
    return RSAPublicKey(
      BigInt.parse(data['modulus']),
      BigInt.parse(data['exponent']),
    );
  }

  RSAPrivateKey _decodePrivateKey(String encoded) {
    final data = json.decode(encoded);
    return RSAPrivateKey(
      BigInt.parse(data['modulus']),
      BigInt.parse(data['privateExponent']),
      BigInt.parse(data['p']),
      BigInt.parse(data['q']),
    );
  }
}

/// Session key structure
class _SessionKey {
  final Uint8List key;
  final Uint8List iv;
  final DateTime created;
  
  _SessionKey(this.key, this.iv) : created = DateTime.now();
  
  bool get isExpired => DateTime.now().difference(created) > const Duration(hours: 1);
}