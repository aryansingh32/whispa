import 'package:whispa_frontend/providers/app_state_provider.dart';
import 'package:whispa_frontend/screens/key_exchange_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// ✅ FIXED: Widget for displaying user's anonymous code and connecting to peers
class IdentityConnection extends StatefulWidget {
  const IdentityConnection({super.key});

  @override
  State<IdentityConnection> createState() => _IdentityConnectionState();
}

class _IdentityConnectionState extends State<IdentityConnection> {
  final TextEditingController _peerCodeController = TextEditingController();
  bool _isConnecting = false;

  @override
  void dispose() {
    _peerCodeController.dispose();
    super.dispose();
  }

  /// Copy anonymous code to clipboard
  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copied to clipboard!'),
        backgroundColor: Color.fromRGBO(32, 211, 102, 1),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Share anonymous code via QR
  void _shareCode(BuildContext context, String code) async {
    final provider = context.read<AppStateProvider>();
    final publicKey = await provider.getMyPublicKey();

    if (publicKey == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Public key not available'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => KeyExchangeScreen(
            anonymousCode: code,
            publicKey: publicKey,
          ),
        ),
      );
    }
  }

  /// ✅ FIXED: Connect to peer - direct connection if key exists
  Future<void> _connectToPeer(BuildContext context) async {
    final peerCode = _peerCodeController.text.trim().toUpperCase();

    // Validate input
    if (peerCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please enter peer code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check if trying to connect to self
    final provider = context.read<AppStateProvider>();
    if (peerCode == provider.anonymousCode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Cannot connect to yourself'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      // ✅ FIX: Always check if we have the public key first
      final hasKey = await provider.hasPeerPublicKey(peerCode);
      print('🔍 Checking peer $peerCode - Has key: $hasKey');

      if (hasKey) {
        // ✅ We have the key - connect directly
        print('✅ Public key found for $peerCode - connecting directly');
        
        // Check if chat already exists
        final existingChat = provider.getChat(peerCode);
        
        if (existingChat != null) {
          // Chat already exists
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Already connected to $peerCode'),
                backgroundColor: const Color.fromRGBO(32, 211, 102, 1),
              ),
            );
            _peerCodeController.clear();
          }
        } else {
          // Create new chat with existing key
          await provider.ensureChatExists(peerCode);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Connected to $peerCode'),
                backgroundColor: const Color.fromRGBO(32, 211, 102, 1),
              ),
            );
            _peerCodeController.clear();
          }
        }
      } else {
        // ❌ No key - but connecting directly as requested
        print('⚠️ No public key for $peerCode - connecting directly anyway');
        
        await provider.ensureChatExists(peerCode);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Connected to $peerCode'),
              backgroundColor: const Color.fromRGBO(32, 211, 102, 1),
            ),
          );
          _peerCodeController.clear();
        }
      }
    } catch (e) {
      print('❌ Connection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Connection failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, provider, child) {
        final anonymousCode = provider.anonymousCode ?? '----';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Identity & Connection",
              style: TextStyle(
                color: Color.fromRGBO(161, 161, 170, 1),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(39, 39, 42, 1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Your Anonymous Code Section
                  const Text(
                    "Your Anonymous Code",
                    style: TextStyle(
                      color: Color.fromRGBO(161, 161, 170, 1),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    anonymousCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 20,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Action Buttons Row
                  Row(
                    children: [
                      // Copy Button
                      Expanded(
                        child: InkWell(
                          onTap: provider.isInitialized
                              ? () => _copyCode(anonymousCode)
                              : null,
                          child: Container(
                            height: 43,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: provider.isInitialized
                                  ? const Color.fromRGBO(78, 79, 80, 1)
                                  : Colors.grey.shade700,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.copy,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  "Copy",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Share Code Button
                      Expanded(
                        child: InkWell(
                          onTap: provider.isInitialized
                              ? () => _shareCode(context, anonymousCode)
                              : null,
                          child: Container(
                            height: 43,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: provider.isInitialized
                                  ? const Color.fromRGBO(32, 211, 102, 1)
                                  : Colors.grey.shade700,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  "Show QR",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // Divider
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: const Color.fromRGBO(161, 161, 170, 0.3),
                  ),

                  const SizedBox(height: 12),

                  // Instructions
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Color.fromRGBO(32, 211, 102, 1),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Enter peer code to connect',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Peer Code Input Field
                  TextField(
                    controller: _peerCodeController,
                    enabled: provider.isInitialized && !_isConnecting,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: const Color.fromRGBO(32, 211, 102, 1),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: "XXXX-XXXX-XXXX-XXXX",
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        letterSpacing: 1.2,
                      ),
                      fillColor: const Color.fromRGBO(24, 24, 27, 1),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(5),
                        borderSide: const BorderSide(
                          color: Color.fromRGBO(32, 211, 102, 1),
                          width: 1,
                        ),
                      ),
                      prefixIcon: const Icon(
                        Icons.person_add,
                        color: Color.fromRGBO(161, 161, 170, 1),
                        size: 20,
                      ),
                      suffixIcon: _peerCodeController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Color.fromRGBO(161, 161, 170, 1),
                                size: 20,
                              ),
                              onPressed: () {
                                _peerCodeController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),

                  const SizedBox(height: 10),

                  // Connect Button
                  InkWell(
                    onTap: provider.isInitialized && !_isConnecting
                        ? () => _connectToPeer(context)
                        : null,
                    child: Container(
                      height: 44,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: provider.isInitialized && !_isConnecting
                            ? const Color.fromRGBO(32, 211, 102, 1)
                            : Colors.grey.shade700,
                      ),
                      child: Center(
                        child: _isConnecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.link,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Connect",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}