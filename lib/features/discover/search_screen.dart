import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/queries.dart';
import '../../core/theme.dart';
import '../feed/clip_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _clips = [];
  bool _loading = false;

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() { _users = []; _clips = []; });
      return;
    }
    setState(() => _loading = true);
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(
      document: gql(kSearch),
      variables: {'q': q.trim()},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    setState(() {
      if (!result.hasException) {
        _users = (result.data!['search']['users'] as List).cast<Map<String, dynamic>>();
        _clips = (result.data!['search']['clips'] as List).cast<Map<String, dynamic>>();
      }
      _loading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search voices...',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: _search,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : ListView(
              children: [
                if (_users.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('People', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  ..._users.map((u) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.accent.withOpacity(0.2),
                      child: Text((u['name'] ?? u['username'] ?? '?')[0].toUpperCase(),
                        style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w700)),
                    ),
                    title: Text(u['name'] ?? u['username'] ?? ''),
                    subtitle: Text('@${u['username'] ?? ''}', style: const TextStyle(color: AppTheme.textMuted)),
                    onTap: () => context.push('/profile/${u['username']}'),
                  )),
                ],
                if (_clips.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('Clips', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  ..._clips.map((c) => ClipCard(clip: c)),
                ],
                if (!_loading && _users.isEmpty && _clips.isEmpty && _controller.text.isNotEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Text('No results for "${_controller.text}"',
                        style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ),
              ],
            ),
    );
  }
}
