import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'constants.dart';
import 'phoenix_socket.dart';

class GraphQLService {
  static ValueNotifier<GraphQLClient> clientNotifier(String? token) {
    final authLink = AuthLink(getToken: () async => token != null ? 'Bearer $token' : null);
    final httpLink = HttpLink(kApiUrl);
    final link = authLink.concat(httpLink);
    return ValueNotifier(
      GraphQLClient(link: link, cache: GraphQLCache(store: InMemoryStore())),
    );
  }
}

class AuthService extends ChangeNotifier {
  String? _token;
  String? get token => _token;
  bool get isLoggedIn => _token != null;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(kTokenKey);
    if (_token != null) _connectSocket();
    notifyListeners();
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kTokenKey, token);
    _connectSocket();
    notifyListeners();
  }

  Future<void> logout() async {
    phoenixSocket.disconnect();
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kTokenKey);
    notifyListeners();
  }

  void _connectSocket() {
    if (_token != null) phoenixSocket.connect(_token!);
  }
}

/// Hive-based feed cache (spec 6.2 — offline queue)
class FeedCache {
  static const _boxName = 'feed_cache';

  static Future<void> save(List<Map<String, dynamic>> clips) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.put('clips', jsonEncode(clips));
  }

  static Future<List<Map<String, dynamic>>> load() async {
    final box = await Hive.openBox<String>(_boxName);
    final raw = box.get('clips');
    if (raw == null) return [];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  static Future<void> clear() async {
    final box = await Hive.openBox<String>(_boxName);
    await box.clear();
  }
}
