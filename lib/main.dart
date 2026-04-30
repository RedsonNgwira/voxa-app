import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'core/theme.dart';
import 'core/services.dart';
import 'core/fcm_service.dart';
import 'core/phoenix_socket.dart';
import 'core/me_provider.dart';
import 'core/queries.dart';
import 'core/cloudinary_service.dart';
import 'features/discover/search_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/feed/clip_card.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/onboarding/voice_bio_screen.dart';
import 'features/feed/feed_screen.dart';
import 'features/discover/discover_screen.dart';
import 'features/circles/circles_screen.dart';
import 'features/notifications/notifications_screen.dart';
import 'features/embers/embers_screen.dart';
import 'features/record/record_screen.dart';
import 'features/profile/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHiveForFlutter();
  await Firebase.initializeApp();
  final auth = AuthService();
  await auth.load();
  runApp(VoxaApp(auth: auth));
}

class VoxaApp extends StatefulWidget {
  final AuthService auth;
  const VoxaApp({super.key, required this.auth});

  @override
  State<VoxaApp> createState() => _VoxaAppState();
}

class _VoxaAppState extends State<VoxaApp> {
  bool _showSplash = true;
  late GoRouter _router;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChange);
    _router = _buildRouter();
  }

  void _onAuthChange() => setState(() { _router = _buildRouter(); });
  void _onSplashDone() => setState(() => _showSplash = false);

  GoRouter _buildRouter() => GoRouter(
    initialLocation: widget.auth.isLoggedIn ? '/' : '/login',
    redirect: (context, state) {
      final loggedIn = widget.auth.isLoggedIn;
      final onAuth = ['/login', '/register'].contains(state.matchedLocation);
      if (!loggedIn && state.matchedLocation != '/voice-bio' && !onAuth) return '/login';
      if (loggedIn && onAuth) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => LoginScreen(auth: widget.auth)),
      GoRoute(path: '/register', builder: (_, __) => RegisterScreen(auth: widget.auth)),
      GoRoute(path: '/voice-bio', builder: (_, __) => const VoiceBioScreen()),
      ShellRoute(
        builder: (_, __, child) => MeLoader(child: MainShell(child: child)),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const FeedScreen()),
          GoRoute(path: '/discover', builder: (_, __) => const DiscoverScreen()),
          GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
          GoRoute(path: '/circles', builder: (_, __) => const CirclesScreen()),
          GoRoute(path: '/circles/:id', builder: (_, s) => CircleDetailScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/embers', builder: (_, __) => const EmbersScreen()),
          GoRoute(path: '/record', builder: (_, __) => const RecordScreen()),
          GoRoute(path: '/profile/:username', builder: (_, s) => ProfileScreen(username: s.pathParameters['username']!)),
          GoRoute(path: '/clip/:id', builder: (_, s) => ClipDetailScreen(id: s.pathParameters['id']!)),
        ],
      ),
    ],
  );

  @override
  void dispose() {
    widget.auth.removeListener(_onAuthChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GraphQLProvider(
      client: GraphQLService.clientNotifier(widget.auth.token),
      child: MaterialApp.router(
        title: 'Voxa',
        theme: AppTheme.dark,
        routerConfig: _router,
        debugShowCheckedModeBanner: false,
        builder: (context, child) {
          if (_showSplash) return SplashScreen(onDone: _onSplashDone);
          return child ?? const SizedBox();
        },
      ),
    );
  }
}

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    final navIndex = switch (location) {
      '/' => 0,
      String l when l.startsWith('/discover') => 1,
      String l when l.startsWith('/circles') => 2,
      String l when l.startsWith('/notifications') => 3,
      String l when l.startsWith('/profile') => 4,
      _ => 0,
    };

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: navIndex,
          onTap: (i) {
            switch (i) {
              case 0: context.go('/');
              case 1: context.go('/discover');
              case 2: context.go('/circles');
              case 3: context.go('/notifications');
              case 4:
                final me = MeProvider.of(context);
                final username = me?['username'] as String? ?? 'me';
                context.go('/profile/$username');
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Feed'),
            BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: 'Discover'),
            BottomNavigationBarItem(icon: Icon(Icons.group_rounded), label: 'Circles'),
            BottomNavigationBarItem(icon: Icon(Icons.notifications_outlined), label: 'Alerts'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
      // Record FAB (spec 7.4)
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: FloatingActionButton(
          onPressed: () => context.push('/record'),
          backgroundColor: AppTheme.accent,
          elevation: 4,
          child: const Icon(Icons.mic_rounded, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class ClipDetailScreen extends StatefulWidget {
  final String id;
  const ClipDetailScreen({super.key, required this.id});

  @override
  State<ClipDetailScreen> createState() => _ClipDetailScreenState();
}

class _ClipDetailScreenState extends State<ClipDetailScreen> {
  Map<String, dynamic>? _clip;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(
      document: gql(kClip),
      variables: {'id': widget.id},
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    setState(() {
      if (!result.hasException) _clip = result.data!['clip'] as Map<String, dynamic>?;
      _loading = false;
    });
  }

  void _showReplySheet({bool isWhisper = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ReplySheet(
        postId: widget.id,
        isWhisper: isWhisper,
        onSent: () { Navigator.pop(context); _load(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.accent)));
    if (_clip == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Clip not found')));

    return Scaffold(
      appBar: AppBar(title: Text(_clip!['user']?['name'] ?? '')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClipCard(
              clip: _clip!,
              onReply: () => _showReplySheet(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showReplySheet(),
                    icon: const Icon(Icons.mic_rounded, size: 18),
                    label: const Text('Reply'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showReplySheet(isWhisper: true),
                    icon: const Icon(Icons.record_voice_over_outlined, size: 18),
                    label: const Text('Whisper'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textMuted,
                      side: const BorderSide(color: AppTheme.border),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet for recording a reply or whisper (spec 9.1, 9.2)
class _ReplySheet extends StatefulWidget {
  final String postId;
  final bool isWhisper;
  final VoidCallback onSent;
  const _ReplySheet({required this.postId, required this.isWhisper, required this.onSent});

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _uploading = false;
  String? _filePath;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  final List<double> _waveform = [];
  String? _error;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) { setState(() => _error = 'Mic permission denied'); return; }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/reply_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final amp = await _recorder.getAmplitude();
      final v = ((amp.current + 60) / 60).clamp(0.0, 1.0);
      if (mounted) setState(() {
        _waveform.add(v);
        if (_waveform.length % 10 == 0) _elapsed += const Duration(seconds: 1);
        if (_elapsed.inSeconds >= 180) _stop();
      });
    });
    setState(() { _isRecording = true; _filePath = path; _elapsed = Duration.zero; _waveform.clear(); });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await _recorder.stop();
    setState(() => _isRecording = false);
  }

  Future<void> _send() async {
    if (_filePath == null) return;
    setState(() { _uploading = true; _error = null; });
    try {
      final client = GraphQLProvider.of(context).value;
      final cloudinary = await CloudinaryService.uploadAudio(_filePath!, client);
      final step = _waveform.length / 48;
      final waveformData = List.generate(48, (i) => _waveform[(i * step).floor().clamp(0, _waveform.length - 1)]);
      final result = await client.mutate(MutationOptions(
        document: gql(kCreateReply),
        variables: {
          'postId': widget.postId,
          'audioUrl': cloudinary['url'],
          'cloudinaryPublicId': cloudinary['publicId'],
          'waveformData': waveformData,
          'durationSeconds': _elapsed.inSeconds,
          'isWhisper': widget.isWhisper,
        },
      ));
      if (!mounted) return;
      if (result.hasException) {
        setState(() { _error = 'Failed to send. Try again.'; _uploading = false; });
        return;
      }
      widget.onSent();
    } catch (e) {
      setState(() { _error = 'Error: $e'; _uploading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.isWhisper ? 'Send a Whisper' : 'Reply with voice',
            style: Theme.of(context).textTheme.titleLarge),
          if (widget.isWhisper)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Only the poster will hear this', style: Theme.of(context).textTheme.bodyMedium),
            ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _isRecording ? _stop : (_filePath == null ? _start : null),
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red : AppTheme.accent,
              ),
              child: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 32),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isRecording
                ? '${_elapsed.inSeconds}s recording...'
                : _filePath != null ? 'Recorded ✓' : 'Tap to record',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          if (_filePath != null && !_isRecording) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => setState(() { _filePath = null; _waveform.clear(); _elapsed = Duration.zero; }),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.textMuted, side: const BorderSide(color: AppTheme.border)),
                child: const Text('Redo'),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: _uploading ? null : _send,
                child: _uploading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(widget.isWhisper ? 'Send Whisper' : 'Send Reply'),
              )),
            ]),
          ],
        ],
      ),
    );
  }
}
