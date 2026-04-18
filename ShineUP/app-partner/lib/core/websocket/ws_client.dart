import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Real-time WebSocket client for Shine-Up Partner App
class WSClient {
  WebSocket? _socket;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  bool _isDisposed = false;

  // Event streams
  final _bookingUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationController = StreamController<Map<String, dynamic>>.broadcast();
  final _chatMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _newJobController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<Map<String, dynamic>> get bookingUpdates => _bookingUpdateController.stream;
  Stream<Map<String, dynamic>> get notifications => _notificationController.stream;
  Stream<Map<String, dynamic>> get chatMessages => _chatMessageController.stream;
  Stream<Map<String, dynamic>> get newJobs => _newJobController.stream;
  Stream<bool> get connectionState => _connectionStateController.stream;

  String get _wsUrl {
    return 'wss://shine-up-public-production.up.railway.app/ws';
  }

  /// Connect to WebSocket server
  Future<void> connect() async {
    if (_isDisposed) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) {
      debugPrint('WS: No JWT token, skipping connection');
      return;
    }

    try {
      final url = '$_wsUrl?token=$token';
      debugPrint('WS: Connecting to $url');
      
      _socket = await WebSocket.connect(url);
      _reconnectAttempts = 0;
      _connectionStateController.add(true);
      debugPrint('WS: Connected!');

      _socket!.listen(
        (data) => _handleMessage(data.toString()),
        onError: (error) {
          debugPrint('WS Error: $error');
          _connectionStateController.add(false);
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('WS: Connection closed');
          _connectionStateController.add(false);
          _scheduleReconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('WS: Connection failed: $e');
      _connectionStateController.add(false);
      _scheduleReconnect();
    }
  }

  void _handleMessage(String data) {
    try {
      final msg = jsonDecode(data) as Map<String, dynamic>;
      final type = msg['type'] as String?;
      final payload = msg['payload'] as Map<String, dynamic>?;

      if (payload == null) return;

      switch (type) {
        case 'BOOKING_UPDATE':
          _bookingUpdateController.add(payload);
          break;
        case 'NEW_NOTIFICATION':
          _notificationController.add(payload);
          break;
        case 'CHAT_MESSAGE':
          _chatMessageController.add(payload);
          break;
        case 'NEW_JOB':
          _newJobController.add(payload);
          break;
        case 'CONNECTED':
          debugPrint('WS: Server says: ${payload['message']}');
          break;
      }
    } catch (e) {
      debugPrint('WS: Error parsing message: $e');
    }
  }

  /// Send a chat message via WebSocket
  void sendChatMessage(String bookingId, String message) {
    if (_socket == null) return;
    
    final msg = jsonEncode({
      'type': 'CHAT_MESSAGE',
      'payload': {
        'booking_id': bookingId,
        'message': message,
      },
    });
    _socket!.add(msg);
  }

  void _scheduleReconnect() {
    if (_isDisposed || _reconnectAttempts >= _maxReconnectAttempts) return;
    
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: (1 << _reconnectAttempts).clamp(1, 30));
    _reconnectAttempts++;
    
    debugPrint('WS: Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    _reconnectTimer = Timer(delay, connect);
  }

  /// Disconnect and clean up
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _socket?.close();
    _bookingUpdateController.close();
    _notificationController.close();
    _chatMessageController.close();
    _newJobController.close();
    _connectionStateController.close();
  }
}
