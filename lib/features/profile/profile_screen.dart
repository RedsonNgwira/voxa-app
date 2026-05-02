import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import '../../core/queries.dart';
import '../../core/theme.dart';
import '../../core/me_provider.dart';
import '../../main.dart';
import '../feed/clip_card.dart';
import '../feed/thread_feed_card.dart';
import '../feed/thread_feed_card.dart';

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
    try {
      final results = await Future.wait([
        client.query(QueryOptions(document: gql(kUser), variables: {'username': widget.username}, fetchPolicy: FetchPolicy.networkOnly)),
        client.query(QueryOptions(document: gql(kUserClips), variables: {'username': widget.username}, fetchPolicy: FetchPolicy.networkOnly)),
        client.query(QueryOptions(document: gql(kUserThreads), variables: {'username': widget.username}, fetchPolicy: FetchPolicy.networkOnly)),
      ]).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        if (!results[0].hasException && results[0].data != null) {
          _user = results[0].data!['user'] as Map<String, dynamic>?;
        }

        List<Map<String, dynamic>> clips = [];
        if (!results[1].hasException && results[1].data != null) {
          clips = (results[1].data!['userClips'] as List? ?? [])
              .whereType<Map<String, dynamic>>().toList();
        }

        List<Map<String, dynamic>> threads = [];
        if (!results[2].hasException && results[2].data != null) {
          threads = (results[2].data!['userThreads'] as List? ?? [])
              .whereType<Map<String, dynamic>>().toList();
        }

        // Merge clips + completed threads sorted by insertedAt
        _clips = [
          ...clips.map((c) => {...c, '_type': 'clip'}),
          ...threads.map((t) => {...t, '_type': 'thread'}),
        ]..sort((a, b) {
          final aDate = DateTime.tryParse((a['insertedAt'] as String? ?? '').replaceAll(' ', 'T')) ?? DateTime(0);
          final bDate = DateTime.tryParse((b['insertedAt'] as String? ?? '').replaceAll(' ', 'T')) ?? DateTime(0);
          return bDate.compareTo(aDate);
        });

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('Profile load error: $e');
    }

    // Auto-play voice bio 3s for other users
    final me = MeProvider.of(context);
    final bioUrl = _user?['voiceBioPath'] as String?;
    final isOtherUser = me != null && me['username'] != widget.username;
    if (bioUrl != null && isOtherUser) {
      try {
        await _bioPlayer.setUrl(bioUrl);
        await _bioPlayer.play();
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) await _bioPlayer.pause();
      } catch (_) {}
    }
  }

  Future<void> _logout(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Log out?'),
        content: const Text('You can always log back in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true || !ctx.mounted) return;

    // Use AuthService for proper cleanup (socket disconnect, token removal, state update)
    final auth = AuthProvider.of(ctx);
    if (auth != null) {
      await auth.logout();
    }
    if (ctx.mounted) ctx.go('/login');
  }

  Future<void> _toggleFollow() async {
    if (_user == null) return;
    final isFollowing = _user!['isFollowing'] as bool? ?? false;
    final client = GraphQLProvider.of(context).value;
    await client.mutate(MutationOptions(
      document: gql(isFollowing ? kUnfollow : kFollow),
      variables: {'userId': _user!['id']},
    ));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.accent),
              const SizedBox(height: 16),
              Text('Loading profile...', style: TextStyle(color: AppTheme.textMuted)),
            ],
          ),
        ),
      );
    }
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off_outlined, size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              const Text('User not found', style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => context.go('/'), child: const Text('Go home')),
            ],
          ),
        ),
      );
    }

    final me = MeProvider.of(context);
    final isOwnProfile = me != null && me['username'] == widget.username;
    final isEmbers = _user!['isEmbers'] as bool? ?? false;

    return Scaffold(
      body: RefreshIndicator(
        color: AppTheme.accent,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            // Header
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppTheme.accent.withOpacity(0.25), AppTheme.black],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 48),
                      // Avatar
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppTheme.accent.withOpacity(0.2),
                            child: Text(
                              (_user!['name'] ?? _user!['username'] ?? '?')[0].toUpperCase(),
                              style: const TextStyle(color: AppTheme.accent, fontSize: 32, fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (isEmbers)
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppTheme.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.local_fire_department, color: Colors.white, size: 14),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(_user!['name'] ?? '', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 2),
                      Text('@${_user!['username'] ?? ''}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textDim)),
                    ],
                  ),
                ),
              ),
            ),

            // Profile content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Clips count
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border, width: 0.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mic_rounded, size: 16, color: AppTheme.accent),
                          const SizedBox(width: 8),
                          Text('${_clips.length}', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(width: 4),
                          Text('voices', style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Voice bio player
                    if (_user!['voiceBioPath'] != null) ...[
                      _BioBanner(
                        bioUrl: _user!['voiceBioPath'] as String,
                        player: _bioPlayer,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Action buttons
                    if (isOwnProfile)
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => context.push('/voice-bio'),
                                  icon: const Icon(Icons.mic_rounded, size: 16),
                                  label: Text(_user!['voiceBioPath'] != null ? 'Update bio' : 'Record bio'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.accent,
                                    side: const BorderSide(color: AppTheme.border),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => context.push('/embers'),
                                  icon: const Icon(Icons.local_fire_department, size: 16, color: AppTheme.accent),
                                  label: Text(isEmbers ? 'Embers active' : 'Get Embers'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.textMuted,
                                    side: const BorderSide(color: AppTheme.border),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: () => context.push('/about'),
                              icon: const Icon(Icons.info_outline_rounded, size: 16, color: AppTheme.textDim),
                              label: const Text('About Voxa', style: TextStyle(color: AppTheme.textDim, fontSize: 13)),
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              onPressed: () => _logout(context),
                              icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.redAccent),
                              label: const Text('Log out', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                            ),
                          ),
                        ],
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (_user!['isFollowing'] as bool? ?? false) ? AppTheme.surface : AppTheme.accent,
                            side: (_user!['isFollowing'] as bool? ?? false) ? const BorderSide(color: AppTheme.border) : null,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text((_user!['isFollowing'] as bool? ?? false) ? 'Following' : 'Follow'),
                        ),
                      ),

                    const SizedBox(height: 8),
                    const Divider(),
                  ],
                ),
              ),
            ),

            // Clips list
            if (_clips.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.mic_none_rounded, size: 40, color: AppTheme.textMuted),
                        SizedBox(height: 8),
                        Text('No voices yet', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final item = _clips[i];
                    if (item['_type'] == 'thread') {
                      return ThreadFeedCard(thread: item);
                    }
                    return ClipCard(clip: item);
                  },
                  childCount: _clips.length,
                ),
              ),

            // Bottom spacing
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
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
  StreamSubscription? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

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
      _sub?.cancel();
      _sub = widget.player.playerStateStream.listen((s) {
        if (s.processingState == ProcessingState.completed && mounted) {
          setState(() => _playing = false);
          _sub?.cancel();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _playing ? AppTheme.accent : AppTheme.accent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: _playing ? Colors.white : AppTheme.accent, size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Voice bio', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    _playing ? 'Playing...' : 'Tap to listen',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textDim),
                  ),
                ],
              ),
            ),
            Icon(Icons.graphic_eq_rounded, size: 20, color: _playing ? AppTheme.accent : AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
