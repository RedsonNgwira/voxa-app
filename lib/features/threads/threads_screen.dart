import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/queries.dart';

class ThreadsScreen extends StatefulWidget {
  const ThreadsScreen({super.key});

  @override
  State<ThreadsScreen> createState() => _ThreadsScreenState();
}

class _ThreadsScreenState extends State<ThreadsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _myThreads = [];
  List<Map<String, dynamic>> _feedThreads = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final client = GraphQLProvider.of(context).value;

    final myResult = await client.query(QueryOptions(
      document: gql(kMyThreads),
      fetchPolicy: FetchPolicy.networkOnly,
    ));

    final feedResult = await client.query(QueryOptions(
      document: gql(kThreadFeed),
      variables: const {'limit': 20},
      fetchPolicy: FetchPolicy.networkOnly,
    ));

    if (!mounted) return;
    setState(() {
      _myThreads = (myResult.data?['myThreads'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      _feedThreads = (feedResult.data?['threadFeed'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      _loading = false;
    });
  }

  Future<void> _createThread() async {
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('New Voice Thread'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Thread title (optional)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textDim)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (title == null || !mounted) return;

    final client = GraphQLProvider.of(context).value;
    final result = await client.mutate(MutationOptions(
      document: gql(kCreateVoiceThread),
      variables: {'title': title.isEmpty ? null : title},
    ));

    if (!mounted) return;
    if (result.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to create thread')),
      );
      return;
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Threads'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textDim,
          tabs: const [
            Tab(text: 'My Threads'),
            Tab(text: 'Explore'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createThread,
        backgroundColor: AppTheme.accent,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : TabBarView(
              controller: _tabController,
              children: [
                _ThreadList(threads: _myThreads, onRefresh: _load, emptyText: 'No threads yet.\nCreate one to start!'),
                _ThreadList(threads: _feedThreads, onRefresh: _load, emptyText: 'No published threads yet.'),
              ],
            ),
    );
  }
}

class _ThreadList extends StatelessWidget {
  final List<Map<String, dynamic>> threads;
  final Future<void> Function() onRefresh;
  final String emptyText;

  const _ThreadList({required this.threads, required this.onRefresh, required this.emptyText});

  @override
  Widget build(BuildContext context) {
    if (threads.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.accent,
        onRefresh: onRefresh,
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: Center(
                child: Text(emptyText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textDim, fontSize: 14)),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.accent,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: threads.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _ThreadCard(thread: threads[i]),
      ),
    );
  }
}

class _ThreadCard extends StatelessWidget {
  final Map<String, dynamic> thread;

  const _ThreadCard({required this.thread});

  @override
  Widget build(BuildContext context) {
    final title = thread['title'] as String? ?? 'Untitled Thread';
    final clipCount = thread['clipCount'] as int? ?? 0;
    final isComplete = thread['isComplete'] as bool? ?? false;
    final user = thread['user'] as Map<String, dynamic>?;
    final clips = (thread['clips'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return GestureDetector(
      onTap: () => context.push('/thread/${thread['id']}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFF0E6D3))),
                ),
                if (isComplete)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.online.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.online.withAlpha(60)),
                    ),
                    child: const Text('Complete',
                        style: TextStyle(color: AppTheme.online, fontSize: 10, fontWeight: FontWeight.w600)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.accent.withAlpha(60)),
                    ),
                    child: const Text('In progress',
                        style: TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (user != null)
              Text('by ${user['name'] ?? user['username']}',
                  style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.segment_rounded, size: 14, color: AppTheme.textDim),
                const SizedBox(width: 6),
                Text('$clipCount ${clipCount == 1 ? 'part' : 'parts'}',
                    style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
              ],
            ),
            if (clips.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: clips.take(10).map((_) => Container(
                  width: 6, height: 6,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent.withAlpha(150),
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
