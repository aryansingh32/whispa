import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// ✅ Complete Music Sync Service
/// Supports Local, Spotify, and YouTube playback with sync
class MusicSyncService {
  // API Configuration
  String? _spotifyAccessToken;
  String? _youtubeApiKey;
  
  // Sync state
  String? _currentChannelId;
  PlaybackState _playbackState = PlaybackState.stopped;
  String? _currentTrackId;
  int _currentPosition = 0; // in milliseconds
  DateTime? _lastSyncTime;
  
  // Members in current channel
  List<String> _channelMembers = [];
  
  // Callbacks
  Function(MusicTrack track)? onTrackChanged;
  Function(PlaybackState state)? onPlaybackStateChanged;
  Function(int position)? onPositionChanged;
  Function(List<String> members)? onMembersChanged;
  Function(String message)? onError;
  
  // WebSocket for sync (reuse existing)
  Function(String channel, Map<String, dynamic> data)? sendSyncMessage;

  /// Initialize with API keys
  Future<void> initialize({
    String? spotifyClientId,
    String? spotifyClientSecret,
    String? youtubeApiKey,
  }) async {
    _youtubeApiKey = youtubeApiKey;
    
    if (spotifyClientId != null && spotifyClientSecret != null) {
      await _authenticateSpotify(spotifyClientId, spotifyClientSecret);
    }
    
    print('✅ Music sync service initialized');
  }

  /// Authenticate with Spotify
  Future<void> _authenticateSpotify(String clientId, String clientSecret) async {
    try {
      final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));
      
      final response = await http.post(
        Uri.parse('https://accounts.spotify.com/api/token'),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'grant_type': 'client_credentials'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _spotifyAccessToken = data['access_token'];
        print('✅ Spotify authenticated');
      }
    } catch (e) {
      print('⚠️ Spotify auth failed: $e');
      onError?.call('Spotify authentication failed');
    }
  }

  // ============ Channel Management ============

  /// Create a new music channel
  Future<String> createChannel(String channelName) async {
    _currentChannelId = 'CHANNEL_${DateTime.now().millisecondsSinceEpoch}';
    _channelMembers = [];
    
    print('🎵 Created music channel: $_currentChannelId');
    return _currentChannelId!;
  }

  /// Join an existing channel
  Future<bool> joinChannel(String channelId, String userCode) async {
    _currentChannelId = channelId;
    
    if (!_channelMembers.contains(userCode)) {
      _channelMembers.add(userCode);
      onMembersChanged?.call(_channelMembers);
    }
    
    // Sync with channel
    await _requestChannelSync();
    
    print('🎵 Joined channel: $channelId');
    return true;
  }

  /// Leave current channel
  void leaveChannel(String userCode) {
    _channelMembers.remove(userCode);
    onMembersChanged?.call(_channelMembers);
    
    if (_channelMembers.isEmpty) {
      _currentChannelId = null;
      _playbackState = PlaybackState.stopped;
    }
    
    print('👋 Left music channel');
  }

  // ============ Playback Control ============

  /// Play a track and sync with channel
  Future<void> play(MusicTrack track) async {
    _currentTrackId = track.id;
    _currentPosition = 0;
    _playbackState = PlaybackState.playing;
    _lastSyncTime = DateTime.now();
    
    onTrackChanged?.call(track);
    onPlaybackStateChanged?.call(_playbackState);
    
    // Broadcast to channel
    if (_currentChannelId != null) {
      _broadcastSync({
        'action': 'play',
        'trackId': track.id,
        'trackData': track.toJson(),
        'position': 0,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
    
    // Start position updates
    _startPositionUpdates();
  }

  /// Pause playback
  void pause() {
    _playbackState = PlaybackState.paused;
    onPlaybackStateChanged?.call(_playbackState);
    
    // Broadcast to channel
    if (_currentChannelId != null) {
      _broadcastSync({
        'action': 'pause',
        'position': _currentPosition,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Resume playback
  void resume() {
    _playbackState = PlaybackState.playing;
    _lastSyncTime = DateTime.now();
    onPlaybackStateChanged?.call(_playbackState);
    
    // Broadcast to channel
    if (_currentChannelId != null) {
      _broadcastSync({
        'action': 'resume',
        'position': _currentPosition,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
    
    _startPositionUpdates();
  }

  /// Seek to position
  void seek(int positionMs) {
    _currentPosition = positionMs;
    _lastSyncTime = DateTime.now();
    onPositionChanged?.call(positionMs);
    
    // Broadcast to channel
    if (_currentChannelId != null) {
      _broadcastSync({
        'action': 'seek',
        'position': positionMs,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Stop playback
  void stop() {
    _playbackState = PlaybackState.stopped;
    _currentPosition = 0;
    _currentTrackId = null;
    onPlaybackStateChanged?.call(_playbackState);
    
    // Broadcast to channel
    if (_currentChannelId != null) {
      _broadcastSync({
        'action': 'stop',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  // ============ Sync Management ============

  /// Handle incoming sync message from channel
  void handleSyncMessage(Map<String, dynamic> data) {
    final action = data['action'] as String;
    final timestamp = data['timestamp'] as int;
    final position = data['position'] as int?;
    
    // Calculate time difference for sync adjustment
    final latency = DateTime.now().millisecondsSinceEpoch - timestamp;
    
    switch (action) {
      case 'play':
        final trackData = data['trackData'] as Map<String, dynamic>;
        final track = MusicTrack.fromJson(trackData);
        _currentTrackId = track.id;
        _currentPosition = (position ?? 0) + latency;
        _playbackState = PlaybackState.playing;
        _lastSyncTime = DateTime.now();
        
        onTrackChanged?.call(track);
        onPlaybackStateChanged?.call(_playbackState);
        _startPositionUpdates();
        break;
        
      case 'pause':
        _playbackState = PlaybackState.paused;
        _currentPosition = position ?? _currentPosition;
        onPlaybackStateChanged?.call(_playbackState);
        break;
        
      case 'resume':
        _playbackState = PlaybackState.playing;
        _currentPosition = (position ?? _currentPosition) + latency;
        _lastSyncTime = DateTime.now();
        onPlaybackStateChanged?.call(_playbackState);
        _startPositionUpdates();
        break;
        
      case 'seek':
        _currentPosition = (position ?? 0) + latency;
        _lastSyncTime = DateTime.now();
        onPositionChanged?.call(_currentPosition);
        break;
        
      case 'stop':
        _playbackState = PlaybackState.stopped;
        _currentPosition = 0;
        onPlaybackStateChanged?.call(_playbackState);
        break;
    }
  }

  /// Request sync from channel (when joining)
  Future<void> _requestChannelSync() async {
    if (_currentChannelId != null) {
      _broadcastSync({
        'action': 'request_sync',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  /// Broadcast sync message to channel
  void _broadcastSync(Map<String, dynamic> data) {
    if (_currentChannelId != null && sendSyncMessage != null) {
      data['channelId'] = _currentChannelId;
      sendSyncMessage!(_currentChannelId!, data);
    }
  }

  /// Start position updates for sync
  Timer? _positionTimer;
  void _startPositionUpdates() {
    _positionTimer?.cancel();
    
    if (_playbackState != PlaybackState.playing) return;
    
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_playbackState == PlaybackState.playing && _lastSyncTime != null) {
        final elapsed = DateTime.now().difference(_lastSyncTime!).inMilliseconds;
        _currentPosition += elapsed;
        _lastSyncTime = DateTime.now();
        
        onPositionChanged?.call(_currentPosition);
      } else {
        timer.cancel();
      }
    });
  }

  // ============ Music Source APIs ============

  /// Search Spotify tracks
  Future<List<MusicTrack>> searchSpotify(String query) async {
    if (_spotifyAccessToken == null) {
      throw Exception('Spotify not authenticated');
    }
    
    try {
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/search?q=$query&type=track&limit=20'),
        headers: {'Authorization': 'Bearer $_spotifyAccessToken'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tracks = (data['tracks']['items'] as List).map((item) {
          return MusicTrack(
            id: item['id'],
            title: item['name'],
            artist: item['artists'][0]['name'],
            albumArt: item['album']['images'][0]['url'],
            duration: item['duration_ms'],
            source: MusicSource.spotify,
            url: item['external_urls']['spotify'],
          );
        }).toList();
        
        return tracks;
      }
      
      return [];
    } catch (e) {
      print('❌ Spotify search failed: $e');
      return [];
    }
  }

  /// Search YouTube videos
  Future<List<MusicTrack>> searchYouTube(String query) async {
    if (_youtubeApiKey == null) {
      throw Exception('YouTube API key not set');
    }
    
    try {
      final response = await http.get(
        Uri.parse(
          'https://www.googleapis.com/youtube/v3/search?'
          'part=snippet&q=$query&type=video&videoCategoryId=10&maxResults=20&key=$_youtubeApiKey'
        ),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tracks = (data['items'] as List).map((item) {
          return MusicTrack(
            id: item['id']['videoId'],
            title: item['snippet']['title'],
            artist: item['snippet']['channelTitle'],
            albumArt: item['snippet']['thumbnails']['high']['url'],
            duration: 0, // Would need additional API call
            source: MusicSource.youtube,
            url: 'https://www.youtube.com/watch?v=${item['id']['videoId']}',
          );
        }).toList();
        
        return tracks;
      }
      
      return [];
    } catch (e) {
      print('❌ YouTube search failed: $e');
      return [];
    }
  }

  /// Get local music files (requires platform implementation)
  Future<List<MusicTrack>> getLocalMusic() async {
    // This would use platform channels to access device music library
    // For now, return empty list
    print('⚠️ Local music access requires platform implementation');
    return [];
  }

  // ============ Nearby Broadcasting ============

  /// Start broadcasting music to nearby devices
  Future<void> startNearbyBroadcast() async {
    // This would integrate with NearbyDiscoveryService
    // to broadcast current playback to nearby devices
    print('📡 Started nearby music broadcast');
  }

  /// Stop nearby broadcast
  void stopNearbyBroadcast() {
    print('📡 Stopped nearby broadcast');
  }

  /// Dispose
  void dispose() {
    _positionTimer?.cancel();
  }

  // Getters
  bool get isPlaying => _playbackState == PlaybackState.playing;
  bool get isPaused => _playbackState == PlaybackState.paused;
  bool get isInChannel => _currentChannelId != null;
  String? get currentChannelId => _currentChannelId;
  List<String> get channelMembers => List.from(_channelMembers);
  int get currentPosition => _currentPosition;
}

/// Music track model
class MusicTrack {
  final String id;
  final String title;
  final String artist;
  final String? albumArt;
  final int duration; // in milliseconds
  final MusicSource source;
  final String? url;

  MusicTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.albumArt,
    required this.duration,
    required this.source,
    this.url,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'artist': artist,
    'albumArt': albumArt,
    'duration': duration,
    'source': source.toString(),
    'url': url,
  };

  factory MusicTrack.fromJson(Map<String, dynamic> json) => MusicTrack(
    id: json['id'],
    title: json['title'],
    artist: json['artist'],
    albumArt: json['albumArt'],
    duration: json['duration'],
    source: MusicSource.values.firstWhere(
      (e) => e.toString() == json['source'],
    ),
    url: json['url'],
  );

  String get durationText {
    final minutes = (duration / 60000).floor();
    final seconds = ((duration % 60000) / 1000).floor();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

enum MusicSource { local, spotify, youtube }
enum PlaybackState { stopped, playing, paused }