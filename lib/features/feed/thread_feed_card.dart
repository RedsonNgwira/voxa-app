import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/theme.dart';

class ThreadFeedCard extends StatefulWidget {
  final Map<String, dynamic> thread;
  const ThreadFeedCard({super.key, required this.thread});

  @override
  State<ThreadFeedCard> createState() => _ThreadFeedCardState();
}

class _ThreadFeedCardState extends State<ThreadFeedCard> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;
  int _currentPart = 0;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _stateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted) {
        _playNext();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _clips =>
      (widget.thread['clips'] as List? ?? []).cast<Map<String, dynamic>>()
        ..sort((a, b) => (a['threadPosition'] as int? ?? 0)
            .compareTo(b['threadPosition'] as int? ?? 0));

  Future<void> _togglePlay() async {
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
      return;
    }
    final clips = _clips;
    if (clips.isEmpty) return;
    if (_player.processingState == ProcessingState.idle) {
      _currentPart = 0;
      await _player.setUrl(clips[0]['audioPath'] as String);
    }
    await _player.play();
    setState(() => _playing = true);
  }

  Future<void> _playNext() async {
    final clips = _clips;
    _currentPart++;
    if (_currentPart < clips.length) {
      await _player.setUrl(clips[_currentPart]['audioPath'] as String);
      await _player.play();
    } else {
      setState(() { _playing = false; _currentPart = 0; });
    }
  }

  String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '${m}m ${s}s' : '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final thread = widget.thread;
    final title = thread['title'] as String? ?? 'Voice Thread';
    final clipCount = thread['clipCount'] as int? ?? 0;
    final totalDuration = thread['totalDuration'] as int? ?? 0;
    final user = thread['user'] as Map<String, dynamic>?;
    final name = user?['name'] as String? ?? user?['username'] as String? ?? '?';
    final username = user?['username'] as String? ?? '';

    return GestureDetector(
      onTap: () => context.push('/thread/${thread['id']}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
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
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.accent.withAlpha(40),
                  child: Text(name[0].toUpperCase(),
                      style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFFF0E6D3))),
                      Text('@$username', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                // Thread badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.gold.withAlpha(60)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.segment_rounded, size: 11, color: AppTheme.gold),
                      SizedBox(width: 4),
                      Text('THREAD', style: TextStyle(color: AppTheme.gold, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Title
            Text(title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFF0E6D3))),
            const SizedBox(height: 6),
            // Meta
            Row(
              children: [
                Icon(Icons.queue_music_rounded, size: 13, color: AppTheme.textDim),
                const SizedBox(width: 4),
                Text('$clipCount ${clipCount == 1 ? 'part' : 'parts'}',
                    style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
                const SizedBox(width: 12),
                Icon(Icons.timer_outlined, size: 13, color: AppTheme.textDim),
                const SizedBox(width: 4),
                Text(_fmtDuration(totalDuration),
                    style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
                if (_playing) ...[
                  const SizedBox(width: 12),
                  Text('Part ${_currentPart + 1} of $clipCount',
                      style: const TextStyle(color: AppTheme.accent, fontSize: 12)),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Play button
            Row(
              children: [
                GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _playing ? AppTheme.accent : AppTheme.surface,
                      border: Border.all(color: AppTheme.accent.withAlpha(80)),
                    ),
                    child: Icon(
                      _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: _playing ? Colors.white : AppTheme.accent,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Part dots
                Expanded(
                  child: Row(
                    children: List.generate(
                      clipCount.clamp(0, 10),
                      (i) => Container(
                        width: 6, height: 6,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == _currentPart && _playing
                              ? AppTheme.accent
                              : i < _currentPart
                                  ? AppTheme.accent.withAlpha(100)
                                  : AppTheme.border,
                        ),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/thread/${thread['id']}'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('View all', style: TextStyle(color: AppTheme.accent, fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
