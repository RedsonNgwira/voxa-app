import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'queries.dart';

// Must be top-level for background handler
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  await _showLocalNotification(message);
}

final _localNotifications = FlutterLocalNotificationsPlugin();

// Navigation callback — set from main.dart after router is ready
void Function(String? postId, String? type)? onNotificationTap;

Future<void> _showLocalNotification(RemoteMessage message) async {
  const androidChannel = AndroidNotificationChannel(
    'voxa_channel',
    'Voxa Notifications',
    description: 'Voice activity notifications',
    importance: Importance.high,
  );

  await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidChannel);

  final title = message.notification?.title ?? _titleFromData(message.data);
  final body = message.notification?.body ?? '';

  await _localNotifications.show(
    message.hashCode,
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        androidChannel.id,
        androidChannel.name,
        channelDescription: androidChannel.description,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
    payload: '${message.data['type'] ?? ''}|${message.data['campfire_id'] ?? message.data['post_id'] ?? ''}',
  );
}

String _titleFromData(Map<String, dynamic> data) {
  return switch (data['type']) {
    'PULSE' => 'Someone felt your voice',
    'WHISPER' => 'New whisper',
    'EXPIRY_WARNING' => 'Your voice expires in 6 hours',
    'CIRCLE_ACTIVITY' => 'New voice in your circle',
    _ => 'Voxa',
  };
}

class FCMService {
  static Future<void> init(GraphQLClient client) async {
    final messaging = FirebaseMessaging.instance;

    // Request permission
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Init local notifications
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // User tapped notification — navigate to the clip
        final parts = (details.payload ?? '').split('|');
        final type = parts.isNotEmpty ? parts[0] : null;
        final postId = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
        onNotificationTap?.call(postId, type);
      },
    );

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

    // Get token and register with backend
    final token = await messaging.getToken();
    if (token != null) await _registerToken(client, token);
    messaging.onTokenRefresh.listen((t) => _registerToken(client, t));

    // Foreground messages — show local notification
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    // App opened from notification (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final type = message.data['type'] as String?;
      final postId = type == 'CAMPFIRE'
          ? message.data['campfire_id'] as String?
          : message.data['post_id'] as String?;
      onNotificationTap?.call(postId, type);
    });

    // App launched from terminated state via notification
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      final postId = initial.data['post_id'] as String?;
      final type = initial.data['type'] as String?;
      // Delay to let router initialize
      Future.delayed(const Duration(seconds: 1), () {
        onNotificationTap?.call(postId, type);
      });
    }
  }

  static Future<void> _registerToken(GraphQLClient client, String token) async {
    await client.mutate(MutationOptions(
      document: gql(kRegisterFcmToken),
      variables: {'token': token},
    ));
  }
}
