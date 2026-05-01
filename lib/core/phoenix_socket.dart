import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Phoenix Channel client for real-time events
/// Connects to feed:{user_id} and pulse:{user_id} channels
class PhoenixSocket {
  static const _wsUrl = 'wss://voxa.gigalixirapp.com/api/socket/websocket';

  WebSocketChannel? _channel;
  String? _token;
  int _ref = 0;
  final Map<String, StreamController<Map<String, dynamic>>> _topics = {};
  final Set<String> _joinedTopics = {};
  Timer? _heartbeat;
  bool _intentionalDisconnect = false;
  int _reconnectAttempts = 0;
  static const _maxReconnectDelay = 30; // seconds

  void connect(String token) {
    _token = token;
    _intentionalDisconnect = false;
    _reconnectAttempts = 0;
    _doConnect();
  }

  void _doConnect() {
    if (_token == null) return;
    try {
      _channel?.sink.close();
      _channel = WebSocketChannel.connect(
        Uri.parse('$_wsUrl?token=$_token&vsn=2.0.0'),
      );
      _channel!.stream.listen(
        _onMessage,
        onDone: _onDone,
        onError: _onError,
        cancelOnError: false,
      );
      _startHeartbeat();

      // Re-join all previously subscribed topics
      for (final topic in _joinedTopics.toList()) {
        _send('phx_join', topic, {});
      }
      _reconnectAttempts = 0;
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void disconnect() {
    _intentionalDisconnect = true;
    _heartbeat?.cancel();
    _channel?.sink.close();
    _channel = null;
    _joinedTopics.clear();
    // Close all topic streams
    for (final controller in _topics.values) {
      controller.close();
    }
    _topics.clear();
  }

  /// Subscribe to a Phoenix channel topic
  Stream<Map<String, dynamic>> subscribe(String topic) {
    if (!_topics.containsKey(topic) || _topics[topic]!.isClosed) {
      _topics[topic] = StreamController.broadcast();
    }
    _joinedTopics.add(topic);
    _send('phx_join', topic, {});
    return _topics[topic]!.stream;
  }

  /// Unsubscribe from a topic
  void unsubscribe(String topic) {
    _send('phx_leave', topic, {});
    _joinedTopics.remove(topic);
    _topics[topic]?.close();
    _topics.remove(topic);
  }

  void _send(String event, String topic, Map<String, dynamic> payload) {
    if (_channel == null) return;
    _ref++;
    try {
      _channel?.sink.add(jsonEncode([null, '$_ref', topic, event, payload]));
    } catch (_) {
      // Channel may be closed
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as List;
      final topic = msg[2] as String;
      final event = msg[3] as String;
      final payload = msg[4] as Map<String, dynamic>;

      if (event == 'phx_reply' || event == 'phx_error' || event == 'phx_close') return;

      final controller = _topics[topic];
      if (controller != null && !controller.isClosed) {
        controller.add({'event': event, 'payload': payload});
      }
    } catch (_) {}
  }

  void _onError(dynamic error) {
    _scheduleReconnect();
  }

  void _onDone() {
    _heartbeat?.cancel();
    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect || _token == null) return;
    _reconnectAttempts++;
    // Exponential backoff: 1s, 2s, 4s, 8s... up to 30s
    final delay = (_reconnectAttempts * 2).clamp(1, _maxReconnectDelay);
    Future.delayed(Duration(seconds: delay), () {
      if (!_intentionalDisconnect && _token != null) {
        _doConnect();
      }
    });
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      _send('heartbeat', 'phoenix', {});
    });
  }

  bool get isConnected => _channel != null;
}

// Singleton
final phoenixSocket = PhoenixSocket();
