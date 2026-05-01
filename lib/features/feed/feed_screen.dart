import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../core/queries.dart';
import '../../core/theme.dart';
import '../../core/services.dart';
import '../../core/me_provider.dart';
import '../../core/phoenix_socket.dart';
import 'clip_card.dart';

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
  bool _loading = false;
  bool _showEmber = false;
  StreamSubscription? _feedSub;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this); // initialized early, updated in didChangeDependencies
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cached = await FeedCache.load();
      if (cached.isNotEmpty && mounted) setState(() => _forYou = cached);
      _load();
    });
  }

  void _subscribeSocket() {
    final me = MeProvider.of(context);
    if (me == null || _feedSub != null) return; // not ready or already subscribed
    final userId = me['id'] as String?;
    if (userId == null) return;
    _feedSub = phoenixSocket.subscribe('feed:$userId').listen((event) {
      if (!mounted) return;
      if (event['event'] == 'new_post' || event['event'] == 'new_clip' ||
          event['event'] == 'post_expired' || event['event'] == 'clip_expired') {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _feedSub?.cancel();
    _tabs?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final me = MeProvider.of(context);
    // Subscribe socket once MeProvider has data
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
    if (_loading) return;
    setState(() => _loading = true);
    final client = GraphQLProvider.of(context).value;
    final futures = [
      client.query(QueryOptions(document: gql(kFeed), fetchPolicy: FetchPolicy.networkOnly)),
      client.query(QueryOptions(document: gql(kFollowingFeed), fetchPolicy: FetchPolicy.networkOnly)),
    ];
    if (_showEmber) {
      futures.add(client.query(QueryOptions(document: gql(kEmberFeed), fetchPolicy: FetchPolicy.networkOnly)));
    }
    final results = await Future.wait(futures);
    if (!mounted) return;
    setState(() {
      if (!results[0].hasException) {
        _forYou = (results[0].data!['feed'] as List).cast<Map<String, dynamic>>();
        FeedCache.save(_forYou);
      }
      if (!results[1].hasException) _following = (results[1].data!['followingFeed'] as List).cast<Map<String, dynamic>>();
      if (_showEmber && results.length > 2 && !results[2].hasException) {
        _ember = (results[2].data!['emberFeed'] as List).cast<Map<String, dynamic>>();
      }
      _loading = false;
    });
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
      _ClipList(clips: _forYou, emptyMessage: 'No voices yet\nBe the first to speak'),
      _ClipList(clips: _following, emptyMessage: 'Follow people to hear their voices'),
      if (_showEmber) _ClipList(clips: _ember, emptyMessage: 'No ember voices yet'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
            const VoxaLogo(fontSize: 20),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_fire_department_rounded, color: AppTheme.accent),
            onPressed: () => context.push('/embers'),
            tooltip: 'Embers',
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () => context.push('/search'),
          ),
        ],
        bottom: TabBar(
          controller: tabs,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: tabList,
        ),
      ),
      body: RefreshIndicator(
              color: AppTheme.accent,
              backgroundColor: AppTheme.surface,
              onRefresh: _load,
              child: TabBarView(controller: tabs, children: views),
            ),
    );
  }
}

class _ClipList extends StatelessWidget {
  final List<Map<String, dynamic>> clips;
  final String emptyMessage;
  const _ClipList({required this.clips, this.emptyMessage = 'No voices yet'});

  String get _emptyMessage => emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (clips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_none_rounded, size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              _emptyMessage,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: clips.length,
      itemBuilder: (_, i) => ClipCard(clip: clips[i]),
    );
  }
}
