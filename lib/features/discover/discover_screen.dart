import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/queries.dart';
import '../../core/theme.dart';
import '../feed/clip_card.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  static const _moods = ['calm', 'hype', 'sad', 'angry', 'playful', 'thoughtful', 'vulnerable'];
  static const _categories = ['General', 'Music', 'Comedy', 'Story', 'Thought', 'Question'];

  String? _selectedMood;
  String? _selectedCategory;
  List<Map<String, dynamic>> _clips = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(
      document: gql(kDiscover),
      variables: {'topic': _selectedCategory, 'mood': _selectedMood},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    setState(() {
      if (!result.hasException) _clips = (result.data!['discover'] as List).cast<Map<String, dynamic>>();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: Column(
        children: [
          // Mood grid (spec 7.9)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mood', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _moods.map((m) => _FilterChip(
                    label: m[0].toUpperCase() + m.substring(1),
                    selected: _selectedMood == m,
                    onTap: () { setState(() => _selectedMood = _selectedMood == m ? null : m); _load(); },
                  )).toList(),
                ),
                const SizedBox(height: 12),
                Text('Category', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _categories.map((c) => _FilterChip(
                    label: c,
                    selected: _selectedCategory == c,
                    onTap: () { setState(() => _selectedCategory = _selectedCategory == c ? null : c); _load(); },
                  )).toList(),
                ),
                const Divider(height: 24),
              ],
            ),
          ),
          // Results — recency sorted (RULE_010)
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
                : RefreshIndicator(
                    color: AppTheme.accent,
                    onRefresh: _load,
                    child: _clips.isEmpty
                        ? ListView(children: [Center(child: Padding(padding: const EdgeInsets.all(40), child: Text('No voices found', style: Theme.of(context).textTheme.bodyMedium)))])
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 8),
                            itemCount: _clips.length,
                            itemBuilder: (_, i) => ClipCard(clip: _clips[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.accent : AppTheme.border),
        ),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
