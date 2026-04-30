import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/queries.dart';
import '../../core/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(document: gql(kNotifications), fetchPolicy: FetchPolicy.networkOnly));
    if (!mounted) return;
    setState(() {
      if (!result.hasException) _notifications = (result.data!['notifications'] as List).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _notifications.isEmpty
              ? Center(child: Text('No notifications yet', style: Theme.of(context).textTheme.bodyMedium))
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (_, i) => _NotifTile(notif: _notifications[i]),
                ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final Map<String, dynamic> notif;
  const _NotifTile({required this.notif});

  @override
  Widget build(BuildContext context) {
    final type = notif['type'] as String? ?? '';

    // Icon + color per type
    final (icon, color) = switch (type) {
      'PULSE' => (Icons.show_chart_rounded, const Color(0xFFFF6B6B)),
      'WHISPER' => (Icons.chat_bubble_outline_rounded, Colors.purple),
      'EXPIRY_WARNING' => (Icons.timer_outlined, AppTheme.accent),
      'CIRCLE_ACTIVITY' => (Icons.group_outlined, Colors.green),
      _ => (Icons.notifications_outlined, AppTheme.textMuted),
    };

    // Message per spec 7.12 — Pulse never reveals sender (RULE_003)
    final message = switch (type) {
      'PULSE' => 'Someone felt your voice',
      'WHISPER' => notif['message'] as String? ?? 'Someone whispered to you',
      'EXPIRY_WARNING' => 'Your voice expires in 6 hours',
      'CIRCLE_ACTIVITY' => notif['message'] as String? ?? 'New voice in your circle',
      _ => notif['message'] as String? ?? '',
    };

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.15),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(message, style: Theme.of(context).textTheme.bodyLarge),
      subtitle: notif['insertedAt'] != null
          ? Text(_timeAgo(notif['insertedAt'] as String), style: Theme.of(context).textTheme.bodyMedium)
          : null,
    );
  }

  String _timeAgo(String insertedAt) {
    try {
      final dt = DateTime.parse(insertedAt.replaceAll(' ', 'T'));
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
  }
}
