import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'queries.dart';

/// Handles FCM push notifications (spec 12.2)
class FCMService {
  static Future<void> init(GraphQLClient client) async {
    final messaging = FirebaseMessaging.instance;

    // Request permission
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Get token and register with backend
    final token = await messaging.getToken();
    if (token != null) {
      await _registerToken(client, token);
    }

    // Re-register on token refresh
    messaging.onTokenRefresh.listen((newToken) => _registerToken(client, newToken));

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((message) {
      // Pulse notifications never reveal sender (RULE_003)
      // Just trigger a local notification or update UI state
    });
  }

  static Future<void> _registerToken(GraphQLClient client, String token) async {
    await client.mutate(MutationOptions(
      document: gql(kRegisterFcmToken),
      variables: {'token': token},
    ));
  }
}
