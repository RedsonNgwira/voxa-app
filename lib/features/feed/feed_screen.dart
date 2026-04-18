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

class _FeedScreenState extends State<FeedScreen> {
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _clips = [];
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(
      document: gql(kFeed),
      variables: {'page': _page},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    if (!result.hasException) {
      final newClips = (result.data!['feed'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _clips.addAll(newClips);
        _page++;
        _hasMore = newClips.length == 20;
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    setState(() { _clips.clear(); _page = 1; _hasMore = true; });
    await _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            const Text('Voxa'),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: AppTheme.accent,
        backgroundColor: AppTheme.surface,
        onRefresh: _refresh,
        child: _clips.isEmpty && _loading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
            : _clips.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mic_none_rounded, size: 64, color: AppTheme.textMuted),
                        const SizedBox(height: 16),
                        Text('No clips yet', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Follow people to see their clips', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _clips.length + (_loading ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _clips.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator(color: AppTheme.accent, strokeWidth: 2)),
                        );
                      }
                      return ClipCard(clip: _clips[i]);
                    },
                  ),
      ),
    );
  }
}
