import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../../core/theme.dart';
import '../../core/queries.dart';

class CampfireScreen extends StatefulWidget {
  const CampfireScreen({super.key});

  @override
  State<CampfireScreen> createState() => _CampfireScreenState();
}

class _CampfireScreenState extends State<CampfireScreen> {
  List<Map<String, dynamic>> _campfires = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(
      document: gql(kActiveCampfires),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    setState(() {
      _campfires = (result.data?['activeCampfires'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      _loading = false;
    });
  }

  Future<void> _startCampfire() async {
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Text('Start a Campfire'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Give it a name (optional)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textDim)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Start'),
            ),
          ],
        );
      },
    );

    if (title == null || !mounted) return;

    final client = GraphQLProvider.of(context).value;
    final result = await client.mutate(MutationOptions(
      document: gql(kStartCampfire),
      variables: {
        'title': title.isEmpty ? null : title,
        'maxParticipants': 8,
      },
    ));

    if (!mounted) return;
    if (result.hasException) {
      final msg = result.exception?.graphqlErrors.firstOrNull?.message ?? 'Failed to start campfire';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      return;
    }

    final campfire = result.data?['startCampfire'] as Map<String, dynamic>?;
    if (campfire != null) {
      context.push('/campfire/${campfire['id']}');
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Campfires')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _startCampfire,
        backgroundColor: AppTheme.accent,
        icon: const Icon(Icons.local_fire_department_rounded, color: Colors.white),
        label: const Text('Start', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : RefreshIndicator(
              color: AppTheme.accent,
              onRefresh: _load,
              child: _campfires.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_fire_department_rounded,
                                    size: 64, color: AppTheme.accent.withAlpha(80)),
                                const SizedBox(height: 16),
                                const Text('No active campfires',
                                    style: TextStyle(color: AppTheme.textDim, fontSize: 16)),
                                const SizedBox(height: 8),
                                const Text('Start one and invite your circle',
                                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _campfires.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _CampfireCard(
                        campfire: _campfires[i],
                        onTap: () => context.push('/campfire/${_campfires[i]['id']}'),
                      ),
                    ),
            ),
    );
  }
}

class _CampfireCard extends StatelessWidget {
  final Map<String, dynamic> campfire;
  final VoidCallback onTap;

  const _CampfireCard({required this.campfire, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = campfire['title'] as String? ?? 'Untitled campfire';
    final count = campfire['participantCount'] as int? ?? 0;
    final max = campfire['maxParticipants'] as int? ?? 8;
    final starter = campfire['starter'] as Map<String, dynamic>?;
    final participants = (campfire['participants'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withAlpha(10),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Live indicator
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.accent,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accent.withAlpha(130),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text('LIVE',
                    style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
                const Spacer(),
                Text('$count/$max',
                    style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFF0E6D3))),
            const SizedBox(height: 8),
            if (starter != null)
              Text('Started by ${starter['name'] ?? starter['username']}',
                  style: const TextStyle(color: AppTheme.textDim, fontSize: 12)),
            const SizedBox(height: 12),
            // Participant avatars
            Row(
              children: [
                ...participants.take(5).map((p) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppTheme.accent.withAlpha(40),
                        child: Text(
                          (p['name'] as String? ?? '?')[0].toUpperCase(),
                          style: const TextStyle(color: AppTheme.accent, fontSize: 11),
                        ),
                      ),
                    )),
                if (participants.length > 5)
                  Text('+${participants.length - 5} more',
                      style: const TextStyle(color: AppTheme.textDim, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Detail screen for a single campfire — powered by LiveKit
class CampfireDetailScreen extends StatefulWidget {
  final String id;
  const CampfireDetailScreen({super.key, required this.id});

  @override
  State<CampfireDetailScreen> createState() => _CampfireDetailScreenState();
}

class _CampfireDetailScreenState extends State<CampfireDetailScreen> {
  Map<String, dynamic>? _campfire;
  bool _loading = true;
  bool _inRoom = false;
  bool _muted = false;
  lk.Room? _room;
  final List<lk.RemoteParticipant> _lkParticipants = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _room?.removeListener(_onRoomUpdate);
    _room?.disconnect();
    super.dispose();
  }

  Future<void> _load() async {
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(
      document: gql(kGetCampfire),
      variables: {'id': widget.id},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    setState(() {
      _campfire = result.data?['campfire'] as Map<String, dynamic>?;
      _loading = false;
    });
  }

  Future<void> _joinRoom() async {
    final client = GraphQLProvider.of(context).value;

    await client.mutate(MutationOptions(
      document: gql(kJoinCampfire),
      variables: {'campfireId': widget.id},
    ));

    final tokenResult = await client.query(QueryOptions(
      document: gql(kCampfireToken),
      variables: {'campfireId': widget.id},
      fetchPolicy: FetchPolicy.networkOnly,
    ));

    if (!mounted) return;
    if (tokenResult.hasException) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to get room token')),
      );
      return;
    }

    final tokenData = tokenResult.data?['campfireToken'] as Map<String, dynamic>?;
    if (tokenData == null) return;

    final room = lk.Room();
    room.addListener(_onRoomUpdate);

    await room.connect(
      tokenData['url'] as String,
      tokenData['token'] as String,
      roomOptions: const lk.RoomOptions(
        defaultAudioPublishOptions: lk.AudioPublishOptions(name: 'voice'),
      ),
    );

    await room.localParticipant?.setMicrophoneEnabled(true);

    if (!mounted) return;
    setState(() {
      _room = room;
      _inRoom = true;
      _lkParticipants
        ..clear()
        ..addAll(room.remoteParticipants.values);
    });
    _load();
  }

  void _onRoomUpdate() {
    if (!mounted) return;
    setState(() {
      _lkParticipants
        ..clear()
        ..addAll(_room!.remoteParticipants.values);
    });
  }

  Future<void> _toggleMic() async {
    final local = _room?.localParticipant;
    if (local == null) return;
    final newMuted = !_muted;
    await local.setMicrophoneEnabled(!newMuted);
    setState(() => _muted = newMuted);
  }

  Future<void> _leaveRoom() async {
    _room?.removeListener(_onRoomUpdate);
    await _room?.disconnect();
    final client = GraphQLProvider.of(context).value;
    await client.mutate(MutationOptions(
      document: gql(kLeaveCampfire),
      variables: {'campfireId': widget.id},
    ));
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }

    if (_campfire == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('Campfire not found or ended',
              style: TextStyle(color: AppTheme.textDim)),
        ),
      );
    }

    final title = _campfire!['title'] as String? ?? 'Campfire';
    final dbParticipants =
        (_campfire!['participants'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final count = _campfire!['participantCount'] as int? ?? 0;
    final max = _campfire!['maxParticipants'] as int? ?? 8;

    return Scaffold(
      backgroundColor: AppTheme.card,
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_inRoom)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accent,
                      boxShadow: [
                        BoxShadow(
                            color: AppTheme.accent.withAlpha(130),
                            blurRadius: 6,
                            spreadRadius: 2)
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('LIVE',
                      style: TextStyle(
                          color: AppTheme.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ],
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.accent.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.accent.withAlpha(60)),
              ),
              child: Text('$count / $max voices',
                  style: const TextStyle(color: AppTheme.accent, fontSize: 13)),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 0.85,
                ),
                itemCount: dbParticipants.length,
                itemBuilder: (_, i) {
                  final p = dbParticipants[i];
                  final name = p['name'] as String? ?? p['username'] as String? ?? '?';
                  final isSpeaking = _inRoom &&
                      _lkParticipants.any((lkp) =>
                          lkp.identity == 'user:${p['id']}' && lkp.isSpeaking);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: isSpeaking
                              ? [
                                  BoxShadow(
                                      color: AppTheme.accent.withAlpha(150),
                                      blurRadius: 16,
                                      spreadRadius: 4)
                                ]
                              : [],
                        ),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: isSpeaking
                              ? AppTheme.accent.withAlpha(80)
                              : AppTheme.accent.withAlpha(40),
                          child: Text(
                            name[0].toUpperCase(),
                            style: TextStyle(
                                color: AppTheme.accent,
                                fontSize: 22,
                                fontWeight: isSpeaking
                                    ? FontWeight.w700
                                    : FontWeight.w500),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(name,
                          style: const TextStyle(
                              color: AppTheme.textDim, fontSize: 11),
                          overflow: TextOverflow.ellipsis),
                    ],
                  );
                },
              ),
            ),
            if (!_inRoom)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _joinRoom,
                  icon: const Icon(Icons.local_fire_department_rounded),
                  label: const Text('Join Campfire'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _toggleMic,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _muted
                              ? AppTheme.surface
                              : AppTheme.accent.withAlpha(30),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: _muted
                                  ? AppTheme.border
                                  : AppTheme.accent.withAlpha(100)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _muted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              color:
                                  _muted ? AppTheme.textDim : AppTheme.accent,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _muted ? 'Unmute' : 'Mute',
                              style: TextStyle(
                                  color: _muted
                                      ? AppTheme.textDim
                                      : AppTheme.accent,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _leaveRoom,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withAlpha(25),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: Colors.red.withAlpha(80)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.exit_to_app_rounded,
                                color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text('Leave',
                                style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
