import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/queries.dart';
import '../../core/theme.dart';
import '../../core/services.dart';
import '../../core/me_provider.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cached = await FeedCache.load();
      if (cached.isNotEmpty && mounted) setState(() => _forYou = cached);
      _load();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final me = MeProvider.of(context);
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

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
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
      futures.add(client.query(QueryOptions(document: gql(kFeed), fetchPolicy: FetchPolicy.networkOnly)));
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
        // Ember feed: same clips sorted by play count (spec 9.4)
        _ember = List.from(_forYou)..sort((a, b) => (b['playsCount'] as int? ?? 0).compareTo(a['playsCount'] as int? ?? 0));
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs ?? TabController(length: 2, vsync: this);
    final tabList = <Tab>[
      const Tab(text: 'For You'),
      const Tab(text: 'Following'),
      if (_showEmber) const Tab(text: 'Ember'),
    ];
    final views = <Widget>[
      _ClipList(clips: _forYou),
      _ClipList(clips: _following),
      if (_showEmber) _ClipList(clips: _ember),
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
            const Text('Voxa'),
          ],
        ),
        bottom: TabBar(
          controller: tabs,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: tabList,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : RefreshIndicator(
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
  const _ClipList({required this.clips});

  @override
  Widget build(BuildContext context) {
    if (clips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_none_rounded, size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text('No voices yet', style: Theme.of(context).textTheme.titleMedium),
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
