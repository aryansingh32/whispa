import 'message_model.dart';

/// ✅ Chat model for storing chat information
class Chat {
  final String peerCode;
  String displayName;
  List<Message> messages;
  Message? lastMessage;
  bool hasPublicKey;
  bool isTyping;
  DateTime? lastSeen;

  Chat({
    required this.peerCode,
    String? displayName,
    required this.messages,
    this.lastMessage,
    this.hasPublicKey = false,
    this.isTyping = false,
    this.lastSeen,
  }) : displayName = displayName ?? peerCode;

  /// Get unread message count
  int get unreadCount {
    return messages.where((m) => !m.isSent && !m.isRead).length;
  }

  /// Mark all messages as read
  void markAllAsRead() {
    for (var message in messages) {
      if (!message.isSent) {
        message.isRead = true;
      }
    }
  }

  /// Get last message preview
  String get lastMessagePreview {
    if (lastMessage == null) {
      return 'No messages yet';
    }
    
    final content = lastMessage!.decryptedContent ?? '[Encrypted]';
    return content.length > 50 ? '${content.substring(0, 50)}...' : content;
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'peerCode': peerCode,
      'displayName': displayName,
      'messages': messages.map((m) => m.toJson()).toList(),
      'lastMessage': lastMessage?.toJson(),
      'hasPublicKey': hasPublicKey,
      'isTyping': isTyping,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      peerCode: json['peerCode'],
      displayName: json['displayName'],
      messages: (json['messages'] as List)
          .map((m) => Message.fromJson(m))
          .toList(),
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'])
          : null,
      hasPublicKey: json['hasPublicKey'] ?? false,
      isTyping: json['isTyping'] ?? false,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'])
          : null,
    );
  }

  /// Copy with updated values
  Chat copyWith({
    String? displayName,
    List<Message>? messages,
    Message? lastMessage,
    bool? hasPublicKey,
    bool? isTyping,
    DateTime? lastSeen,
  }) {
    return Chat(
      peerCode: peerCode,
      displayName: displayName ?? this.displayName,
      messages: messages ?? this.messages,
      lastMessage: lastMessage ?? this.lastMessage,
      hasPublicKey: hasPublicKey ?? this.hasPublicKey,
      isTyping: isTyping ?? this.isTyping,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}