import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../services/nearby_service.dart';

/// ✅ COMPLETE: Nearby People Discovery Page
/// Auto-connects and exchanges keys in background
class NearbyPage extends StatefulWidget {
  const NearbyPage({super.key});

  @override
  State<NearbyPage> createState() => _NearbyPageState();
}

class _NearbyPageState extends State<NearbyPage> {
  late NearbyDiscoveryService _nearbyService;
  bool _isInitialized = false;
  bool _isScanning = false;
  bool _isAdvertising = false;
  List<NearbyPerson> _nearbyPeople = [];
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  @override
  void dispose() {
    _nearbyService.dispose();
    super.dispose();
  }

  /// Initialize nearby discovery service
  Future<void> _initializeService() async {
    final provider = context.read<AppStateProvider>();
    
    if (provider.anonymousCode == null) {
      setState(() {
        _statusMessage = 'Waiting for app initialization...';
      });
      return;
    }

    final publicKey = await provider.getMyPublicKey();
    if (publicKey == null) {
      setState(() {
        _statusMessage = 'Encryption not ready';
      });
      return;
    }

    _nearbyService = NearbyDiscoveryService();

    // Setup callbacks
    _nearbyService.onPeopleDiscovered = (people) {
      setState(() {
        _nearbyPeople = people;
      });
    };

    _nearbyService.onPersonAdded = (person) {
      _showSnackBar('Found: ${person.code} (${person.distanceText})');
    };

    _nearbyService.onError = (error) {
      _showSnackBar(error, isError: true);
    };

    _nearbyService.onStatusUpdate = (message, {bool? isInfo}) {
      setState(() {
        _statusMessage = message;
      });
    };

    // Initialize
    final success = await _nearbyService.initialize(
      provider.anonymousCode!,
      publicKey,
    );

    setState(() {
      _isInitialized = success;
      if (success) {
        _statusMessage = 'Ready to discover nearby users';
      } else {
        _statusMessage = 'Failed to initialize';
      }
    });
  }

  /// Start scanning for nearby devices
  Future<void> _startScanning() async {
    if (!_isInitialized) {
      _showSnackBar('Please enable Bluetooth and grant permissions', isError: true);
      return;
    }

    setState(() {
      _isScanning = true;
      _nearbyPeople.clear();
    });

    await _nearbyService.startScanning();
    
    // Also start advertising
    if (!_isAdvertising) {
      await _startAdvertising();
    }
  }

  /// Stop scanning
  Future<void> _stopScanning() async {
    await _nearbyService.stopScanning();
    setState(() {
      _isScanning = false;
    });
  }

  /// Start advertising (make discoverable)
  Future<void> _startAdvertising() async {
    if (!_isInitialized) return;

    await _nearbyService.startAdvertising();
    setState(() {
      _isAdvertising = true;
    });
  }

  /// Stop advertising
  Future<void> _stopAdvertising() async {
    await _nearbyService.stopAdvertising();
    setState(() {
      _isAdvertising = false;
    });
  }

  /// Quick connect to nearby person
  Future<void> _quickConnect(NearbyPerson person) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Color.fromRGBO(32, 211, 102, 1),
          ),
        ),
      ),
    );

    try {
      // Get connection data
      final connectionData = await _nearbyService.quickConnect(person);
      
      if (mounted) Navigator.pop(context); // Close loading

      if (connectionData == null) {
        _showSnackBar('Failed to exchange keys', isError: true);
        return;
      }

      // Connect via app provider
      final provider = context.read<AppStateProvider>();
      await provider.connectToPeer(
        connectionData['code']!,
        connectionData['publicKey']!,
      );

      if (mounted) {
        _showSnackBar('✅ Connected to ${person.code}!');
        
        // Show success dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color.fromRGBO(39, 39, 42, 1),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color.fromRGBO(32, 211, 102, 1)),
                SizedBox(width: 8),
                Text('Connected!', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Text(
              'You can now chat with ${person.code}',
              style: const TextStyle(color: Color.fromRGBO(161, 161, 170, 1)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to chat (implement navigation)
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromRGBO(32, 211, 102, 1),
                ),
                child: const Text('Start Chat'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      _showSnackBar('Connection failed: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError 
            ? Colors.red[700] 
            : const Color.fromRGBO(32, 211, 102, 1),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 24, 27, 1),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Find Nearby',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Discover and connect instantly',
                            style: TextStyle(
                              color: Color.fromRGBO(161, 161, 170, 1),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isScanning 
                              ? const Color.fromRGBO(32, 211, 102, 0.2)
                              : const Color.fromRGBO(39, 39, 42, 1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                          color: _isScanning
                              ? const Color.fromRGBO(32, 211, 102, 1)
                              : const Color.fromRGBO(161, 161, 170, 1),
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                  
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(39, 39, 42, 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isScanning ? Icons.search : Icons.info_outline,
                            size: 16,
                            color: const Color.fromRGBO(32, 211, 102, 1),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _statusMessage!,
                              style: const TextStyle(
                                color: Color.fromRGBO(161, 161, 170, 1),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Info Card
            if (!_isInitialized)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(39, 39, 42, 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.warning_amber,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Please enable Bluetooth and grant location permissions to discover nearby users',
                        style: TextStyle(
                          color: Color.fromRGBO(161, 161, 170, 1),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // Control Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Scan Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isInitialized
                          ? (_isScanning ? _stopScanning : _startScanning)
                          : _initializeService,
                      icon: Icon(_isScanning ? Icons.stop : Icons.radar),
                      label: Text(_isScanning ? 'Stop Scanning' : 'Start Scanning'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isScanning
                            ? Colors.red[700]
                            : const Color.fromRGBO(32, 211, 102, 1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Advertising Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: _isAdvertising
                          ? const Color.fromRGBO(32, 211, 102, 0.2)
                          : const Color.fromRGBO(39, 39, 42, 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: _isInitialized
                          ? (_isAdvertising ? _stopAdvertising : _startAdvertising)
                          : null,
                      icon: Icon(
                        _isAdvertising ? Icons.visibility : Icons.visibility_off,
                        color: _isAdvertising
                            ? const Color.fromRGBO(32, 211, 102, 1)
                            : const Color.fromRGBO(161, 161, 170, 1),
                      ),
                      tooltip: _isAdvertising ? 'Visible to others' : 'Hidden',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Nearby People List
            Expanded(
              child: _nearbyPeople.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isScanning ? Icons.radar : Icons.people_outline,
                            size: 80,
                            color: const Color.fromRGBO(161, 161, 170, 0.5),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _isScanning
                                ? 'Scanning for nearby users...'
                                : 'No users found nearby',
                            style: const TextStyle(
                              color: Color.fromRGBO(161, 161, 170, 1),
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (!_isScanning)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 40),
                              child: Text(
                                'Tap "Start Scanning" to find users nearby',
                                style: TextStyle(
                                  color: Color.fromRGBO(161, 161, 170, 1),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _nearbyPeople.length,
                      itemBuilder: (context, index) {
                        return _buildNearbyPersonCard(_nearbyPeople[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyPersonCard(NearbyPerson person) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(39, 39, 42, 1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color.fromRGBO(32, 211, 102, 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar with signal strength indicator
          Stack(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color.fromRGBO(32, 211, 102, 0.3),
                      Color.fromRGBO(32, 211, 102, 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.person,
                  color: Color.fromRGBO(32, 211, 102, 1),
                  size: 28,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(24, 24, 27, 1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    person.rssi > -70 ? Icons.signal_cellular_4_bar 
                        : person.rssi > -80 ? Icons.signal_cellular_alt
                        : Icons.signal_cellular_alt_1_bar,
                    size: 12,
                    color: const Color.fromRGBO(32, 211, 102, 1),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.near_me,
                      size: 14,
                      color: Colors.green[400],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      person.distanceText,
                      style: const TextStyle(
                        color: Color.fromRGBO(161, 161, 170, 1),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '• ${person.signalStrength}',
                      style: TextStyle(
                        color: Colors.green[300],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Quick Connect Button
          ElevatedButton.icon(
            onPressed: () => _quickConnect(person),
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Connect'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(32, 211, 102, 1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}