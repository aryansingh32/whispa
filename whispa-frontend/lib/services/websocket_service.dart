import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';

/// 🔌 PRODUCTION-READY: WebSocket Service with STOMP Protocol
/// Handles real-time messaging, typing indicators, and connection management
class WebSocketService {
  final String baseUrl;
  final bool useTor;
  
  StompClient? _stompClient;
  String? _anonymousCode;
  bool _isConnected = false;
  
  // Callbacks
  Function(Map<String, dynamic>)? onMessageReceived;
  Function()? onConnected;
  Function()? onDisconnected;
  Function(String)? onError;
  Function(String sender, bool isTyping)? onTypingIndicator;
  
  WebSocketService({
    required this.baseUrl,
    this.useTor = false,
  });

  /// Connect to WebSocket server
  Future<void> connect(String anonymousCode) async {
    _anonymousCode = anonymousCode;
    
    // Convert HTTP/HTTPS URL to WS/WSS
    // final wsUrl = baseUrl
    //     .replaceAll('https://', 'wss://')
    //     .replaceAll('http://', 'ws://');
    
    print('🔌 Connecting to WebSocket: $baseUrl/ws');
    
    _stompClient = StompClient(
      config: StompConfig.sockJS(
        url: '$baseUrl/ws',
        onConnect: _onConnect,
        onWebSocketError: (dynamic error) {
          print('❌ WebSocket error: $error');
          onError?.call(error.toString());
        },
        onStompError: (StompFrame frame) {
          print('❌ STOMP error: ${frame.body}');
          onError?.call(frame.body ?? 'STOMP error');
        },
        onDisconnect: (StompFrame? frame) {
          print('🔌 Disconnected from WebSocket');
          _isConnected = false;
          onDisconnected?.call();
        },
        onWebSocketDone: () {
          print('🔌 WebSocket connection closed');
          _isConnected = false;
          onDisconnected?.call();
        },
        // Authentication headers
        stompConnectHeaders: {
          'X-Anonymous-Code': anonymousCode,
        },
        webSocketConnectHeaders: {
          'X-Anonymous-Code': anonymousCode,
        },
        // Heartbeat configuration (keeps connection alive)
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
      ),
    );
    
    // Activate connection
    _stompClient!.activate();
  }

  /// Handle successful connection
  void _onConnect(StompFrame frame) {
    print('✅ Connected to WebSocket');
    _isConnected = true;
    onConnected?.call();
    
    // Subscribe to personal message queue
    _subscribeToMessages();
    
    // Subscribe to typing indicators
    _subscribeToTypingIndicators();
  }

  /// Subscribe to incoming messages
  void _subscribeToMessages() {
    if (_stompClient == null || _anonymousCode == null) return;
    
    _stompClient!.subscribe(
      destination: '/topic/user/$_anonymousCode',
      callback: (StompFrame frame) {
        if (frame.body == null) return;
        
        try {
          final messageData = json.decode(frame.body!) as Map<String, dynamic>;
          print('📨 Message received: ${messageData['sender']}');
          
          // Forward to callback
          onMessageReceived?.call(messageData);
          
        } catch (e) {
          print('❌ Failed to parse message: $e');
          onError?.call('Failed to parse message: $e');
        }
      },
    );
    
    print('✅ Subscribed to messages: /topic/user/$_anonymousCode');
  }

  /// Subscribe to typing indicators
  void _subscribeToTypingIndicators() {
    if (_stompClient == null || _anonymousCode == null) return;
    
    _stompClient!.subscribe(
      destination: '/topic/typing/$_anonymousCode',
      callback: (StompFrame frame) {
        if (frame.body == null) return;
        
        try {
          final data = json.decode(frame.body!) as Map<String, dynamic>;
          final sender = data['sender'] as String;
          final isTyping = data['isTyping'] as bool;
          
          // Forward to callback
          onTypingIndicator?.call(sender, isTyping);
          
        } catch (e) {
          print('❌ Failed to parse typing indicator: $e');
        }
      },
    );
    
    print('✅ Subscribed to typing indicators: /topic/typing/$_anonymousCode');
  }

  /// Send encrypted message
  void sendMessage({
    required String receiver,
    required String encryptedContent,
    String? encryptedSessionKey,
    String? sessionId,
  }) {
    if (_stompClient == null || !_isConnected) {
      throw Exception('WebSocket not connected');
    }
    
    final message = {
      'sender': _anonymousCode,
      'receiver': receiver,
      'encryptedContent': encryptedContent,
      'encryptedSessionKey': encryptedSessionKey,
      'sessionId': sessionId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    try {
      _stompClient!.send(
        destination: '/app/sendMessage',
        body: json.encode(message),
      );
      
      print('✅ Message sent to $receiver');
      
    } catch (e) {
      print('❌ Failed to send message: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  /// Send typing indicator
  void sendTypingIndicator({
    required String receiver,
    required bool isTyping,
  }) {
    if (_stompClient == null || !_isConnected) return;
    
    final notification = {
      'sender': _anonymousCode,
      'receiver': receiver,
      'isTyping': isTyping,
    };
    
    try {
      _stompClient!.send(
        destination: '/app/typing',
        body: json.encode(notification),
      );
    } catch (e) {
      print('⚠️ Failed to send typing indicator: $e');
      // Don't throw, typing indicators are non-critical
    }
  }

  /// Request key exchange with peer
  void requestKeyExchange(String peerCode) {
    if (_stompClient == null || !_isConnected) {
      throw Exception('WebSocket not connected');
    }
    
    final request = {
      'sender': _anonymousCode,
      'receiver': peerCode,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    try {
      _stompClient!.send(
        destination: '/app/requestKeyExchange',
        body: json.encode(request),
      );
      
      print('✅ Key exchange requested with $peerCode');
      
    } catch (e) {
      print('❌ Failed to request key exchange: $e');
      throw Exception('Failed to request key exchange: $e');
    }
  }

  /// Send public key to peer
  void sharePublicKey({
    required String receiver,
    required String publicKey,
  }) {
    if (_stompClient == null || !_isConnected) {
      throw Exception('WebSocket not connected');
    }
    
    final keyData = {
      'sender': _anonymousCode,
      'receiver': receiver,
      'publicKey': publicKey,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    try {
      _stompClient!.send(
        destination: '/app/sharePublicKey',
        body: json.encode(keyData),
      );
      
      print('✅ Public key shared with $receiver');
      
    } catch (e) {
      print('❌ Failed to share public key: $e');
      throw Exception('Failed to share public key: $e');
    }
  }

  /// Disconnect from WebSocket
  void disconnect() {
    if (_stompClient != null) {
      _stompClient!.deactivate();
      _stompClient = null;
      _isConnected = false;
      print('🔌 WebSocket disconnected');
    }
  }

  /// Reconnect to WebSocket
  Future<void> reconnect() async {
    disconnect();
    
    if (_anonymousCode != null) {
      await Future.delayed(const Duration(seconds: 2));
      await connect(_anonymousCode!);
    }
  }

  // ============ Getters ============

  bool get isConnected => _isConnected;
  String? get anonymousCode => _anonymousCode;
}