import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/backend_service.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

/// ✅ COMPLETE & FIXED: App State Provider with Optional Persistence
class AppStateProvider extends ChangeNotifier {
  BackendService? _backendService;
  
  // State
  String? _anonymousCode;
  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isConnected = false;
  bool _isTorConnected = false;
  bool _isE2EEActive = false;
  String? _errorMessage;
  bool _enablePersistence = false;
  
  // Chats
  final Map<String, Chat> _chats = {};
  
  // Local storage
  Box? _chatBox;
  Box? _messagesBox;
  
  // Getters
  String? get anonymousCode => _anonymousCode;
  bool get isInitialized => _isInitialized;
  bool get isInitializing => _isInitializing;
  bool get isConnected => _isConnected;
  bool get isTorConnected => _isTorConnected;
  bool get isE2EEActive => _isE2EEActive;
  String? get errorMessage => _errorMessage;
  bool get persistenceEnabled => _enablePersistence;
  
  List<Chat> get chats => _chats.values.toList()
    ..sort((a, b) {
      final aTime = a.lastMessage?.timestamp ?? DateTime(2000);
      final bTime = b.lastMessage?.timestamp ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

  /// ✅ Initialize backend service with optional persistence
  Future<void> initialize({
    required String baseUrl,
    bool useTor = false,
    bool enablePersistence = false,
  }) async {
    if (_isInitializing || _isInitialized) {
      print('⚠️ Already initialized or initializing');
      return;
    }

    _isInitializing = true;
    _errorMessage = null;
    _enablePersistence = enablePersistence;
    notifyListeners();

    try {
      print('🚀 Initializing app state provider...');

      // Initialize local storage if persistence enabled
      if (_enablePersistence) {
        await _initLocalStorage();
      }

      // Create backend service
      _backendService = BackendService(
        baseUrl: baseUrl,
        useTor: useTor,
      );

      // Setup callbacks
      _setupBackendCallbacks();

      // Initialize backend
      final success = await _backendService!.initialize();

      if (success) {
        _anonymousCode = _backendService!.anonymousCode;
        _isInitialized = true;
        _isConnected = _backendService!.isConnected;
        _isTorConnected = useTor;
        
        // Check E2EE status
        await _updateE2EEStatus();
        
        // Load persisted chats if enabled
        if (_enablePersistence) {
          await _loadLocalChats();
        }
        
        print('✅ App initialized successfully: $_anonymousCode');
        print('🔐 E2EE Active: $_isE2EEActive');
        print('🧅 Tor Connected: $_isTorConnected');
      } else {
        _errorMessage = 'Backend initialization failed';
        print('❌ Backend initialization failed');
      }
    } catch (e) {
      _errorMessage = e.toString();
      print('❌ Initialization error: $e');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  /// ✅ Initialize local storage with Hive
  Future<void> _initLocalStorage() async {
    try {
      await Hive.initFlutter();
      
      _chatBox = await Hive.openBox('chats_box');
      _messagesBox = await Hive.openBox('messages_box');
      
      print('📦 Hive storage initialized');
    } catch (e) {
      print('❌ Failed to init storage: $e');
      _enablePersistence = false;
    }
  }

  /// ✅ Update E2EE status
  Future<void> _updateE2EEStatus() async {
    try {
      final myKey = await getMyPublicKey();
      _isE2EEActive = myKey != null && myKey.isNotEmpty;
      
      // Also check if backend has keys
      if (_backendService != null) {
        _isE2EEActive = _isE2EEActive && (_backendService!.hasKeys ?? false);
      }
    } catch (e) {
      print('⚠️ Failed to check E2EE status: $e');
      _isE2EEActive = false;
    }
  }

  /// ✅ Load chats from local storage
  Future<void> _loadLocalChats() async {
    if (_chatBox == null || _messagesBox == null) return;

    try {
      final storedChats = _chatBox!.toMap();
      
      for (var entry in storedChats.entries) {
        try {
          final chatData = Map<String, dynamic>.from(entry.value);
          final peerCode = entry.key as String;
          
          // Load messages for this chat
          final messagesData = _messagesBox!.get(peerCode);
          List<Message> messages = [];
          
          if (messagesData != null) {
            final messagesList = List<Map<String, dynamic>>.from(messagesData);
            messages = messagesList.map((m) => Message.fromJson(m)).toList();
          }
          
          // Create chat with loaded messages
          _chats[peerCode] = Chat(
            peerCode: peerCode,
            displayName: chatData['displayName'] ?? peerCode,
            messages: messages,
            lastMessage: messages.isNotEmpty ? messages.last : null,
            hasPublicKey: chatData['hasPublicKey'] ?? false,
            isTyping: false,
            lastSeen: chatData['lastSeen'] != null 
                ? DateTime.parse(chatData['lastSeen']) 
                : null,
          );
        } catch (e) {
          print('⚠️ Failed to load chat ${entry.key}: $e');
        }
      }
      
      print('💾 Loaded ${_chats.length} chats from storage');
      notifyListeners();
    } catch (e) {
      print('❌ Failed to load chats: $e');
    }
  }

  /// ✅ Save chat to local storage
  Future<void> _saveChat(Chat chat) async {
    if (!_enablePersistence || _chatBox == null || _messagesBox == null) {
      return;
    }

    try {
      // Save chat metadata
      await _chatBox!.put(chat.peerCode, {
        'peerCode': chat.peerCode,
        'displayName': chat.displayName,
        'hasPublicKey': chat.hasPublicKey,
        'lastSeen': chat.lastSeen?.toIso8601String(),
      });

      // Save messages separately
      await _messagesBox!.put(
        chat.peerCode,
        chat.messages.map((m) => m.toJson()).toList(),
      );
    } catch (e) {
      print('⚠️ Failed to save chat: $e');
    }
  }

  /// Setup backend service callbacks
  void _setupBackendCallbacks() {
    if (_backendService == null) return;

    // Message received callback
    _backendService!.onMessageReceived = _handleIncomingMessage;

    // Connection callbacks
    _backendService!.onConnected = () {
      _isConnected = true;
      _updateE2EEStatus(); // Update E2EE status on connection
      print('✅ Connected to backend');
    };

    _backendService!.onDisconnected = () {
      _isConnected = false;
      notifyListeners();
      print('⚠️ Disconnected from backend');
    };

    _backendService!.onError = (error) {
      _errorMessage = error;
      notifyListeners();
      print('❌ Backend error: $error');
    };

    // Typing indicator callback
    _backendService!.onTypingIndicator = (sender, isTyping) {
      if (_chats.containsKey(sender)) {
        _chats[sender]!.isTyping = isTyping;
        notifyListeners();
      }
    };
  }

  /// ✅ Handle incoming message
  void _handleIncomingMessage(Map<String, dynamic> messageData) {
    try {
      final sender = messageData['sender'] as String;
      final timestamp = messageData['timestamp'] as String?;
      final decryptedContent = messageData['decryptedContent'] as String?;

      print('📨 Message from $sender: $decryptedContent');

      // Create message
      final message = Message(
        sender: sender,
        receiver: _anonymousCode!,
        encryptedContent: messageData['encryptedContent'] as String?,
        decryptedContent: decryptedContent,
        timestamp: timestamp != null 
            ? DateTime.parse(timestamp) 
            : DateTime.now(),
        isSent: false,
        messageId: messageData['messageId'] as String?,
      );

      // Ensure chat exists
      if (!_chats.containsKey(sender)) {
        _chats[sender] = Chat(
          peerCode: sender,
          displayName: sender,
          messages: [],
          hasPublicKey: true,
        );
      }

      // Add message to chat
      _chats[sender]!.messages.add(message);
      _chats[sender]!.lastMessage = message;

      // Save to local storage if persistence enabled
      if (_enablePersistence) {
        _saveChat(_chats[sender]!);
      }

      notifyListeners();
    } catch (e) {
      print('❌ Failed to handle message: $e');
    }
  }

  /// ✅ Send message to peer
  Future<void> sendMessage(String peerCode, String text) async {
    if (_backendService == null || !_isInitialized) {
      throw Exception('Service not initialized');
    }

    try {
      // Ensure chat exists
      await ensureChatExists(peerCode);

      // Create optimistic message
      final message = Message(
        sender: _anonymousCode!,
        receiver: peerCode,
        decryptedContent: text,
        timestamp: DateTime.now(),
        isSent: true,
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        status: MessageStatus.sending,
      );

      // Add to chat
      _chats[peerCode]!.messages.add(message);
      _chats[peerCode]!.lastMessage = message;
      
      // Save to local storage if persistence enabled
      if (_enablePersistence) {
        await _saveChat(_chats[peerCode]!);
      }
      
      notifyListeners();

      // Send via backend
      await _backendService!.sendMessage(peerCode, text);

      // Update message status
      message.status = MessageStatus.sent;
      
      if (_enablePersistence) {
        await _saveChat(_chats[peerCode]!);
      }
      
      notifyListeners();

      print('✅ Message sent to $peerCode');
    } catch (e) {
      print('❌ Failed to send message: $e');
      
      // Update message status to failed
      if (_chats[peerCode]?.lastMessage != null) {
        _chats[peerCode]!.lastMessage!.status = MessageStatus.failed;
        notifyListeners();
      }
      
      rethrow;
    }
  }

  /// ✅ Send typing indicator
  void sendTypingIndicator(String peerCode, bool isTyping) {
    if (_backendService == null || !_isInitialized) return;

    try {
      _backendService!.sendTypingIndicator(peerCode, isTyping);
    } catch (e) {
      print('⚠️ Failed to send typing indicator: $e');
    }
  }

  /// ✅ Ensure chat exists for peer
  Future<void> ensureChatExists(String peerCode) async {
    if (_chats.containsKey(peerCode)) {
      return;
    }

    // Check if we have public key
    final hasKey = await hasPeerPublicKey(peerCode);

    // Create chat
    _chats[peerCode] = Chat(
      peerCode: peerCode,
      displayName: peerCode,
      messages: [],
      hasPublicKey: hasKey,
    );

    // Save to local storage if persistence enabled
    if (_enablePersistence) {
      await _saveChat(_chats[peerCode]!);
    }

    notifyListeners();
    print('✅ Chat created for $peerCode');
  }

  /// ✅ Connect to peer
  Future<void> connectToPeer(String peerCode, String publicKey) async {
    if (_backendService == null || !_isInitialized) {
      throw Exception('Service not initialized');
    }

    try {
      print('🔗 Connecting to peer: $peerCode');

      // Store public key
      await _backendService!.storePeerPublicKey(peerCode, publicKey);

      // Update E2EE status after storing key
      await _updateE2EEStatus();

      // Create or update chat
      if (!_chats.containsKey(peerCode)) {
        _chats[peerCode] = Chat(
          peerCode: peerCode,
          displayName: peerCode,
          messages: [],
          hasPublicKey: true,
        );
      } else {
        _chats[peerCode]!.hasPublicKey = true;
      }

      // Save to local storage if persistence enabled
      if (_enablePersistence) {
        await _saveChat(_chats[peerCode]!);
      }

      notifyListeners();
      print('✅ Connected to $peerCode');
    } catch (e) {
      print('❌ Failed to connect to peer: $e');
      rethrow;
    }
  }

  /// ✅ Get public key methods
  Future<String?> getMyPublicKey() async {
    if (_backendService == null) return null;
    return await _backendService!.getPublicKey();
  }

  Future<String?> getPeerPublicKey(String peerCode) async {
    if (_backendService == null) return null;
    return await _backendService!.getPeerPublicKey(peerCode);
  }

  Future<bool> hasPeerPublicKey(String peerCode) async {
    if (_backendService == null) return false;
    return await _backendService!.hasPeerPublicKey(peerCode);
  }

  /// ✅ Get specific chat
  Chat? getChat(String peerCode) {
    return _chats[peerCode];
  }

  /// ✅ Get chat messages
  List<Message> getChatMessages(String peerCode) {
    return _chats[peerCode]?.messages ?? [];
  }

  /// ✅ Delete chat
  Future<void> deleteChat(String peerCode) async {
    _chats.remove(peerCode);
    
    // Remove from storage if persistence enabled
    if (_enablePersistence && _chatBox != null && _messagesBox != null) {
      await _chatBox!.delete(peerCode);
      await _messagesBox!.delete(peerCode);
    }
    
    notifyListeners();
  }

  /// ✅ Clear all chats
  Future<void> clearAllChats() async {
    _chats.clear();
    
    // Clear storage if persistence enabled
    if (_enablePersistence && _chatBox != null && _messagesBox != null) {
      await _chatBox!.clear();
      await _messagesBox!.clear();
    }
    
    notifyListeners();
  }

  /// ✅ Clear local data only (keep backend state)
  Future<void> clearLocalData() async {
    if (!_enablePersistence) return;
    
    _chats.clear();
    
    if (_chatBox != null) await _chatBox!.clear();
    if (_messagesBox != null) await _messagesBox!.clear();
    
    notifyListeners();
    print('🧹 Local storage cleared');
  }

  /// ✅ Emergency clear keys
  void emergencyClearKeys() {
    if (_backendService != null) {
      _backendService!.emergencyClearKeys();
      _isE2EEActive = false;
      print('🚨 Emergency: All keys cleared');
      notifyListeners();
    }
  }

  /// ✅ Refresh E2EE status (call this after key operations)
  Future<void> refreshE2EEStatus() async {
    await _updateE2EEStatus();
    notifyListeners();
  }

  /// ✅ Logout
  Future<void> logout() async {
    try {
      if (_backendService != null) {
        await _backendService!.logout();
      }

      // Clear state
      _chats.clear();
      _anonymousCode = null;
      _isInitialized = false;
      _isConnected = false;
      _errorMessage = null;

      // Close storage boxes
      if (_enablePersistence) {
        await _chatBox?.close();
        await _messagesBox?.close();
        _chatBox = null;
        _messagesBox = null;
      }

      notifyListeners();
      print('👋 Logged out');
    } catch (e) {
      print('⚠️ Logout error: $e');
    }
  }

  /// ✅ Retry initialization after failure
  Future<void> retryInitialization(
    String baseUrl, 
    bool useTor, 
    bool enablePersistence,
  ) async {
    // Reset state
    _isInitialized = false;
    _isInitializing = false;
    _errorMessage = null;
    _backendService = null;

    // Try again
    await initialize(
      baseUrl: baseUrl, 
      useTor: useTor,
      enablePersistence: enablePersistence,
    );
  }

  @override
  void dispose() {
    _backendService?.dispose();
    _chatBox?.close();
    _messagesBox?.close();
    super.dispose();
  }

  /// ✅ Get connection status details
  Map<String, dynamic> get connectionStatus => {
    'initialized': _isInitialized,
    'connected': _isConnected,
    'torConnected': _isTorConnected,
    'e2eeActive': _isE2EEActive,
    'anonymousCode': _anonymousCode,
    'chatsCount': _chats.length,
    'hasError': _errorMessage != null,
    'error': _errorMessage,
    'persistenceEnabled': _enablePersistence,
  };
}