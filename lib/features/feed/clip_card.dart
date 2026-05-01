import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      final diff = DateTime.now().toUtc().difference(dt);
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
      final hoursLeft = dt.difference(DateTime.now().toUtc()).inHours;
      if (hoursLeft <= 0) return null;
      return '${hoursLeft}h left';
    } catch (_) { return null; }
  }

  double? _expiryProgress(String? expiresAt) {
    if (expiresAt == null) return null;
    try {
      final dt = DateTime.parse(expiresAt.replaceAll(' ', 'T'));
      final hoursLeft = dt.difference(DateTime.now().toUtc()).inHours;
      return (hoursLeft / 72).clamp(0.0, 1.0);
    } catch (_) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    if (_deleted) return const SizedBox.shrink();
    final clip = widget.clip;
    final user = clip['user'] as Map<String, dynamic>;
    final waveformRaw = clip['waveform'] as String?;
    final waveform = waveformRaw != null && waveformRaw.isNotEmpty
        ? waveformRaw.split(',').map((e) => (double.tryParse(e) ?? 0.0) / 100.0).toList()
        : null;
    final expiryLabel = _expiryLabel(clip['expiresAt'] as String?);
    final expiryProg = _expiryProgress(clip['expiresAt'] as String?);

    return GestureDetector(
      onTap: () => context.push('/clip/${clip['id']}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Expiry bar
            if (expiryProg != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: LayoutBuilder(
                  builder: (context, constraints) => Container(
                    height: 2.5,
                    width: constraints.maxWidth * expiryProg,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.accent, AppTheme.gold],
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      // Avatar
                      GestureDetector(
                        onTap: () => context.push('/profile/${user['username']}'),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.accent.withOpacity(0.15),
                          child: Text(
                            (user['name'] ?? user['username'] ?? '?')[0].toUpperCase(),
                            style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Name + handle
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/profile/${user['username']}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['name'] ?? user['username'] ?? '',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFF0E6D3)),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              Text(
                                '@${user['username'] ?? ''}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textDim),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Time ago
                      Text(_timeAgo(clip['insertedAt'] as String?),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                      // Own clip actions
                      _OwnClipActions(
                        clip: clip,
                        onDeleted: () => setState(() => _deleted = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Tags row
                  Row(
                    children: [
                      if (clip['topic'] != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.gold.withOpacity(0.15)),
                          ),
                          child: Text(clip['topic'],
                            style: const TextStyle(color: AppTheme.gold, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (expiryLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('\u2B21 ', style: TextStyle(color: AppTheme.accent, fontSize: 8)),
                              Text(expiryLabel,
                                style: const TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Audio player
                  AudioPlayerWidget(
                    url: clip['audioPath'] ?? '',
                    waveform: waveform,
                    duration: clip['duration'] as int?,
                  ),
                  const SizedBox(height: 10),

                  // Actions row
                  Row(
                    children: [
                      // Reply
                      _ActionBtn(
                        icon: Icons.chat_bubble_outline_rounded,
                        count: clip['repliesCount'] ?? 0,
                        onTap: widget.onReply ?? () => context.push('/clip/${clip['id']}'),
                      ),
                      const SizedBox(width: 20),
                      // Whisper
                      GestureDetector(
                        onTap: () => context.push('/clip/${clip['id']}'),
                        child: const Tooltip(
                          message: 'Private voice reply',
                          child: Row(
                            children: [
                              Icon(Icons.record_voice_over_outlined, size: 16, color: AppTheme.textMuted),
                              SizedBox(width: 4),
                              Text('Whisper', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Pulse button — no count shown (RULE_003)
                      _PulseBtn(
                        clipId: clip['id'].toString(),
                        hasPulsed: clip['hasPulsed'] as bool? ?? false,
                      ),
                    ],
                  ),
                ],
              ),
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
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text('$count', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
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

class _PulseBtnState extends State<_PulseBtn> with SingleTickerProviderStateMixin {
  late bool _pulsed;
  late AnimationController _animController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulsed = widget.hasPulsed;
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _pulse() async {
    if (_pulsed) return;
    HapticFeedback.mediumImpact();
    _animController.forward(from: 0);
    setState(() => _pulsed = true); // Optimistic update
    final client = GraphQLProvider.of(context).value;
    final result = await client.mutate(MutationOptions(
      document: gql(kPulse),
      variables: {'postId': widget.clipId},
    ));
    if (result.hasException && mounted) {
      setState(() => _pulsed = false); // Revert on failure
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _pulse,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _pulsed ? AppTheme.pulse.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _pulsed ? AppTheme.pulse.withOpacity(0.3) : AppTheme.border,
              width: _pulsed ? 1.0 : 0.5,
            ),
          ),
          child: Icon(
            _pulsed ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 16,
            color: _pulsed ? AppTheme.pulse : AppTheme.textMuted,
          ),
          // No count shown — RULE_003
        ),
      ),
    );
  }
}

/// Shows preserve/delete for own clips only
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
        SnackBar(
          content: Text(result.exception?.graphqlErrors.firstOrNull?.message ?? 'Failed to preserve'),
          backgroundColor: AppTheme.surface,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: AppTheme.accent, size: 18),
              SizedBox(width: 8),
              Text('Voice preserved'),
            ],
          ),
          backgroundColor: AppTheme.surface,
        ),
      );
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete this voice?'),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) {
        if (v == 'preserve') _preserve(context);
        if (v == 'delete') _delete(context);
      },
      itemBuilder: (_) => [
        if (isEmbers && hasExpiry)
          const PopupMenuItem(value: 'preserve', child: Row(
            children: [
              Icon(Icons.bookmark_border, size: 18, color: AppTheme.accent),
              SizedBox(width: 8),
              Text('Preserve voice'),
            ],
          )),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
  }
}
