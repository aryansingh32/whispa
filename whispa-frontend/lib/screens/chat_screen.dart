import 'dart:async';
import 'package:whispa_frontend/models/message_model.dart';
import 'package:whispa_frontend/providers/app_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Individual chat screen for messaging with a specific peer
/// Displays message history and allows sending encrypted messages
class ChatScreen extends StatefulWidget {
  final String peerCode;

  const ChatScreen({required this.peerCode, super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  /// Scroll to bottom of chat
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// Handle text input changes
  void _onTextChanged(String text) {
    final provider = context.read<AppStateProvider>();
    
    // Send typing indicator
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      provider.sendTypingIndicator(widget.peerCode, true);
    } else if (text.isEmpty && _isTyping) {
      _isTyping = false;
      provider.sendTypingIndicator(widget.peerCode, false);
    }

    // Reset typing timer
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        provider.sendTypingIndicator(widget.peerCode, false);
      }
    });
  }

  /// Send message
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    
    if (text.isEmpty) return;

    final provider = context.read<AppStateProvider>();

    try {
      // Clear input immediately
      _messageController.clear();
      
      // Stop typing indicator
      if (_isTyping) {
        _isTyping = false;
        provider.sendTypingIndicator(widget.peerCode, false);
      }

      // Send message
      await provider.sendMessage(widget.peerCode, text);

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(24, 24, 27, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(39, 39, 42, 1),
        title: Consumer<AppStateProvider>(
          builder: (context, provider, child) {
            final chat = provider.getChat(widget.peerCode);
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chat?.displayName ?? widget.peerCode,
                  style: const TextStyle(fontSize: 16),
                ),
                // Show typing indicator or encryption status
                if (chat?.isTyping ?? false)
                  const Text(
                    'typing...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color.fromRGBO(32, 211, 102, 1),
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else if (chat?.hasPublicKey ?? false)
                  const Row(
                    children: [
                      Icon(
                        Icons.lock,
                        size: 12,
                        color: Color.fromRGBO(32, 211, 102, 1),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'End-to-end encrypted',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color.fromRGBO(161, 161, 170, 1),
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // TODO: Show chat info
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Chat with ${widget.peerCode}')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: Consumer<AppStateProvider>(
              builder: (context, provider, child) {
                final chat = provider.getChat(widget.peerCode);
                final messages = chat?.messages ?? [];

                // Scroll to bottom when messages change
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.message_outlined,
                          size: 64,
                          color: Color.fromRGBO(161, 161, 170, 1),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No messages yet',
                          style: TextStyle(
                            color: Color.fromRGBO(161, 161, 170, 1),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Send a message to ${widget.peerCode}',
                          style: const TextStyle(
                            color: Color.fromRGBO(161, 161, 170, 1),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageBubble(messages[index]);
                  },
                );
              },
            ),
          ),

          // Message Input
          _buildMessageInput(),
        ],
      ),
    );
  }

  /// Build message bubble
  Widget _buildMessageBubble(Message message) {
    final isSent = message.isSent;
    final time = DateFormat('HH:mm').format(message.timestamp);

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isSent
              ? const Color.fromRGBO(32, 211, 102, 1)
              : const Color.fromRGBO(39, 39, 42, 1),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isSent ? const Radius.circular(12) : Radius.zero,
            bottomRight: isSent ? Radius.zero : const Radius.circular(12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message text
            Text(
              message.decryptedContent ?? '[Decryption Failed]',
              style: TextStyle(
                color: isSent ? Colors.white : Colors.white,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            
            // Timestamp
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    color: isSent
                        ? Colors.white.withOpacity(0.7)
                        : const Color.fromRGBO(161, 161, 170, 1),
                    fontSize: 11,
                  ),
                ),
                if (isSent) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build message input area
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: Color.fromRGBO(39, 39, 42, 1),
        border: Border(
          top: BorderSide(
            color: Color.fromRGBO(161, 161, 170, 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Text input
          Expanded(
            child: TextField(
              controller: _messageController,
              onChanged: _onTextChanged,
              onSubmitted: (_) => _sendMessage(),
              style: const TextStyle(color: Colors.white),
              cursorColor: const Color.fromRGBO(32, 211, 102, 1),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(
                  color: Color.fromRGBO(161, 161, 170, 1),
                ),
                fillColor: const Color.fromRGBO(24, 24, 27, 1),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
            ),
          ),

          const SizedBox(width: 8),

          // Send button
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color.fromRGBO(32, 211, 102, 1),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
