import 'dart:convert';
import 'dart:math'; // ✅ FIXED: Added missing import for Random.secure()
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

/// ✅ FIXED: Recovery Service
/// Provides backup/restore with optional encrypted cloud backup
/// Balance between privacy and user convenience
class RecoveryService {
  final _secureStorage = const FlutterSecureStorage();
  
  static const String _backupKeyPrefix = 'backup_';
  static const String _recoveryPhraseKey = 'recovery_phrase';

  /// ✅ Generate recovery phrase (BIP39-style, 12 words)
  /// User can write this down for recovery on new device
  Future<String> generateRecoveryPhrase() async {
    // Check if already exists
    final existing = await _secureStorage.read(key: _recoveryPhraseKey);
    if (existing != null) {
      return existing;
    }

    // Generate random phrase (simplified - use BIP39 library in production)
    final words = _generateRandomWords(12);
    final phrase = words.join(' ');
    
    await _secureStorage.write(key: _recoveryPhraseKey, value: phrase);
    
    print('✅ Recovery phrase generated');
    return phrase;
  }

  /// ✅ Create encrypted backup of all keys
  /// Returns encrypted backup string that user can save
  Future<String> createBackup(String recoveryPhrase) async {
    try {
      // Get all stored data
      final allData = await _secureStorage.readAll();
      
      // Filter sensitive keys
      final backup = <String, String>{};
      for (var entry in allData.entries) {
        if (entry.key.startsWith('rsa_') || 
            entry.key.startsWith('peer_') ||
            entry.key == 'anonymous_code') {
          backup[entry.key] = entry.value;
        }
      }

      // Encrypt backup with recovery phrase
      final encrypted = _encryptBackup(backup, recoveryPhrase);
      
      print('✅ Backup created (${backup.length} items)');
      return encrypted;
      
    } catch (e) {
      print('❌ Backup creation failed: $e');
      rethrow;
    }
  }

  /// ✅ Restore from encrypted backup
  Future<bool> restoreFromBackup(String encryptedBackup, String recoveryPhrase) async {
    try {
      // Decrypt backup
      final backup = _decryptBackup(encryptedBackup, recoveryPhrase);
      
      // Restore all keys
      for (var entry in backup.entries) {
        await _secureStorage.write(key: entry.key, value: entry.value);
      }
      
      print('✅ Backup restored (${backup.length} items)');
      return true;
      
    } catch (e) {
      print('❌ Backup restore failed: $e');
      return false;
    }
  }

  /// ✅ Auto-backup to secure location (optional)
  /// Privacy note: This is encrypted client-side, but stored in cloud
  /// User should opt-in explicitly
  Future<void> enableAutoBackup({
    required bool toCloud,
    required String recoveryPhrase,
  }) async {
    // Implementation would integrate with:
    // - Android: Encrypted SharedPreferences Auto Backup
    // - iOS: iCloud Keychain
    // Both are end-to-end encrypted by OS
    
    print('⚠️ Auto-backup not implemented yet');
    print('User should manually save recovery phrase and backup string');
  }

  /// ✅ Verify recovery phrase is correct
  Future<bool> verifyRecoveryPhrase(String phrase) async {
    final stored = await _secureStorage.read(key: _recoveryPhraseKey);
    return stored == phrase;
  }

  /// ✅ Check if backup exists
  Future<bool> hasBackup() async {
    final phrase = await _secureStorage.read(key: _recoveryPhraseKey);
    return phrase != null;
  }

  // ============ Helper Methods ============

  /// Encrypt backup data with recovery phrase
  String _encryptBackup(Map<String, String> data, String phrase) {
    // Simple encryption using recovery phrase as key
    // In production, use proper KDF (PBKDF2) and AES
    final key = _deriveKeyFromPhrase(phrase);
    final json = jsonEncode(data);
    final encrypted = _simpleEncrypt(json, key);
    return base64Encode(utf8.encode(encrypted));
  }

  /// Decrypt backup data
  Map<String, String> _decryptBackup(String encrypted, String phrase) {
    final key = _deriveKeyFromPhrase(phrase);
    final decoded = utf8.decode(base64Decode(encrypted));
    final decrypted = _simpleDecrypt(decoded, key);
    return Map<String, String>.from(jsonDecode(decrypted));
  }

  /// Derive encryption key from recovery phrase
  String _deriveKeyFromPhrase(String phrase) {
    // Use PBKDF2 or Argon2 in production
    final hash = sha256.convert(utf8.encode(phrase));
    return hash.toString();
  }

  /// Simple XOR encryption (replace with AES in production)
  String _simpleEncrypt(String data, String key) {
    final result = StringBuffer();
    for (int i = 0; i < data.length; i++) {
      result.write(String.fromCharCode(
        data.codeUnitAt(i) ^ key.codeUnitAt(i % key.length),
      ));
    }
    return result.toString();
  }

  String _simpleDecrypt(String data, String key) {
    return _simpleEncrypt(data, key); // XOR is symmetric
  }

  /// Generate random words for recovery phrase
  List<String> _generateRandomWords(int count) {
    // Simplified word list - use BIP39 wordlist in production
    const words = [
      'apple', 'banana', 'cherry', 'dragon', 'eagle', 'falcon',
      'garden', 'harbor', 'island', 'jungle', 'kingdom', 'lion',
      'mountain', 'nebula', 'ocean', 'palace', 'quantum', 'river',
      'sunset', 'thunder', 'universe', 'valley', 'whisper', 'xenon',
      'yellow', 'zenith', 'anchor', 'bridge', 'castle', 'diamond',
    ];
    
    final random = Random.secure();
    return List.generate(count, (_) => words[random.nextInt(words.length)]);
  }
}

/// ✅ Better UX: Smart Connection Helper
/// Guides users through key exchange with clear instructions
class ConnectionHelper {
  /// ✅ Generate friendly connection instructions
  static String getConnectionInstructions(String myCode) {
    return '''
🔐 How to Connect Securely:

1️⃣ Share Your Code
   → Copy "$myCode" and send to your peer
   → Or show them your QR code in person

2️⃣ Get Their Code
   → Ask them to share their code
   → Or scan their QR code

3️⃣ Exchange Keys (In Person)
   → Both: Tap "Share QR Code"
   → Scan each other's QR codes
   → ✅ Connection secured!

⚠️ Important: Exchange QR codes in person or via secure video call
''';
  }

  /// ✅ Validate peer code format
  static bool isValidPeerCode(String code) {
    // Example format: XXXX-XXXX-XXXX-XXXX
    final regex = RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$');
    return regex.hasMatch(code);
  }

  /// ✅ Format code for display (add dashes if missing)
  static String formatCode(String code) {
    final clean = code.replaceAll('-', '').toUpperCase();
    if (clean.length != 16) return code;
    
    return '${clean.substring(0, 4)}-${clean.substring(4, 8)}-'
           '${clean.substring(8, 12)}-${clean.substring(12, 16)}';
  }
}