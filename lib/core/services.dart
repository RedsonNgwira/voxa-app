import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

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
    notifyListeners();
  }

  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kTokenKey, token);
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kTokenKey);
    notifyListeners();
  }
}
