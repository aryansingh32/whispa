import 'package:whispa_frontend/components/status_monetoring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';

/// ✅ NEW: Settings Page with Tor Control
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _secureStorage = const FlutterSecureStorage();
  
  bool _useTor = false;
  bool _autoKeyRotation = true;
  bool _notificationsEnabled = true;
  String _backendUrl = 'http://192.168.1.20:8080';
  
  final TextEditingController _backendController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _backendController.dispose();
    super.dispose();
  }

  /// Load settings from secure storage
  Future<void> _loadSettings() async {
    final useTor = await _secureStorage.read(key: 'use_tor');
    final autoRotation = await _secureStorage.read(key: 'auto_key_rotation');
    final notifications = await _secureStorage.read(key: 'notifications_enabled');
    final backend = await _secureStorage.read(key: 'backend_url');

    setState(() {
      _useTor = useTor == 'true';
      _autoKeyRotation = autoRotation != 'false'; // default true
      _notificationsEnabled = notifications != 'false'; // default true
      _backendUrl = backend ?? _backendUrl;
      _backendController.text = _backendUrl;
    });
  }

  /// Save setting
  Future<void> _saveSetting(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  /// Toggle Tor
  Future<void> _toggleTor(bool value) async {
    setState(() => _useTor = value);
    await _saveSetting('use_tor', value.toString());
    
    if (!mounted) return;
    
    // Show dialog about reconnection
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(39, 39, 42, 1),
        title: const Text(
          'Tor Settings Changed',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          value 
              ? 'Tor routing will be enabled on next restart.\n\nNote: Built-in Tor may be slower. You can also use Orbot app for better performance.'
              : 'Tor routing disabled. Direct connection will be used on next restart.',
          style: const TextStyle(
            color: Color.fromRGBO(161, 161, 170, 1),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _reconnectApp();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(32, 211, 102, 1),
            ),
            child: const Text('Restart Now'),
          ),
        ],
      ),
    );
  }

  /// Reconnect app with new settings
  Future<void> _reconnectApp() async {
    final provider = context.read<AppStateProvider>();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          color: Color.fromRGBO(39, 39, 42, 1),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.fromRGBO(32, 211, 102, 1),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Reconnecting...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await provider.retryInitialization(_backendUrl, _useTor,false);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Reconnected successfully'),
          backgroundColor: Color.fromRGBO(32, 211, 102, 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 24, 27, 1),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Configure your Anonym experience',
                      style: TextStyle(
                        color: Color.fromRGBO(161, 161, 170, 1),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Privacy & Security Section
              _buildSectionHeader('Privacy & Security'),
              
              _buildSettingTile(
                icon: Icons.security,
                title: 'Built-in Tor Routing',
                subtitle: _useTor 
                    ? 'Enabled - All traffic routed through Tor'
                    : 'Disabled - Using direct connection',
                trailing: Switch(
                  value: _useTor,
                  onChanged: _toggleTor,
                  activeColor: const Color.fromRGBO(32, 211, 102, 1),
                ),
              ),

              _buildSettingTile(
                icon: Icons.autorenew,
                title: 'Automatic Key Rotation',
                subtitle: 'Rotate encryption keys every hour',
                trailing: Switch(
                  value: _autoKeyRotation,
                  onChanged: (value) {
                    setState(() => _autoKeyRotation = value);
                    _saveSetting('auto_key_rotation', value.toString());
                  },
                  activeColor: const Color.fromRGBO(32, 211, 102, 1),
                ),
              ),

              _buildSettingTile(
                icon: Icons.delete_forever,
                title: 'Emergency Clear Keys',
                subtitle: 'Clear all encryption keys immediately',
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color.fromRGBO(161, 161, 170, 1),
                ),
                onTap: _showEmergencyClearDialog,
              ),

              // Connection Section
              _buildSectionHeader('Connection'),

              _buildSettingTile(
                icon: Icons.dns,
                title: 'Backend Server',
                subtitle: _backendUrl,
                trailing: const Icon(
                  Icons.edit,
                  size: 20,
                  color: Color.fromRGBO(161, 161, 170, 1),
                ),
                onTap: _showBackendDialog,
              ),

              Consumer<AppStateProvider>(
                builder: (context, provider, child) {
                  return _buildSettingTile(
                    icon: Icons.info_outline,
                    title: 'Connection Status',
                    subtitle: provider.isConnected 
                        ? 'Connected' 
                        : 'Disconnected',
                    trailing: Icon(
                      Icons.circle,
                      size: 12,
                      color: provider.isConnected 
                          ? const Color.fromRGBO(32, 211, 102, 1)
                          : Colors.red,
                    ),
                  );
                },
              ),
              StatusMonitorWidget(),

              // Notifications Section
              _buildSectionHeader('Notifications'),

              _buildSettingTile(
                icon: Icons.notifications,
                title: 'Enable Notifications',
                subtitle: 'Get notified about new messages',
                trailing: Switch(
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() => _notificationsEnabled = value);
                    _saveSetting('notifications_enabled', value.toString());
                  },
                  activeColor: const Color.fromRGBO(32, 211, 102, 1),
                ),
              ),

              // About Section
              _buildSectionHeader('About'),

              _buildSettingTile(
                icon: Icons.info,
                title: 'App Version',
                subtitle: '1.0.0',
              ),

              _buildSettingTile(
                icon: Icons.description,
                title: 'Privacy Policy',
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Color.fromRGBO(161, 161, 170, 1),
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Privacy Policy coming soon')),
                  );
                },
              ),
              

              const SizedBox(height: 32),

              // Logout Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showLogoutDialog,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Color.fromRGBO(32, 211, 102, 1),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(39, 39, 42, 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color.fromRGBO(32, 211, 102, 1)),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(
                  color: Color.fromRGBO(161, 161, 170, 1),
                  fontSize: 12,
                ),
              )
            : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  void _showBackendDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(39, 39, 42, 1),
        title: const Text(
          'Backend Server',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: _backendController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'http://example.com:8080',
            hintStyle: TextStyle(color: Color.fromRGBO(161, 161, 170, 1)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _backendUrl = _backendController.text);
              _saveSetting('backend_url', _backendUrl);
              Navigator.pop(context);
              _reconnectApp();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(32, 211, 102, 1),
            ),
            child: const Text('Save & Reconnect'),
          ),
        ],
      ),
    );
  }

  void _showEmergencyClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(39, 39, 42, 1),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text(
              'Emergency Clear',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: const Text(
          'This will immediately clear all encryption keys. You will need to exchange keys again with all contacts.\n\nThis action cannot be undone.',
          style: TextStyle(color: Color.fromRGBO(161, 161, 170, 1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<AppStateProvider>().emergencyClearKeys();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚨 All keys cleared'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
            ),
            child: const Text('Clear All Keys'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(39, 39, 42, 1),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will disconnect you and clear all local data. Are you sure?',
          style: TextStyle(color: Color.fromRGBO(161, 161, 170, 1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await context.read<AppStateProvider>().logout();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logged out successfully'),
                    backgroundColor: Color.fromRGBO(32, 211, 102, 1),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}