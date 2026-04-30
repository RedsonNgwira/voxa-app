import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/queries.dart';
import '../../core/theme.dart';
import '../feed/clip_card.dart';

class CirclesScreen extends StatefulWidget {
  const CirclesScreen({super.key});

  @override
  State<CirclesScreen> createState() => _CirclesScreenState();
}

class _CirclesScreenState extends State<CirclesScreen> {
  List<Map<String, dynamic>> _circles = [];
  bool _loading = true;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(document: gql(kMyCircles), fetchPolicy: FetchPolicy.networkOnly));
    if (!mounted) return;
    setState(() {
      if (!result.hasException) _circles = (result.data!['myCircles'] as List).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  Future<void> _createCircle() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final client = GraphQLProvider.of(context).value;
    final result = await client.mutate(MutationOptions(
      document: gql(kCreateCircle),
      variables: {'name': name, 'isPrivate': false},
    ));
    if (!mounted) return;
    if (result.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${result.exception?.graphqlErrors.firstOrNull?.message ?? 'Unknown error'}')),
      );
      return;
    }
    _nameController.clear();
    Navigator.pop(context);
    _load();
  }

  // Circle is live if any post in last 2h (spec 7.7)
  bool _isCircleLive(Map<String, dynamic> circle) {
    final posts = (circle['posts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final twoHoursAgo = DateTime.now().subtract(const Duration(hours: 2));
    return posts.any((p) {
      try {
        return DateTime.parse((p['insertedAt'] as String).replaceAll(' ', 'T')).isAfter(twoHoursAgo);
      } catch (_) { return false; }
    });
  }

  void _showCreate() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('New Circle', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'Circle name'), autofocus: true),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _createCircle, child: const Text('Create'))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Circles'),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: _showCreate)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _circles.isEmpty
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.group_outlined, size: 56, color: AppTheme.textMuted),
                    const SizedBox(height: 12),
                    Text('No circles yet', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ElevatedButton(onPressed: _showCreate, child: const Text('Create a circle')),
                  ],
                ))
              : ListView.builder(
                  itemCount: _circles.length,
                  itemBuilder: (_, i) {
                    final c = _circles[i];
                    final isLive = _isCircleLive(c);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.accent.withOpacity(0.2),
                        child: Text((c['name'] as String)[0].toUpperCase(), style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700)),
                      ),
                      title: Text(c['name'] as String),
                      subtitle: Text('${c['memberCount']} members', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      trailing: isLive
                          ? _LiveDot()
                          : c['isPrivate'] == true
                              ? const Icon(Icons.lock_outline, size: 16, color: AppTheme.textMuted)
                              : null,
                      onTap: () => context.push('/circles/${c['id']}'),
                    );
                  },
                ),
    );
  }
}

// Animated ember dot — live indicator (spec 7.7)
class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _anim = Tween(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: 10, height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.accent.withOpacity(_anim.value),
        boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.5), blurRadius: 6)],
      ),
    ),
  );
}

class CircleDetailScreen extends StatefulWidget {
  final String id;
  const CircleDetailScreen({super.key, required this.id});

  @override
  State<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _CircleDetailScreenState extends State<CircleDetailScreen> {
  Map<String, dynamic>? _circle;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(
      document: gql(kCircle),
      variables: {'id': widget.id},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    setState(() {
      if (!result.hasException) _circle = result.data!['circle'] as Map<String, dynamic>?;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.accent)));
    if (_circle == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Circle not found')));

    final members = (_circle!['members'] as List).cast<Map<String, dynamic>>();
    final posts = (_circle!['posts'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_circle!['name'] as String),
        actions: [
          // Member avatars (max 5) per spec 7.8
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...members.take(5).map((m) => Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppTheme.accent.withOpacity(0.2),
                    child: Text((m['name'] ?? m['username'] ?? '?')[0].toUpperCase(),
                      style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                )),
                if ((_circle!['memberCount'] as int) > 5)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppTheme.surface,
                      child: Text('+${(_circle!['memberCount'] as int) - 5}',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: posts.isEmpty
          ? Center(child: Text('No voices in this circle yet', style: Theme.of(context).textTheme.bodyMedium))
          : ListView.builder(
              itemCount: posts.length,
              itemBuilder: (_, i) => ClipCard(clip: posts[i]),
            ),
    );
  }
}
