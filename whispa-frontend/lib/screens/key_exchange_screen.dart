import 'dart:convert';
import 'package:whispa_frontend/providers/app_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Screen for exchanging public keys via QR codes
/// Allows secure key exchange between peers
class KeyExchangeScreen extends StatefulWidget {
  final String anonymousCode;
  final String publicKey;
  final String? peerCode;

  const KeyExchangeScreen({
    required this.anonymousCode,
    required this.publicKey,
    super.key,
  }) : peerCode = null;

  const KeyExchangeScreen.forPeer({
    required this.peerCode,
    super.key,
  })  : anonymousCode = '',
        publicKey = '';

  @override
  State<KeyExchangeScreen> createState() => _KeyExchangeScreenState();
}

class _KeyExchangeScreenState extends State<KeyExchangeScreen> {
  bool _isScanning = false;
  bool _showMyCode = true;
  MobileScannerController? _scannerController;
  String? _myPublicKey;
  String? _myCode;

  @override
  void initState() {
    super.initState();
    _loadMyCredentials();
  }

  /// Load user's own credentials for sharing
  Future<void> _loadMyCredentials() async {
    final provider = context.read<AppStateProvider>();
    
    if (widget.anonymousCode.isNotEmpty) {
      _myCode = widget.anonymousCode;
      _myPublicKey = widget.publicKey;
    } else {
      _myCode = provider.anonymousCode;
      _myPublicKey = await provider.getMyPublicKey();
    }
    
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  /// Toggle between showing QR and scanning
  void _toggleMode() {
    setState(() {
      _showMyCode = !_showMyCode;
      if (!_showMyCode && _scannerController == null) {
        _scannerController = MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
        );
      }
    });
  }

  /// Handle scanned QR code
  void _handleQRScan(BarcodeCapture capture) async {
    final barcodes = capture.barcodes;
    
    if (barcodes.isEmpty) return;
    
    try {
      final qrData = barcodes.first.rawValue;
      if (qrData == null || qrData.isEmpty) return;

      // Parse QR data (format: "CODE:PUBLIC_KEY")
      final data = json.decode(qrData);
      final peerCode = data['code'] as String;
      final peerPublicKey = data['publicKey'] as String;

      // Stop scanning
      _scannerController?.stop();

      // Store peer's public key
      final provider = context.read<AppStateProvider>();
      await provider.connectToPeer(peerCode, peerPublicKey);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Connected to $peerCode'),
            backgroundColor: Colors.green,
          ),
        );

        // Return success
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('❌ Failed to process QR code: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid QR code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Generate QR code data
  String _generateQRData() {
    if (_myCode == null || _myPublicKey == null) {
      return '';
    }

    return json.encode({
      'code': _myCode,
      'publicKey': _myPublicKey,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 24, 27, 1),
      appBar: AppBar(
        title: const Text('Exchange Keys'),
        backgroundColor: const Color.fromRGBO(39, 39, 42, 1),
        actions: [
          IconButton(
            icon: Icon(_showMyCode ? Icons.qr_code_scanner : Icons.qr_code),
            onPressed: _toggleMode,
            tooltip: _showMyCode ? 'Scan QR' : 'Show QR',
          ),
        ],
      ),
      body: _myPublicKey == null
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'Loading credentials...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            )
          : _showMyCode
              ? _buildShowQRCode()
              : _buildScanQRCode(),
    );
  }

  /// Build UI for showing user's QR code
  Widget _buildShowQRCode() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Share your QR code',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Let your peer scan this code to connect',
              style: TextStyle(
                color: Color.fromRGBO(161, 161, 170, 1),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            
            // QR Code
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: QrImageView(
                data: _generateQRData(),
                size: 250,
                backgroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 30),

            // Your Code Display
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(39, 39, 42, 1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  const Text(
                    'Your Code',
                    style: TextStyle(
                      color: Color.fromRGBO(161, 161, 170, 1),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _myCode ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Scan Button
            ElevatedButton.icon(
              onPressed: _toggleMode,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Peer\'s QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromRGBO(32, 211, 102, 1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build UI for scanning peer's QR code
  Widget _buildScanQRCode() {
    return Column(
      children: [
        // Instructions
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: const Color.fromRGBO(39, 39, 42, 1),
          child: Column(
            children: [
              const Text(
                'Scan your peer\'s QR code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.peerCode != null 
                    ? 'Connecting to: ${widget.peerCode}'
                    : 'Point your camera at the QR code',
                style: const TextStyle(
                  color: Color.fromRGBO(161, 161, 170, 1),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),

        // Scanner
        Expanded(
          child: _scannerController != null
              ? MobileScanner(
                  controller: _scannerController,
                  onDetect: _handleQRScan,
                )
              : const Center(
                  child: CircularProgressIndicator(),
                ),
        ),

        // Show My Code Button
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: ElevatedButton.icon(
            onPressed: _toggleMode,
            icon: const Icon(Icons.qr_code),
            label: const Text('Show My QR Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromRGBO(78, 79, 80, 1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
