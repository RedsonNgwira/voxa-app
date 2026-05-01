import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/queries.dart';
import '../feed/clip_card.dart';

class PromptScreen extends StatefulWidget {
  const PromptScreen({super.key});

  @override
  State<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends State<PromptScreen> {
  Map<String, dynamic>? _todayPrompt;
  List<Map<String, dynamic>> _recentPrompts = [];
  List<Map<String, dynamic>> _responses = [];
  bool _loading = true;
  String? _selectedPromptId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final client = GraphQLProvider.of(context).value;

    final todayResult = await client.query(QueryOptions(
      document: gql(kTodayPrompt),
      fetchPolicy: FetchPolicy.networkOnly,
    ));

    final recentResult = await client.query(QueryOptions(
      document: gql(kRecentPrompts),
      variables: const {'days': 7},
      fetchPolicy: FetchPolicy.networkOnly,
    ));

    if (!mounted) return;

    final today = todayResult.data?['todayPrompt'] as Map<String, dynamic>?;
    final recent = (recentResult.data?['recentPrompts'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        [];

    setState(() {
      _todayPrompt = today;
      _recentPrompts = recent;
      _loading = false;
      if (today != null) {
        _selectedPromptId = today['id'] as String;
        _loadResponses(_selectedPromptId!);
      }
    });
  }

  Future<void> _loadResponses(String promptId) async {
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(
      document: gql(kPromptResponses),
      variables: {'promptId': promptId, 'limit': 20},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    setState(() {
      _responses = (result.data?['promptResponses'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      _selectedPromptId = promptId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Prompt'),
        actions: [
          if (_todayPrompt != null)
            IconButton(
              icon: const Icon(Icons.mic_rounded),
              tooltip: 'Respond to prompt',
              onPressed: () => context.push(
                Uri(path: '/record', queryParameters: {
                  'promptId': _todayPrompt!['id'].toString(),
                  'promptText': _todayPrompt!['text'] as String,
                }).toString(),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.accent))
          : RefreshIndicator(
              color: AppTheme.accent,
              onRefresh: _load,
              child: CustomScrollView(
                slivers: [
                  // Today's prompt card
                  if (_todayPrompt != null)
                    SliverToBoxAdapter(
                      child: _PromptCard(
                        prompt: _todayPrompt!,
                        isToday: true,
                        onRespond: () => context.push(
                          Uri(path: '/record', queryParameters: {
                            'promptId': _todayPrompt!['id'].toString(),
                            'promptText': _todayPrompt!['text'] as String,
                          }).toString(),
                        ),
                      ),
                    ),

                  if (_todayPrompt == null)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No prompt today yet.\nCheck back soon!',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: AppTheme.textDim, fontSize: 15),
                          ),
                        ),
                      ),
                    ),

                  // Recent prompts row
                  if (_recentPrompts.length > 1)
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding:
                                EdgeInsets.fromLTRB(16, 24, 16, 8),
                            child: Text('Recent Prompts',
                                style: TextStyle(
                                    color: AppTheme.gold,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5)),
                          ),
                          SizedBox(
                            height: 40,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _recentPrompts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) {
                                final p = _recentPrompts[i];
                                final selected =
                                    p['id'] == _selectedPromptId;
                                return GestureDetector(
                                  onTap: () =>
                                      _loadResponses(p['id'] as String),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? AppTheme.accent
                                          : AppTheme.surface,
                                      borderRadius:
                                          BorderRadius.circular(20),
                                      border: Border.all(
                                          color: selected
                                              ? AppTheme.accent
                                              : AppTheme.border),
                                    ),
                                    child: Text(
                                      p['activeDate'] as String? ??
                                          'Prompt',
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.white
                                            : AppTheme.textDim,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Responses header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.mic_rounded,
                              size: 16, color: AppTheme.accent),
                          const SizedBox(width: 6),
                          Text(
                            '${_responses.length} ${_responses.length == 1 ? 'response' : 'responses'}',
                            style: const TextStyle(
                                color: AppTheme.textDim, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Responses list
                  if (_responses.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'Be the first to respond!',
                            style:
                                TextStyle(color: AppTheme.textDim, fontSize: 14),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: ClipCard(clip: _responses[index]),
                        ),
                        childCount: _responses.length,
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  final Map<String, dynamic> prompt;
  final bool isToday;
  final VoidCallback onRespond;

  const _PromptCard({
    required this.prompt,
    this.isToday = false,
    required this.onRespond,
  });

  String _categoryIcon(String? cat) {
    return switch (cat) {
      'reflective' => '🪞',
      'sensory' => '👂',
      'playful' => '🎭',
      'deep' => '🌊',
      _ => '💬',
    };
  }

  @override
  Widget build(BuildContext context) {
    final text = prompt['text'] as String? ?? '';
    final category = prompt['category'] as String? ?? 'general';
    final count = prompt['responseCount'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A1F14), Color(0xFF1A1410)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.accent.withAlpha(40),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accent.withAlpha(15),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isToday) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('TODAY',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                '${_categoryIcon(category)} ${category[0].toUpperCase()}${category.substring(1)}',
                style:
                    const TextStyle(color: AppTheme.textDim, fontSize: 12),
              ),
              const Spacer(),
              Text('$count voices',
                  style:
                      const TextStyle(color: AppTheme.textDim, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            text,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF0E6D3),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRespond,
              icon: const Icon(Icons.mic_rounded, size: 18),
              label: const Text('Respond with your voice'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
