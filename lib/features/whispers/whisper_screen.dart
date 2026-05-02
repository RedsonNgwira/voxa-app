import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/theme.dart';
import '../../core/queries.dart';

class WhisperScreen extends StatefulWidget {
  final String clipId;
  final String? clipOwnerUsername;
  const WhisperScreen({super.key, required this.clipId, this.clipOwnerUsername});

  @override
  State<WhisperScreen> createState() => _WhisperScreenState();
}

class _WhisperScreenState extends State<WhisperScreen> {
  List<Map<String, dynamic>> _whispers = [];
  bool _loading = true;
  final AudioPlayer _player = AudioPlayer();
  int? _playingIndex;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed && mounted) {
        setState(() { _isPlaying = false; _playingIndex = null; });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final client = GraphQLProvider.of(context).value;
    try {
      final result = await client.query(QueryOptions(
        document: gql(kWhispers),
        variables: {'clipId': widget.clipId},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      if (!mounted) return;
      setState(() {
        _whispers = (result.data?['whispers'] as List? ?? [])
            .whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _togglePlay(int index, String audioUrl) async {
    if (_playingIndex == index && _isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
      return;
    }
    await _player.stop();
    await _player.setUrl(audioUrl);
    await _player.play();
    setState(() { _playingIndex = index; _isPlaying = true; });
  }

  String _timeAgo(String insertedAt) {
    try {
      final dt = DateTime.parse(insertedAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Whispers'),
            if (_whispers.isNotEmpty)
              Text('${_whispers.length} private ${_whispers.length == 1 ? 'reply' : 'replies'}',
                  style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _whispers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 56,
                          color: AppTheme.accent.withAlpha(60)),
                      const SizedBox(height: 16),
                      const Text('No whispers yet',
                          style: TextStyle(color: AppTheme.textDim, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('Private replies will appear here',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _whispers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final w = _whispers[i];
                    final user = w['user'] as Map<String, dynamic>?;
                    final name = user?['name'] as String? ??
                        user?['username'] as String? ?? '?';
                    final audioUrl = w['audioPath'] as String? ?? '';
                    final duration = w['duration'] as int? ?? 0;
                    final isPlaying = _playingIndex == i && _isPlaying;

                    return GestureDetector(
                      onTap: () => _togglePlay(i, audioUrl),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? AppTheme.accent.withAlpha(15)
                              : AppTheme.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isPlaying
                                ? AppTheme.accent.withAlpha(80)
                                : AppTheme.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Avatar
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.accent.withAlpha(40),
                              child: Text(
                                name[0].toUpperCase(),
                                style: const TextStyle(
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: Color(0xFFF0E6D3))),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.lock_rounded,
                                          size: 11, color: AppTheme.textMuted),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${duration}s · ${_timeAgo(w['insertedAt'] as String? ?? '')}',
                                    style: const TextStyle(
                                        color: AppTheme.textDim, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            // Play button
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isPlaying
                                    ? AppTheme.accent
                                    : AppTheme.surface,
                              ),
                              child: Icon(
                                isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: isPlaying
                                    ? Colors.white
                                    : AppTheme.accent,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
