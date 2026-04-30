import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/queries.dart';
import '../../core/theme.dart';
import '../../core/me_provider.dart';
import '../feed/clip_card.dart';

class ProfileScreen extends StatefulWidget {
  final String username;
  const ProfileScreen({super.key, required this.username});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _clips = [];
  bool _loading = true;
  final _bioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _bioPlayer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final client = GraphQLProvider.of(context).value;
    final results = await Future.wait([
      client.query(QueryOptions(document: gql(kUser), variables: {'username': widget.username}, fetchPolicy: FetchPolicy.networkOnly)),
      client.query(QueryOptions(document: gql(kUserClips), variables: {'username': widget.username}, fetchPolicy: FetchPolicy.networkOnly)),
    ]);
    if (!mounted) return;
    setState(() {
      if (!results[0].hasException) _user = results[0].data!['user'] as Map<String, dynamic>?;
      if (!results[1].hasException) _clips = (results[1].data!['userClips'] as List).cast<Map<String, dynamic>>();
      _loading = false;
    });

    // Auto-play voice bio 3s for other users (spec 7.11)
    final me = MeProvider.of(context);
    final bioUrl = _user?['voiceBioPath'] as String?;
    final isOtherUser = me != null && me['username'] != widget.username;
    if (bioUrl != null && isOtherUser) {
      try {
        await _bioPlayer.setUrl(bioUrl);
        await _bioPlayer.play();
        await Future.delayed(const Duration(seconds: 3));
        await _bioPlayer.pause();
      } catch (_) {}
    }
  }

  Future<void> _toggleFollow() async {
    if (_user == null) return;
    final isFollowing = _user!['isFollowing'] as bool? ?? false;
    final client = GraphQLProvider.of(context).value;
    // Follow/unfollow uses userId per spec
    await client.mutate(MutationOptions(
      document: gql(isFollowing ? kUnfollow : kFollow),
      variables: {'userId': _user!['id']},
    ));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.accent)));
    if (_user == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('User not found')));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.accent.withOpacity(0.3), AppTheme.black],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppTheme.accent.withOpacity(0.2),
                      child: Text(
                        (_user!['name'] ?? _user!['username'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: AppTheme.accent, fontSize: 28, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_user!['name'] ?? '', style: Theme.of(context).textTheme.titleLarge),
                    Text('@${_user!['username'] ?? ''}', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Clips count only — no follower counts per RULE_001
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Stat(label: 'Clips', value: '${_clips.length}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Voice bio player (spec 7.10/7.11)
                  if (_user!['voiceBioPath'] != null) ...[
                    _BioBanner(
                      bioUrl: _user!['voiceBioPath'] as String,
                      player: _bioPlayer,
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: Builder(builder: (context) {
                      final me = MeProvider.of(context);
                      final isOwnProfile = me != null && me['username'] == widget.username;
                      if (isOwnProfile) {
                        return OutlinedButton.icon(
                          onPressed: () => context.push('/voice-bio'),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit profile'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textMuted,
                            side: const BorderSide(color: AppTheme.border),
                          ),
                        );
                      }
                      return ElevatedButton(
                        onPressed: _toggleFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: (_user!['isFollowing'] as bool? ?? false) ? AppTheme.surface : AppTheme.accent,
                          side: (_user!['isFollowing'] as bool? ?? false) ? const BorderSide(color: AppTheme.border) : null,
                        ),
                        child: Text((_user!['isFollowing'] as bool? ?? false) ? 'Following' : 'Follow'),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => ClipCard(clip: _clips[i]),
              childCount: _clips.length,
            ),
          ),
          if (_clips.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('No clips yet', style: TextStyle(color: AppTheme.textMuted))),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _BioBanner extends StatefulWidget {
  final String bioUrl;
  final AudioPlayer player;
  const _BioBanner({required this.bioUrl, required this.player});

  @override
  State<_BioBanner> createState() => _BioBannerState();
}

class _BioBannerState extends State<_BioBanner> {
  bool _playing = false;

  Future<void> _toggle() async {
    if (_playing) {
      await widget.player.pause();
      setState(() => _playing = false);
    } else {
      if (widget.player.processingState == ProcessingState.idle) {
        await widget.player.setUrl(widget.bioUrl);
      }
      await widget.player.play();
      setState(() => _playing = true);
      widget.player.playerStateStream.firstWhere(
        (s) => s.processingState == ProcessingState.completed,
      ).then((_) { if (mounted) setState(() => _playing = false); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
              child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Voice bio', style: Theme.of(context).textTheme.titleMedium),
                  Text(_playing ? 'Playing...' : 'Tap to listen', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.mic_rounded, size: 16, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
