import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/queries.dart';
import '../../core/theme.dart';
import '../../core/me_provider.dart';
import 'audio_player_widget.dart';

class ClipCard extends StatefulWidget {
  final Map<String, dynamic> clip;
  final VoidCallback? onReply;

  const ClipCard({super.key, required this.clip, this.onReply});

  @override
  State<ClipCard> createState() => _ClipCardState();
}

class _ClipCardState extends State<ClipCard> {
  bool _deleted = false;

  String _timeAgo(String? insertedAt) {
    if (insertedAt == null) return '';
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

  String? _expiryLabel(String? expiresAt) {
    if (expiresAt == null) return null;
    try {
      final dt = DateTime.parse(expiresAt.replaceAll(' ', 'T'));
      final hoursLeft = dt.difference(DateTime.now()).inHours;
      if (hoursLeft <= 0) return null;
      return '${hoursLeft}h left';
    } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    if (_deleted) return const SizedBox.shrink();
    final clip = widget.clip;
    final user = clip['user'] as Map<String, dynamic>;
    final waveformRaw = clip['waveform'] as String?;
    final waveform = waveformRaw != null
        ? waveformRaw.split(',').map((e) => double.tryParse(e) ?? 0.0).toList()
        : null;
    final expiryLabel = _expiryLabel(clip['expiresAt'] as String?);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 0.5),
      ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Expiry bar — ember→gold gradient (spec 7.5)
            if (expiryLabel != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.accent, AppTheme.gold],
                      stops: [_expiryProgress(clip['expiresAt'] as String?) ?? 1.0, 1.0],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/profile/${user['username']}'),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.accent.withOpacity(0.2),
                          child: Text(
                            (user['name'] ?? user['username'] ?? '?')[0].toUpperCase(),
                            style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 14),
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
                      // Expiry tag (spec 7.5: "Nh left")
                      if (expiryLabel != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                          ),
                          child: Text(expiryLabel, style: TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      ],
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => context.push('/clip/${clip['id']}'),
                        child: Text(_timeAgo(clip['insertedAt'] as String?), style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      // Own clip actions — absorb tap so card doesn't navigate
                      GestureDetector(
                        onTap: () {}, // absorb
                        child: _OwnClipActions(
                          clip: clip,
                          onDeleted: () => setState(() => _deleted = true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Audio player
                  AudioPlayerWidget(
                    url: clip['audioPath'] ?? '',
                    waveform: waveform,
                    duration: clip['duration'] as int?,
                  ),
                  const SizedBox(height: 12),
                  // Actions row
                  Row(
                    children: [
                      // Reply
                      _ActionBtn(
                        icon: Icons.chat_bubble_outline_rounded,
                        count: clip['repliesCount'] ?? 0,
                        onTap: widget.onReply ?? () => context.push('/clip/${clip['id']}'),
                      ),
                      const SizedBox(width: 16),
                      // Whisper — private reply (spec 9.2)
                      _ActionBtn(
                        icon: Icons.record_voice_over_outlined,
                        count: 0,
                        label: 'Whisper',
                        onTap: () => context.push('/clip/${clip['id']}'),
                      ),
                      const Spacer(),
                      // Pulse button — no count shown (RULE_003)
                      _PulseBtn(
                        clipId: clip['id'] as String,
                        hasPulsed: clip['hasPulsed'] as bool? ?? false,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
    );
  }

  double? _expiryProgress(String? expiresAt) {
    if (expiresAt == null) return null;
    try {
      final dt = DateTime.parse(expiresAt.replaceAll(' ', 'T'));
      final hoursLeft = dt.difference(DateTime.now()).inHours;
      return (hoursLeft / 72).clamp(0.0, 1.0);
    } catch (_) { return null; }
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  final String? label;

  const _ActionBtn({required this.icon, required this.count, required this.onTap, this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(label ?? '$count', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// Pulse button — anonymous, no count (RULE_003)
class _PulseBtn extends StatefulWidget {
  final String clipId;
  final bool hasPulsed;

  const _PulseBtn({required this.clipId, required this.hasPulsed});

  @override
  State<_PulseBtn> createState() => _PulseBtnState();
}

class _PulseBtnState extends State<_PulseBtn> {
  late bool _pulsed;

  @override
  void initState() {
    super.initState();
    _pulsed = widget.hasPulsed;
  }

  Future<void> _pulse() async {
    if (_pulsed) return; // Cannot un-pulse per spec
    final client = GraphQLProvider.of(context).value;
    final result = await client.mutate(MutationOptions(
      document: gql(kPulse),
      variables: {'postId': widget.clipId},
    ));
    if (!result.hasException && mounted) {
      setState(() => _pulsed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pulse,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _pulsed ? AppTheme.accent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _pulsed ? AppTheme.accent.withOpacity(0.4) : AppTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart_rounded, size: 16, color: _pulsed ? AppTheme.accent : AppTheme.textMuted),
            // No count shown — RULE_003
          ],
        ),
      ),
    );
  }
}

/// Shows preserve/delete for own clips only (spec 4.3, 9.3)
class _OwnClipActions extends StatelessWidget {
  final Map<String, dynamic> clip;
  final VoidCallback? onDeleted;
  const _OwnClipActions({required this.clip, this.onDeleted});

  Future<void> _preserve(BuildContext context) async {
    final client = GraphQLProvider.of(context).value;
    final result = await client.mutate(MutationOptions(
      document: gql(kPreservePost),
      variables: {'id': clip['id']},
    ));
    if (!context.mounted) return;
    if (result.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.exception?.graphqlErrors.firstOrNull?.message ?? 'Failed')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice preserved ✓')),
      );
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete clip?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final client = GraphQLProvider.of(context).value;
    final result = await client.mutate(MutationOptions(
      document: gql(kDeleteClip),
      variables: {'id': clip['id']},
    ));
    if (!context.mounted) return;
    if (!result.hasException) onDeleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final me = MeProvider.of(context);
    if (me == null) return const SizedBox.shrink();
    final isOwn = me['id'] == clip['user']?['id'];
    if (!isOwn) return const SizedBox.shrink();

    final isEmbers = me['isEmbers'] as bool? ?? false;
    final hasExpiry = clip['expiresAt'] != null;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, size: 18, color: AppTheme.textMuted),
      color: AppTheme.surface,
      onSelected: (v) {
        if (v == 'preserve') _preserve(context);
        if (v == 'delete') _delete(context);
      },
      itemBuilder: (_) => [
        if (isEmbers && hasExpiry)
          const PopupMenuItem(value: 'preserve', child: Text('Preserve voice')),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    );
  }
}
