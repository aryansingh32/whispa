/// ✅ Fixed Message model
class Message {
  final String sender;
  final String receiver;
  final String? encryptedContent;
  final String? decryptedContent;
  final DateTime timestamp;
  final bool isSent;
  bool isRead;
  String? messageId;
  MessageStatus status;

  Message({
    required this.sender,
    required this.receiver,
    this.encryptedContent,
    this.decryptedContent,
    required this.timestamp,
    required this.isSent,
    this.isRead = false,
    this.messageId,
    this.status = MessageStatus.sent,
  });

  /// Get display content
  String get displayContent {
    if (decryptedContent != null && decryptedContent!.isNotEmpty) {
      return decryptedContent!;
    }
    if (encryptedContent != null) {
      return '[Encrypted Message]';
    }
    return '[No Content]';
  }

  /// Check if message is encrypted
  bool get isEncrypted => encryptedContent != null;

  /// Check if message is decrypted
  bool get isDecrypted => decryptedContent != null;

  /// Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${(difference.inDays / 7).floor()}w ago';
    }
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'sender': sender,
      'receiver': receiver,
      'encryptedContent': encryptedContent,
      'decryptedContent': decryptedContent,
      'timestamp': timestamp.toIso8601String(),
      'isSent': isSent,
      'isRead': isRead,
      'messageId': messageId,
      'status': status.name,
    };
  }

  /// ✅ Fixed: Create from JSON
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      sender: json['sender'] as String,
      receiver: json['receiver'] as String,
      encryptedContent: json['encryptedContent'] as String?,
      decryptedContent: json['decryptedContent'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isSent: json['isSent'] as bool? ?? false,
      isRead: json['isRead'] as bool? ?? false,
      messageId: json['messageId'] as String?,
      status: json['status'] != null
          ? MessageStatus.values.firstWhere(
              (e) => e.name == json['status'],
              orElse: () => MessageStatus.sent,
            )
          : MessageStatus.sent,
    );
  }

  /// Copy with updated values
  Message copyWith({
    String? decryptedContent,
    bool? isRead,
    MessageStatus? status,
    String? messageId,
  }) {
    return Message(
      sender: sender,
      receiver: receiver,
      encryptedContent: encryptedContent,
      decryptedContent: decryptedContent ?? this.decryptedContent,
      timestamp: timestamp,
      isSent: isSent,
      isRead: isRead ?? this.isRead,
      messageId: messageId ?? this.messageId,
      status: status ?? this.status,
    );
  }
}

/// Message delivery status
enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}