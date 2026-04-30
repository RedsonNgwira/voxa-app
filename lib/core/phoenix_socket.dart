import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Phoenix Channel client for real-time events (spec 5.1)
/// Connects to feed:{user_id} and pulse:{user_id} channels
class PhoenixSocket {
  static const _wsUrl = 'wss://voxa.gigalixirapp.com/api/socket/websocket';

  WebSocketChannel? _channel;
  String? _token;
  int _ref = 0;
  final Map<String, StreamController<Map<String, dynamic>>> _topics = {};
  Timer? _heartbeat;

  void connect(String token) {
    _token = token;
    _channel = WebSocketChannel.connect(Uri.parse('$_wsUrl?token=$token&vsn=2.0.0'));
    _channel!.stream.listen(_onMessage, onDone: _onDone);
    _startHeartbeat();
  }

  void disconnect() {
    _heartbeat?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  /// Subscribe to a Phoenix channel topic
  Stream<Map<String, dynamic>> subscribe(String topic) {
    _topics[topic] ??= StreamController.broadcast();
    _send('phx_join', topic, {});
    return _topics[topic]!.stream;
  }

  void _send(String event, String topic, Map<String, dynamic> payload) {
    _ref++;
    _channel?.sink.add(jsonEncode([null, '$_ref', topic, event, payload]));
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as List;
      final topic = msg[2] as String;
      final event = msg[3] as String;
      final payload = msg[4] as Map<String, dynamic>;

      if (event == 'phx_reply' || event == 'phx_error') return;

      _topics[topic]?.add({'event': event, 'payload': payload});
    } catch (_) {}
  }

  void _onDone() {
    // Reconnect after 3s
    Future.delayed(const Duration(seconds: 3), () {
      if (_token != null) connect(_token!);
    });
  }

  void _startHeartbeat() {
    _heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
      _send('heartbeat', 'phoenix', {});
    });
  }
}

// Singleton
final phoenixSocket = PhoenixSocket();
