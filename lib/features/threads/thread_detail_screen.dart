import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/theme.dart';
import '../../core/queries.dart';

class ThreadDetailScreen extends StatefulWidget {
  final String id;
  const ThreadDetailScreen({super.key, required this.id});

  @override
  State<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends State<ThreadDetailScreen> {
  Map<String, dynamic>? _thread;
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
    final result = await client.query(QueryOptions(
      document: gql(kVoiceThread),
      variables: {'id': widget.id},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    setState(() {
      _thread = result.data?['voiceThread'] as Map<String, dynamic>?;
      _loading = false;
    });
  }

  Future<void> _playClip(int index, String audioUrl) async {
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

  Future<void> _addClip() async {
    context.push('/record?threadId=${widget.id}');
  }

  Future<void> _completeThread() async {
    final client = GraphQLProvider.of(context).value;
    await client.mutate(MutationOptions(
      document: gql(kCompleteThread),
      variables: {'threadId': widget.id},
    ));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    if (_thread == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Thread not found', style: TextStyle(color: AppTheme.textDim))),
      );
    }

    final title = _thread!['title'] as String? ?? 'Untitled Thread';
    final isComplete = _thread!['isComplete'] as bool? ?? false;
    final clips = (_thread!['clips'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!isComplete && clips.isNotEmpty)
            TextButton(
              onPressed: _completeThread,
              child: const Text('Publish', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      floatingActionButton: !isComplete
          ? FloatingActionButton.extended(
              onPressed: _addClip,
              backgroundColor: AppTheme.accent,
              icon: const Icon(Icons.mic_rounded, color: Colors.white),
              label: const Text('Add Part', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: clips.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mic_none_rounded, size: 64, color: AppTheme.accent.withAlpha(80)),
                  const SizedBox(height: 16),
                  const Text('No parts yet', style: TextStyle(color: AppTheme.textDim, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Tap the mic button to record the first part',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: clips.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final clip = clips[i];
                final audioUrl = clip['audioPath'] as String? ?? '';
                final duration = clip['duration'] as int? ?? 0;
                final isThisPlaying = _playingIndex == i && _isPlaying;

                return GestureDetector(
                  onTap: () => _playClip(i, audioUrl),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isThisPlaying ? AppTheme.accent.withAlpha(20) : AppTheme.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isThisPlaying ? AppTheme.accent.withAlpha(80) : AppTheme.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isThisPlaying ? AppTheme.accent : AppTheme.surface,
                          ),
                          child: Icon(
                            isThisPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: isThisPlaying ? Colors.white : AppTheme.accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Part ${i + 1}',
                                  style: const TextStyle(
                                      color: Color(0xFFF0E6D3),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14)),
                              Text('${duration}s',
                                  style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
                            ],
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
