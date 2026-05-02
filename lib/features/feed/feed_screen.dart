import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../core/queries.dart';
import '../../core/theme.dart';
import '../../core/services.dart';
import '../../core/me_provider.dart';
import '../../core/phoenix_socket.dart';
import 'clip_card.dart';
import 'thread_feed_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  TabController? _tabs;
  List<Map<String, dynamic>> _forYou = [];
  List<Map<String, dynamic>> _following = [];
  List<Map<String, dynamic>> _ember = [];
  bool _loading = true;
  bool _showEmber = false;
  bool _hasNewPosts = false;
  StreamSubscription? _feedSub;
  StreamSubscription? _pulseSub;
  String? _activeMood;

  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final me = MeProvider.of(context);
    _subscribeSocket();
    final showEmber = _checkEmberFeed(me);
    if (showEmber != _showEmber) {
      setState(() {
        _showEmber = showEmber;
        _tabs?.dispose();
        _tabs = TabController(length: showEmber ? 3 : 2, vsync: this);
      });
    }
    _tabs ??= TabController(length: showEmber ? 3 : 2, vsync: this);

    if (!_initialLoadDone) {
      _initialLoadDone = true;
      FeedCache.load().then((cached) {
        if (cached.isNotEmpty && mounted) {
          setState(() { _forYou = cached; _loading = false; });
        }
      });
      _load();
    }
  }

  void _subscribeSocket() {
    final me = MeProvider.of(context);
    if (me == null || _feedSub != null) return;
    final userId = me['id'] as String?;
    if (userId == null) return;
    _feedSub = phoenixSocket.subscribe('feed:$userId').listen((event) {
      if (!mounted) return;
      if (event['event'] == 'new_post' || event['event'] == 'new_clip') {
        setState(() => _hasNewPosts = true);
      } else if (event['event'] == 'post_expired' || event['event'] == 'clip_expired') {
        _load();
      }
    });
    _pulseSub = phoenixSocket.subscribe('pulse:$userId').listen((event) {
      if (!mounted) return;
      HapticFeedback.mediumImpact();
    });
  }

  @override
  void dispose() {
    _feedSub?.cancel();
    _pulseSub?.cancel();
    _tabs?.dispose();
    super.dispose();
  }

  bool _checkEmberFeed(Map<String, dynamic>? me) {
    if (me == null) return false;
    final expiresAt = me['emberFeedExpiresAt'] as String?;
    if (expiresAt == null) return false;
    try {
      return DateTime.parse(expiresAt).isAfter(DateTime.now());
    } catch (_) { return false; }
  }

  Future<void> _load() async {
    final client = GraphQLProvider.of(context).value;
    try {
      final futures = <Future>[
        client.query(QueryOptions(document: gql(kFeed), fetchPolicy: FetchPolicy.networkOnly)),
        client.query(QueryOptions(document: gql(kFollowingFeed), fetchPolicy: FetchPolicy.networkOnly)),
        client.query(QueryOptions(document: gql(kThreadFeed), variables: {'limit': 20}, fetchPolicy: FetchPolicy.networkOnly)),
      ];
      if (_showEmber) {
        futures.add(client.query(QueryOptions(document: gql(kEmberFeed), fetchPolicy: FetchPolicy.networkOnly)));
      }
      final results = await Future.wait(futures).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        final r0 = results[0] as QueryResult;
        final r1 = results[1] as QueryResult;
        final r2 = results[2] as QueryResult;

        List<Map<String, dynamic>> clips = [];
        if (!r0.hasException && r0.data != null) {
          clips = (r0.data!['feed'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
        }

        // Merge complete threads into For You feed, sorted by insertedAt
        List<Map<String, dynamic>> threads = [];
        if (!r2.hasException && r2.data != null) {
          threads = (r2.data!['threadFeed'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
        }

        // Tag each item with _type so the list builder knows what to render
        final tagged = [
          ...clips.map((c) => {...c, '_type': 'clip'}),
          ...threads.map((t) => {...t, '_type': 'thread'}),
        ]..sort((a, b) {
          final aDate = DateTime.tryParse((a['insertedAt'] as String? ?? '').replaceAll(' ', 'T')) ?? DateTime(0);
          final bDate = DateTime.tryParse((b['insertedAt'] as String? ?? '').replaceAll(' ', 'T')) ?? DateTime(0);
          return bDate.compareTo(aDate);
        });

        _forYou = tagged;
        FeedCache.save(clips); // cache only clips

        if (!r1.hasException && r1.data != null) {
          _following = (r1.data!['followingFeed'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
        }
        if (_showEmber && results.length > 3) {
          final r3 = results[3] as QueryResult;
          if (!r3.hasException && r3.data != null) {
            _ember = (r3.data!['emberFeed'] as List? ?? []).whereType<Map<String, dynamic>>().toList();
          }
        }
        _loading = false;
        _hasNewPosts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      debugPrint('Feed load error: $e');
    }
  }

  List<Map<String, dynamic>> _moodFiltered(List<Map<String, dynamic>> clips) {
    if (_activeMood == null) return clips;
    return clips.where((c) => c['mood'] == _activeMood).toList();
  }

  void _setMood(String? mood) {
    setState(() => _activeMood = _activeMood == mood ? null : mood);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs!;
    final tabList = <Tab>[
      const Tab(text: 'For You'),
      const Tab(text: 'Following'),
      if (_showEmber) const Tab(text: 'Ember'),
    ];
    final views = <Widget>[
      _ClipList(clips: _moodFiltered(_forYou), loading: _loading, emptyMessage: 'No voices yet\nBe the first to speak', emptyIcon: Icons.campaign_rounded),
      _ClipList(clips: _moodFiltered(_following), loading: _loading, emptyMessage: 'Follow people to hear\ntheir voices', suggestUsers: true, emptyIcon: Icons.people_outline_rounded),
      if (_showEmber) _ClipList(clips: _moodFiltered(_ember), loading: _loading, emptyMessage: 'No ember voices yet', emptyIcon: Icons.local_fire_department_outlined),
    ];

    const moods = ['calm', 'hype', 'sad', 'angry', 'playful', 'thoughtful', 'vulnerable'];
    const moodIcons = {
      'calm': Icons.spa_rounded,
      'hype': Icons.bolt_rounded,
      'sad': Icons.water_drop_rounded,
      'angry': Icons.whatshot_rounded,
      'playful': Icons.mood_rounded,
      'thoughtful': Icons.psychology_rounded,
      'vulnerable': Icons.favorite_rounded,
    };

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.accent, Color(0xFFC0431A)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 15),
            ),
            const SizedBox(width: 8),
            const VoxaLogo(fontSize: 22),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline_rounded, color: AppTheme.gold, size: 22),
            onPressed: () => context.push('/prompts'),
            tooltip: 'Daily Prompt',
          ),
          IconButton(
            icon: const Icon(Icons.local_fire_department_rounded, color: AppTheme.accent, size: 22),
            onPressed: () => context.push('/embers'),
            tooltip: 'Embers',
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 22),
            onPressed: () => context.push('/search'),
          ),
        ],
        bottom: TabBar(
          controller: tabs,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 2.5,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          tabs: tabList,
        ),
      ),
      body: Column(
        children: [
          // Mood filter chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: moods.map((mood) {
                final active = _activeMood == mood;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _setMood(mood),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? AppTheme.accent.withOpacity(0.15) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active ? AppTheme.accent : AppTheme.border,
                          width: active ? 1.2 : 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(moodIcons[mood] ?? Icons.circle, size: 14,
                            color: active ? AppTheme.accent : AppTheme.textMuted),
                          const SizedBox(width: 5),
                          Text(mood[0].toUpperCase() + mood.substring(1),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                              color: active ? AppTheme.accent : AppTheme.textMuted,
                            )),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Feed content
          Expanded(
            child: Stack(
              children: [
                RefreshIndicator(
                  color: AppTheme.accent,
                  backgroundColor: AppTheme.surface,
                  onRefresh: _load,
                  child: TabBarView(controller: tabs, children: views),
                ),
                // New posts banner
                if (_hasNewPosts)
                  Positioned(
                    top: 8, left: 0, right: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: () { setState(() => _hasNewPosts = false); _load(); },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.4), blurRadius: 12)],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 14),
                              SizedBox(width: 6),
                              Text('New voices', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClipList extends StatefulWidget {
  final List<Map<String, dynamic>> clips;
  final bool loading;
  final String emptyMessage;
  final bool suggestUsers;
  final IconData emptyIcon;
  const _ClipList({
    required this.clips,
    this.loading = false,
    this.emptyMessage = 'No voices yet',
    this.suggestUsers = false,
    this.emptyIcon = Icons.mic_none_rounded,
  });

  @override
  State<_ClipList> createState() => _ClipListState();
}

class _ClipListState extends State<_ClipList> with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _suggested = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.suggestUsers) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSuggested());
    }
  }

  Future<void> _loadSuggested() async {
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(
      document: gql(kSuggestedUsers),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted || result.hasException) return;
    setState(() => _suggested = (result.data!['search']['users'] as List).cast<Map<String, dynamic>>());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Loading skeleton
    if (widget.loading && widget.clips.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: 4,
        itemBuilder: (_, __) => const _SkeletonCard(),
      );
    }

    // Empty state
    if (widget.clips.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 60, 32, 24),
            child: Column(
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.emptyIcon, size: 36, color: AppTheme.accent.withOpacity(0.5)),
                ),
                const SizedBox(height: 16),
                Text(widget.emptyMessage,
                  style: const TextStyle(color: AppTheme.textDim, fontSize: 15, height: 1.4),
                  textAlign: TextAlign.center),
              ],
            ),
          ),
          if (_suggested.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('People to follow', style: Theme.of(context).textTheme.titleMedium),
            ),
            ..._suggested.take(10).map((u) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border, width: 0.5),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.accent.withOpacity(0.15),
                      child: Text(
                        (u['name'] ?? u['username'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u['name'] ?? u['username'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          Text('@${u['username'] ?? ''}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => context.push('/profile/${u['username']}'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: const Text('View', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ],
      );
    }

    // Feed list
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: widget.clips.length,
      itemBuilder: (_, i) {
        final item = widget.clips[i];
        if (item['_type'] == 'thread') {
          return ThreadFeedCard(thread: item);
        }
        return ClipCard(clip: item);
      },
    );
  }
}

/// Skeleton loading card placeholder
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Header skeleton
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 100, height: 12, decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(4))),
                  const SizedBox(height: 6),
                  Container(width: 60, height: 10, decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(4))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Waveform skeleton
          Row(
            children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: AppTheme.surface, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(child: Container(height: 32, decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(4)))),
            ],
          ),
          const SizedBox(height: 12),
          // Actions skeleton
          Container(width: 120, height: 10, decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(4))),
        ],
      ),
    );
  }
}
