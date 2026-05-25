import 'package:whispa_frontend/providers/app_state_provider.dart';
import 'package:whispa_frontend/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

/// ✅ Fixed: Widget to display list of all active chats
class AllChats extends StatelessWidget {
  const AllChats({super.key});

  /// Format timestamp for display
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return DateFormat('HH:mm').format(timestamp);
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(timestamp);
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, provider, child) {
        final chats = provider.chats;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "All Chats",
                    style: TextStyle(
                      color: Color.fromRGBO(161, 161, 170, 1),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    "${chats.length} ${chats.length == 1 ? 'chat' : 'chats'}",
                    style: const TextStyle(
                      color: Color.fromRGBO(161, 161, 170, 1),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Chat List
            Expanded(
              child: chats.isEmpty
                  ? _buildEmptyState(provider.isInitialized)
                  : ListView.builder(
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        return _buildChatItem(context, chat, provider);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  /// Build empty state when no chats
  Widget _buildEmptyState(bool isInitialized) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: Colors.grey.shade700,
          ),
          const SizedBox(height: 20),
          Text(
            isInitialized ? 'No chats yet' : 'Initializing...',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 10),
          if (isInitialized)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Connect with a peer to start chatting',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  /// ✅ Fixed: Build individual chat item
  Widget _buildChatItem(BuildContext context, chat, AppStateProvider provider) {
    final lastMessage = chat.lastMessage;
    final unreadCount = chat.unreadCount;
    final hasUnread = unreadCount > 0;

    return InkWell(
      onTap: () {
        // Mark messages as read when opening chat
        if (hasUnread) {
          chat.markAllAsRead();
          provider.notifyListeners();
        }
        
        // Navigate to chat screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(peerCode: chat.peerCode),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(39, 39, 42, 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: Colors.grey.shade800.withOpacity(0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: const Color.fromRGBO(78, 79, 80, 1),
                  child: Text(
                    chat.displayName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                // Online indicator (optional - implement based on your needs)
                if (chat.hasPublicKey)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(32, 211, 102, 1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color.fromRGBO(39, 39, 42, 1),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 15),

            // Chat Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Peer name/code
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Lock icon for E2EE
                      if (chat.hasPublicKey)
                        const Padding(
                          padding: EdgeInsets.only(left: 5),
                          child: Icon(
                            Icons.lock,
                            size: 14,
                            color: Color.fromRGBO(32, 211, 102, 1),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Last message or typing indicator
                  chat.isTyping
                      ? const Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color.fromRGBO(32, 211, 102, 1),
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'typing...',
                              style: TextStyle(
                                color: Color.fromRGBO(32, 211, 102, 1),
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            // Sent/Received indicator
                            if (lastMessage != null)
                              Icon(
                                lastMessage.isSent
                                    ? Icons.done_all
                                    : Icons.arrow_downward,
                                size: 14,
                                color: lastMessage.isSent
                                    ? (lastMessage.isRead
                                        ? const Color.fromRGBO(32, 211, 102, 1)
                                        : const Color.fromRGBO(161, 161, 170, 1))
                                    : const Color.fromRGBO(32, 211, 102, 1),
                              ),
                            if (lastMessage != null) const SizedBox(width: 5),
                            
                            Expanded(
                              child: Text(
                                lastMessage?.displayContent ?? 'No messages yet',
                                style: TextStyle(
                                  color: hasUnread
                                      ? Colors.white
                                      : const Color.fromRGBO(161, 161, 170, 1),
                                  fontSize: 13,
                                  fontWeight: hasUnread
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Timestamp and indicator
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Timestamp
                if (lastMessage != null)
                  Text(
                    _formatTimestamp(lastMessage.timestamp),
                    style: TextStyle(
                      color: hasUnread
                          ? const Color.fromRGBO(32, 211, 102, 1)
                          : const Color.fromRGBO(161, 161, 170, 1),
                      fontSize: 11,
                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                
                const SizedBox(height: 5),

                // Unread badge or star
                if (hasUnread)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(32, 211, 102, 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (lastMessage != null)
                  const Icon(
                    Icons.star_border,
                    size: 18,
                    color: Color.fromRGBO(161, 161, 170, 1),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}