import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../components/allChats.dart';
import '../components/header.dart';
import '../components/identityConnection.dart';
import '../components/showConnection.dart';

/// ✅ UPDATED: Main home screen with better initialization flow
/// Shows progressive feedback and handles errors gracefully
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  void initState() {
    super.initState();
    // Initialize app after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  /// Initialize the app with backend connection
  Future<void> _initializeApp() async {
    final provider = context.read<AppStateProvider>();
    
    // Check if already initialized
    if (provider.isInitialized) {
      print('ℹ️ App already initialized');
      return;
    }

    // TODO: Replace with your actual backend URL
    // For local testing:
    // - Android emulator: 'http://10.0.2.2:8080'
    // - iOS simulator: 'http://localhost:8080'
    // - Real device on same network: 'http://192.168.x.x:8080'
    // For production: 'https://your-server.com'
    const String backendUrl = 'https://whispa-production-4d07.up.railway.app';
    
    // TODO: Set to true to enable Tor routing
    // Note: Requires Orbot app installed on Android
    const bool useTor = false;

    // Show loading dialog with progress
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _buildInitializationDialog(),
      );
    }

    // Initialize app
    await provider.initialize(
      baseUrl: backendUrl,
      useTor: useTor,
    );

    // Close loading dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    // Show result
    _handleInitializationResult(provider);
  }

  /// Build initialization progress dialog
  Widget _buildInitializationDialog() {
    return WillPopScope(
      onWillPop: () async => false, // Prevent dismissal
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(20),
          color: const Color.fromRGBO(39, 39, 42, 1),
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated loading indicator
                const SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color.fromRGBO(32, 211, 102, 1),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Title
                const Text(
                  'Initializing Anonym',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Progress steps
                const Text(
                  '🔒 Setting up encryption...\n'
                  '🆔 Getting anonymous identity...\n'
                  '🔌 Connecting to server...\n'
                  '✨ Almost ready...',
                  style: TextStyle(
                    color: Color.fromRGBO(161, 161, 170, 1),
                    fontSize: 14,
                    height: 1.8,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Handle initialization result
  void _handleInitializationResult(AppStateProvider provider) {
    if (!mounted) return;

    if (provider.errorMessage != null) {
      // Show error with retry option
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '❌ Initialization Failed',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                provider.errorMessage!,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          backgroundColor: Colors.red[800],
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'RETRY',
            textColor: Colors.white,
            onPressed: () {
              _initializeApp();
            },
          ),
        ),
      );
      
      // Show retry dialog
      _showRetryDialog();
      
    } else if (provider.isInitialized) {
      // Show success with user's code
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    '✅ Connected Successfully!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Your Code: ',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      provider.anonymousCode ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(
                          ClipboardData(text: provider.anonymousCode ?? ''),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Code copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.copy,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color.fromRGBO(32, 211, 102, 1),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Show retry dialog on initialization failure
  void _showRetryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromRGBO(39, 39, 42, 1),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Connection Failed',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.read<AppStateProvider>().errorMessage ?? 
              'Unable to connect to server',
              style: const TextStyle(
                color: Color.fromRGBO(161, 161, 170, 1),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Troubleshooting:\n'
              '• Check your internet connection\n'
              '• Verify backend server is running\n'
              '• Check backend URL in code\n'
              '• Try again in a moment',
              style: TextStyle(
                color: Color.fromRGBO(161, 161, 170, 1),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Maybe allow app to continue with limited functionality
            },
            child: const Text(
              'CLOSE',
              style: TextStyle(color: Color.fromRGBO(161, 161, 170, 1)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _initializeApp();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(32, 211, 102, 1),
            ),
            child: const Text('RETRY'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, provider, child) {
        // Show loading screen during initialization
        if (provider.isInitializing) {
          return Scaffold(
            backgroundColor: const Color.fromRGBO(24, 24, 27, 1),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated logo or icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(39, 39, 42, 1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.security,
                      size: 80,
                      color: Color.fromRGBO(32, 211, 102, 1),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color.fromRGBO(32, 211, 102, 1),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  const Text(
                    'Initializing Anonym...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  const Text(
                    'Setting up secure connection',
                    style: TextStyle(
                      color: Color.fromRGBO(161, 161, 170, 1),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Main home screen UI
        return Scaffold(
          backgroundColor: const Color.fromRGBO(24, 24, 27, 1),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
              child: Column(
                children: [
                  // App header with logo
                  const Header(),
                  const SizedBox(height: 2),
                  
                  // Connection status indicators (E2EE, Tor, WebSocket)
                  const ShowConnection(),
                  const SizedBox(height: 2),
                  
                  // Identity and peer connection section
                  const IdentityConnection(),
                  const SizedBox(height: 5),
                  
                  // Chat list
                  const Expanded(child: AllChats()),
                ],
              ),
            ),
          ),
          
          // Floating action button for manual refresh if needed
          floatingActionButton: !provider.isConnected && provider.isInitialized
              ? FloatingActionButton.extended(
                  onPressed: () {
                    _initializeApp();
                  },
                  backgroundColor: const Color.fromRGBO(32, 211, 102, 1),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reconnect'),
                )
              : null,
        );
      },
    );
  }
}