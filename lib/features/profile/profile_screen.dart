import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/queries.dart';
import '../../core/theme.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
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
  }

  Future<void> _toggleFollow() async {
    if (_user == null) return;
    final isFollowing = _user!['isFollowing'] as bool? ?? false;
    final client = GraphQLProvider.of(context).value;
    await client.mutate(MutationOptions(
      document: gql(isFollowing ? kUnfollow : kFollow),
      variables: {'username': widget.username},
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
            expandedHeight: 200,
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
                      radius: 40,
                      backgroundColor: AppTheme.accent.withOpacity(0.2),
                      child: Text(
                        (_user!['name'] ?? _user!['username'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: AppTheme.accent, fontSize: 32, fontWeight: FontWeight.w700),
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
                  // Stats + follow
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Stat(label: 'Clips', value: '${_clips.length}'),
                      _Stat(label: 'Followers', value: '${_user!['followerCount'] ?? 0}'),
                      _Stat(label: 'Following', value: '${_user!['followingCount'] ?? 0}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_user!['isFollowing'] as bool? ?? false) ? AppTheme.surface : AppTheme.accent,
                        side: (_user!['isFollowing'] as bool? ?? false) ? const BorderSide(color: AppTheme.border) : null,
                      ),
                      child: Text((_user!['isFollowing'] as bool? ?? false) ? 'Following' : 'Follow'),
                    ),
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
