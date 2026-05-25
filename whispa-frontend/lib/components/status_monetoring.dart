import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whispa_frontend/providers/app_state_provider.dart';

/// 🔍 Real-time Status Monitor Widget
/// Use this to debug and monitor status changes in real-time
class StatusMonitorWidget extends StatefulWidget {
  final bool showDetailed;
  
  const StatusMonitorWidget({
    super.key,
    this.showDetailed = false,
  });

  @override
  State<StatusMonitorWidget> createState() => _StatusMonitorWidgetState();
}

class _StatusMonitorWidgetState extends State<StatusMonitorWidget> {
  final List<String> _statusLog = [];
  int _updateCount = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, provider, child) {
        // Log status changes
        _logStatusChange(provider);
        
        return Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(39, 39, 42, 1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color.fromRGBO(161, 161, 170, 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.monitor_heart,
                    color: Color.fromRGBO(32, 211, 102, 1),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Status Monitor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Updates: $_updateCount',
                    style: const TextStyle(
                      color: Color.fromRGBO(161, 161, 170, 1),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Status Grid
              _buildStatusGrid(provider),
              
              if (widget.showDetailed) ...[
                const SizedBox(height: 16),
                const Divider(
                  color: Color.fromRGBO(161, 161, 170, 0.3),
                  height: 1,
                ),
                const SizedBox(height: 16),
                _buildDetailedInfo(provider),
              ],
              
              // Refresh Button
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await provider.refreshE2EEStatus();
                    setState(() {
                      _updateCount++;
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh E2EE Status'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromRGBO(78, 79, 80, 1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusGrid(AppStateProvider provider) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                'Initialized',
                provider.isInitialized,
                Icons.power_settings_new,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatusCard(
                'Connected',
                provider.isConnected,
                Icons.wifi,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                'E2EE Active',
                provider.isE2EEActive,
                Icons.lock,
                showPulse: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatusCard(
                'Tor Connected',
                provider.isTorConnected,
                Icons.security,
                showPulse: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard(
    String label,
    bool isActive,
    IconData icon, {
    bool showPulse = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? const Color.fromRGBO(32, 211, 102, 0.1)
            : const Color.fromRGBO(161, 161, 170, 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive
              ? const Color.fromRGBO(32, 211, 102, 0.3)
              : const Color.fromRGBO(161, 161, 170, 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isActive
                    ? const Color.fromRGBO(32, 211, 102, 1)
                    : const Color.fromRGBO(161, 161, 170, 1),
                size: 20,
              ),
              if (showPulse && isActive) ...[
                const SizedBox(width: 6),
                _buildPulseIndicator(),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : const Color.fromRGBO(161, 161, 170, 1),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color.fromRGBO(32, 211, 102, 0.2)
                  : const Color.fromRGBO(161, 161, 170, 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color: isActive
                    ? const Color.fromRGBO(32, 211, 102, 1)
                    : const Color.fromRGBO(161, 161, 170, 1),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulseIndicator() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1500),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(32, 211, 102, 1).withOpacity(1 - value),
            shape: BoxShape.circle,
          ),
        );
      },
      onEnd: () {
        if (mounted) setState(() {});
      },
    );
  }

  Widget _buildDetailedInfo(AppStateProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detailed Information',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildInfoRow('Anonymous Code', provider.anonymousCode ?? '----'),
        _buildInfoRow('Active Chats', provider.chats.length.toString()),
        _buildInfoRow('Persistence', provider.persistenceEnabled ? 'Enabled' : 'Disabled'),
        if (provider.errorMessage != null)
          _buildInfoRow('Error', provider.errorMessage!, isError: true),
        
        const SizedBox(height: 12),
        
        // Connection Status Details
        FutureBuilder<Map<String, dynamic>>(
          future: _getConnectionDetails(provider),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final details = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connection Details',
                    style: TextStyle(
                      color: Color.fromRGBO(161, 161, 170, 1),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(24, 24, 27, 1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSmallInfoRow('Has Public Key', details['hasPublicKey'].toString()),
                        _buildSmallInfoRow('Public Key Length', details['keyLength']),
                      ],
                    ),
                  ),
                ],
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color.fromRGBO(161, 161, 170, 1),
              fontSize: 12,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: isError ? Colors.red : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color.fromRGBO(161, 161, 170, 1),
              fontSize: 10,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color.fromRGBO(32, 211, 102, 1),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _getConnectionDetails(AppStateProvider provider) async {
    final publicKey = await provider.getMyPublicKey();
    return {
      'hasPublicKey': publicKey != null,
      'keyLength': publicKey?.length.toString() ?? '0',
    };
  }

  void _logStatusChange(AppStateProvider provider) {
    final status = 'E2EE: ${provider.isE2EEActive}, Tor: ${provider.isTorConnected}';
    if (_statusLog.isEmpty || _statusLog.last != status) {
      _statusLog.add(status);
      if (_statusLog.length > 10) {
        _statusLog.removeAt(0);
      }
      _updateCount++;
    }
  }
}

// ========================================
// Simplified Status Bar Widget
// ========================================

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(39, 39, 42, 1),
            border: Border(
              bottom: BorderSide(
                color: const Color.fromRGBO(161, 161, 170, 0.3),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              _buildStatusDot(provider.isConnected, 'Server'),
              const SizedBox(width: 12),
              _buildStatusDot(provider.isE2EEActive, 'E2EE'),
              const SizedBox(width: 12),
              _buildStatusDot(provider.isTorConnected, 'Tor'),
              const Spacer(),
              if (!provider.isE2EEActive || !provider.isTorConnected)
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 18,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusDot(bool isActive, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? const Color.fromRGBO(32, 211, 102, 1)
                : const Color.fromRGBO(161, 161, 170, 1),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: isActive
                ? const Color.fromRGBO(32, 211, 102, 1)
                : const Color.fromRGBO(161, 161, 170, 1),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ========================================
// Floating Status Button
// ========================================

class FloatingStatusButton extends StatelessWidget {
  const FloatingStatusButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, provider, child) {
        final isSecure = provider.isE2EEActive && provider.isTorConnected;
        
        return FloatingActionButton.extended(
          onPressed: () {
            _showStatusDialog(context, provider);
          },
          backgroundColor: isSecure
              ? const Color.fromRGBO(32, 211, 102, 1)
              : Colors.orange,
          icon: Icon(isSecure ? Icons.shield : Icons.warning),
          label: Text(isSecure ? 'Secure' : 'Unsecured'),
        );
      },
    );
  }

  void _showStatusDialog(BuildContext context, AppStateProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(39, 39, 42, 1),
        title: const Text(
          'Security Status',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogRow('Server', provider.isConnected),
            _buildDialogRow('E2EE', provider.isE2EEActive),
            _buildDialogRow('Tor', provider.isTorConnected),
            const SizedBox(height: 16),
            if (!provider.isE2EEActive)
              const Text(
                '⚠️ E2EE is not active. Exchange keys with contacts to enable encryption.',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                ),
              ),
            if (!provider.isTorConnected)
              const Text(
                '⚠️ Tor is not connected. Enable Tor during initialization for enhanced privacy.',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!provider.isE2EEActive)
            ElevatedButton(
              onPressed: () async {
                await provider.refreshE2EEStatus();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(32, 211, 102, 1),
              ),
              child: const Text('Refresh'),
            ),
        ],
      ),
    );
  }

  Widget _buildDialogRow(String label, bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color.fromRGBO(161, 161, 170, 1),
              fontSize: 14,
            ),
          ),
          Row(
            children: [
              Icon(
                isActive ? Icons.check_circle : Icons.cancel,
                color: isActive
                    ? const Color.fromRGBO(32, 211, 102, 1)
                    : Colors.red,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: isActive
                      ? const Color.fromRGBO(32, 211, 102, 1)
                      : Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}