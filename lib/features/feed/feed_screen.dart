import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/queries.dart';
import '../../core/theme.dart';
import 'clip_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Map<String, dynamic>> _forYou = [];
  List<Map<String, dynamic>> _following = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    final client = GraphQLProvider.of(context).value;
    final results = await Future.wait([
      client.query(QueryOptions(document: gql(kFeed), fetchPolicy: FetchPolicy.networkOnly)),
      client.query(QueryOptions(document: gql(kFollowingFeed), fetchPolicy: FetchPolicy.networkOnly)),
    ]);
    if (!mounted) return;
    setState(() {
      if (!results[0].hasException) _forYou = (results[0].data!['feed'] as List).cast<Map<String, dynamic>>();
      if (!results[1].hasException) _following = (results[1].data!['followingFeed'] as List).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          controller: _tabs,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textMuted,
          tabs: const [
            Tab(text: 'For You'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : RefreshIndicator(
              color: AppTheme.accent,
              backgroundColor: AppTheme.surface,
              onRefresh: _load,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _ClipList(clips: _forYou),
                  _ClipList(clips: _following),
                ],
              ),
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
