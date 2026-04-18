import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/queries.dart';
import '../../core/theme.dart';
import 'audio_player_widget.dart';

class ClipCard extends StatelessWidget {
  final Map<String, dynamic> clip;
  final VoidCallback? onReply;

  const ClipCard({super.key, required this.clip, this.onReply});

  String _timeAgo(String insertedAt) {
    try {
      final dt = DateTime.parse(insertedAt.replaceAll(' ', 'T'));
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'now';
      if (diff.inHours < 1) return '${diff.inMinutes}m';
      if (diff.inDays < 1) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${(diff.inDays / 7).floor()}w';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final user = clip['user'] as Map<String, dynamic>;
    final waveform = (clip['waveform'] as List?)?.map((e) => (e as num).toDouble()).toList();

    return GestureDetector(
      onTap: () => context.push('/clip/${clip['id']}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.push('/profile/${user['username']}'),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.accent.withOpacity(0.2),
                    child: Text(
                      (user['name'] ?? user['username'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['name'] ?? user['username'] ?? '', style: Theme.of(context).textTheme.titleMedium),
                      Text('@${user['username'] ?? ''}', style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                if (clip['topic'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(clip['topic'], style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(width: 8),
                Text(_timeAgo(clip['insertedAt'] ?? ''), style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 14),
            // Audio player
            AudioPlayerWidget(
              url: clip['audioPath'] ?? '',
              waveform: waveform,
              duration: clip['duration'] as int?,
            ),
            const SizedBox(height: 14),
            // Actions
            Row(
              children: [
                _ActionBtn(
                  icon: Icons.reply_rounded,
                  count: clip['repliesCount'] ?? 0,
                  onTap: onReply ?? () => context.push('/clip/${clip['id']}'),
                ),
                const SizedBox(width: 20),
                _ReactBtn(clipId: clip['id'], type: 'echo', icon: Icons.repeat_rounded, count: clip['echoCount'] ?? 0),
                const SizedBox(width: 20),
                _ReactBtn(clipId: clip['id'], type: 'felt', icon: Icons.favorite_border_rounded, count: clip['feltCount'] ?? 0),
                const Spacer(),
                Text('${clip['playsCount'] ?? 0} plays', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  const _ActionBtn({required this.icon, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text('$count', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ReactBtn extends StatefulWidget {
  final String clipId;
  final String type;
  final IconData icon;
  final int count;

  const _ReactBtn({required this.clipId, required this.type, required this.icon, required this.count});

  @override
  State<_ReactBtn> createState() => _ReactBtnState();
}

class _ReactBtnState extends State<_ReactBtn> {
  late int _count;
  bool _reacted = false;

  @override
  void initState() {
    super.initState();
    _count = widget.count;
  }

  Future<void> _react() async {
    final client = GraphQLProvider.of(context).value;
    final result = await client.mutate(MutationOptions(
      document: gql(kReact),
      variables: {'clipId': widget.clipId, 'type': widget.type},
    ));
    if (result.hasException || !mounted) return;
    final data = result.data!['react'];
    setState(() {
      _reacted = data['reacted'] as bool;
      _count = (widget.type == 'echo' ? data['echoCount'] : data['feltCount']) as int;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _react,
      child: Row(
        children: [
          Icon(widget.icon, size: 18, color: _reacted ? AppTheme.accent : AppTheme.textMuted),
          const SizedBox(width: 4),
          Text('$_count', style: TextStyle(color: _reacted ? AppTheme.accent : AppTheme.textMuted, fontSize: 13)),
        ],
      ),
    );
  }
}
