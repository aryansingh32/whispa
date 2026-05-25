import 'dart:async';
import 'hybrid_encryption_service.dart';

/// ✅ FIXED: Automatic Session Key Rotation
/// Provides Perfect Forward Secrecy by rotating encryption keys
/// Even if a key is compromised, only recent messages are affected
class KeyRotationScheduler {
  final HybridEncryptionService _encryptionService;
  Timer? _rotationTimer;
  
  // Rotation interval (default: 1 hour)
  final Duration rotationInterval;
  
  // Callbacks
  Function(DateTime)? onRotationComplete;
  Function(String)? onError;

  KeyRotationScheduler({
    required HybridEncryptionService encryptionService,
    this.rotationInterval = const Duration(hours: 1),
  }) : _encryptionService = encryptionService;

  /// ✅ Start automatic key rotation
  /// Rotates session keys periodically for Perfect Forward Secrecy
  void startAutoRotation() {
    if (_rotationTimer != null) {
      print('⚠️ Key rotation already running');
      return;
    }

    print('🔄 Starting automatic key rotation (interval: ${rotationInterval.inMinutes} minutes)');

    _rotationTimer = Timer.periodic(rotationInterval, (timer) {
      _performRotation();
    });

    // Also perform immediate rotation on start
    _performRotation();
  }

  /// ✅ Stop automatic key rotation
  void stopAutoRotation() {
    _rotationTimer?.cancel();
    _rotationTimer = null;
    print('⏸️ Key rotation stopped');
  }

  /// ✅ Manually trigger key rotation
  void rotateNow() {
    print('🔄 Manual key rotation triggered');
    _performRotation();
  }

  /// Perform the actual rotation
  void _performRotation() {
    try {
      final timestamp = DateTime.now();
      
      // Rotate expired session keys
      _encryptionService.rotateSessionKeys();
      
      print('✅ Key rotation complete at ${timestamp.toString()}');
      print('🔐 Old keys discarded, new keys will be generated on next message');
      
      onRotationComplete?.call(timestamp);
    } catch (e) {
      print('❌ Key rotation failed: $e');
      onError?.call(e.toString());
    }
  }

  /// ✅ Get time until next rotation
  Duration? getTimeUntilNextRotation() {
    if (_rotationTimer == null) return null;
    
    // Calculate time remaining in current period
    final elapsed = DateTime.now().difference(_getLastRotationTime());
    final remaining = rotationInterval - elapsed;
    
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Get last rotation timestamp (estimated)
  DateTime _getLastRotationTime() {
    // This is a simplified implementation
    // In production, you'd store the actual timestamp
    return DateTime.now().subtract(
      Duration(
        milliseconds: DateTime.now().millisecondsSinceEpoch % rotationInterval.inMilliseconds,
      ),
    );
  }

  /// ✅ Clear all session keys immediately (emergency)
  /// Use this if you suspect key compromise
  void emergencyClearAllKeys() {
    print('🚨 EMERGENCY: Clearing all session keys');
    _encryptionService.clearSessionKeys();
    print('✅ All session keys cleared, new keys will be generated');
  }

  /// Check if auto-rotation is active
  bool get isActive => _rotationTimer != null && _rotationTimer!.isActive;

  void dispose() {
    stopAutoRotation();
  }
}

/// ✅ Key Rotation Policy Configuration
class KeyRotationPolicy {
  /// Rotation interval options
  static const Duration aggressive = Duration(minutes: 15);  // Very secure
  static const Duration moderate = Duration(hours: 1);       // Balanced (default)
  static const Duration relaxed = Duration(hours: 6);        // Battery-friendly

  /// Recommended policy based on threat model
  static Duration getRecommendedInterval({
    required bool highSecurity,
    required bool batteryConstrained,
  }) {
    if (highSecurity) {
      return aggressive;
    } else if (batteryConstrained) {
      return relaxed;
    } else {
      return moderate;
    }
  }
}
