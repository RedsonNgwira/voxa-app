import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'core/theme.dart';
import 'core/services.dart';
import 'core/fcm_service.dart';
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
import 'features/prompts/prompt_screen.dart';
import 'features/campfire/campfire_screen.dart';
import 'features/threads/threads_screen.dart';
import 'features/threads/thread_detail_screen.dart';
import 'features/whispers/whisper_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHiveForFlutter();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase may not be configured in all environments
  }
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
    // Handle notification taps — navigate based on type
    onNotificationTap = (postId, type) {
      if (type == 'CAMPFIRE' && postId != null) {
        _router.push('/campfire/$postId');
      } else if (type == 'WHISPER' && postId != null) {
        _router.push('/whispers/$postId');
      } else if (postId != null) {
        _router.push('/clip/$postId');
      }
    };
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
      GoRoute(path: '/voice-bio', builder: (_, __) => VoiceBioScreen(token: widget.auth.token)),
      ShellRoute(
        builder: (_, __, child) => AuthProvider(
          auth: widget.auth,
          child: MeLoader(child: MainShell(child: child)),
        ),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const FeedScreen()),
          GoRoute(path: '/discover', builder: (_, __) => const DiscoverScreen()),
          GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
          GoRoute(path: '/circles', builder: (_, __) => const CirclesScreen()),
          GoRoute(path: '/circles/:id', builder: (_, s) => CircleDetailScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
          GoRoute(path: '/embers', builder: (_, __) => const EmbersScreen()),
          GoRoute(path: '/record', builder: (_, s) => RecordScreen(
            preselectedCircleId: s.uri.queryParameters['circleId'],
            promptId: s.uri.queryParameters['promptId'],
            promptText: s.uri.queryParameters['promptText'],
            initialMood: s.uri.queryParameters['mood'],
            threadId: s.uri.queryParameters['threadId'],
          )),
          GoRoute(path: '/profile/:username', builder: (_, s) => ProfileScreen(username: s.pathParameters['username']!)),
          GoRoute(path: '/clip/:id', builder: (_, s) => ClipDetailScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/prompts', builder: (_, __) => const PromptScreen()),
          GoRoute(path: '/campfires', builder: (_, __) => const CampfireScreen()),
          GoRoute(path: '/campfire/:id', builder: (_, s) => CampfireDetailScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/threads', builder: (_, __) => const ThreadsScreen()),
          GoRoute(path: '/thread/:id', builder: (_, s) => ThreadDetailScreen(id: s.pathParameters['id']!)),
          GoRoute(path: '/whispers/:clipId', builder: (_, s) => WhisperScreen(clipId: s.pathParameters['clipId']!)),
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

/// InheritedWidget to provide AuthService down the tree
class AuthProvider extends InheritedWidget {
  final AuthService auth;

  const AuthProvider({super.key, required this.auth, required super.child});

  static AuthService? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthProvider>()?.auth;

  @override
  bool updateShouldNotify(AuthProvider old) => auth != old.auth;
}

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    // Hide bottom nav on record, clip detail, and campfire detail screens
    final hideNav = location == '/record' ||
        location.startsWith('/clip/') ||
        location.startsWith('/campfire/') ||
        location == '/prompts' ||
        location == '/campfires' ||
        location == '/threads' ||
        location.startsWith('/thread/');

    final navIndex = switch (location) {
      '/' => 0,
      String l when l.startsWith('/discover') || l.startsWith('/search') => 1,
      String l when l.startsWith('/circles') => 2,
      String l when l.startsWith('/notifications') => 3,
      String l when l.startsWith('/profile') => 4,
      _ => 0,
    };

    return Scaffold(
      body: child,
      bottomNavigationBar: hideNav ? null : _VoxaBottomNav(
        currentIndex: navIndex,
        onRecordTap: () => context.push('/record'),
      ),
    );
  }
}

/// Custom bottom navigation bar with centered record button
class _VoxaBottomNav extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onRecordTap;

  const _VoxaBottomNav({required this.currentIndex, required this.onRecordTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.black,
        border: const Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_rounded, label: 'Feed', active: currentIndex == 0,
                onTap: () => context.go('/')),
              _NavItem(icon: Icons.explore_rounded, label: 'Discover', active: currentIndex == 1,
                onTap: () => context.go('/discover')),
              // Centered record button
              GestureDetector(
                onTap: onRecordTap,
                child: Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.accent, Color(0xFFC0431A)],
                    ),
                    boxShadow: [
                      BoxShadow(color: AppTheme.accent.withOpacity(0.4), blurRadius: 16, spreadRadius: 2),
                      BoxShadow(color: AppTheme.accent.withOpacity(0.15), blurRadius: 4, spreadRadius: 4),
                    ],
                  ),
                  child: const Icon(Icons.mic_rounded, color: Colors.white, size: 26),
                ),
              ),
              _NavItem(icon: Icons.notifications_outlined, label: 'Alerts', active: currentIndex == 3,
                onTap: () => context.go('/notifications')),
              _NavItem(icon: Icons.person_rounded, label: 'Profile', active: currentIndex == 4,
                onTap: () {
                  final me = MeProvider.of(context);
                  final username = me?['username'] as String?;
                  if (username != null) {
                    context.go('/profile/$username');
                  }
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: active ? AppTheme.accent : AppTheme.textDim),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              fontSize: 10,
              color: active ? AppTheme.accent : AppTheme.textDim,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            )),
          ],
        ),
      ),
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
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
      );
    }
    if (_clip == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mic_off_rounded, size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              const Text('Voice not found', style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => context.go('/'), child: const Text('Go home')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_clip!['user']?['name'] ?? '')),
      body: RefreshIndicator(
        color: AppTheme.accent,
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              // Replies list
              if ((_clip!['replies'] as List?)?.isNotEmpty == true) ...[
                const SizedBox(height: 24),
                Text('Replies', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...(_clip!['replies'] as List).cast<Map<String, dynamic>>()
                    .where((r) => r['isWhisper'] != true)
                    .map((r) => ClipCard(clip: r)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for recording a reply or whisper
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
  final _player = AudioPlayer();
  bool _isRecording = false;
  bool _isPlaying = false;
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
    _player.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) { setState(() => _error = 'Mic permission denied'); return; }
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/reply_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final amp = await _recorder.getAmplitude();
      final v = ((amp.current + 60) / 60).clamp(0.0, 1.0);
      if (mounted) setState(() {
        _waveform.add(v);
        _elapsed += const Duration(milliseconds: 100);
        if (_elapsed.inSeconds >= 180) _stop();
      });
    });
    setState(() { _isRecording = true; _filePath = path; _elapsed = Duration.zero; _waveform.clear(); _error = null; });
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await _recorder.stop();
    setState(() => _isRecording = false);
  }

  Future<void> _togglePreview() async {
    if (_filePath == null) return;
    if (_isPlaying) {
      await _player.pause();
      setState(() => _isPlaying = false);
    } else {
      try {
        if (_player.processingState == ProcessingState.idle ||
            _player.processingState == ProcessingState.completed) {
          await _player.setFilePath(_filePath!);
        }
        await _player.seek(Duration.zero);
        await _player.play();
        setState(() => _isPlaying = true);
        _player.playerStateStream.firstWhere(
          (s) => s.processingState == ProcessingState.completed,
        ).then((_) { if (mounted) setState(() => _isPlaying = false); });
      } catch (_) {}
    }
  }

  Future<void> _send() async {
    if (_filePath == null) return;
    setState(() { _uploading = true; _error = null; });
    try {
      final client = GraphQLProvider.of(context).value;
      final cloudinary = await CloudinaryService.uploadAudio(_filePath!);
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
    } on CloudinaryUploadException catch (e) {
      if (mounted) setState(() { _error = e.message; _uploading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Error sending. Try again.'; _uploading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRecording = _filePath != null && !_isRecording;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(widget.isWhisper ? 'Send a Whisper' : 'Reply with voice',
            style: Theme.of(context).textTheme.titleLarge),
          if (widget.isWhisper)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Only the poster will hear this',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textDim)),
            ),
          const SizedBox(height: 24),
          // Record / preview button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (hasRecording) ...[
                // Preview
                GestureDetector(
                  onTap: _togglePreview,
                  child: Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.accent.withOpacity(0.4)),
                    ),
                    child: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: AppTheme.accent, size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              GestureDetector(
                onTap: _isRecording ? _stop : (hasRecording ? null : _start),
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording ? Colors.red : (hasRecording ? AppTheme.surface : AppTheme.accent),
                    border: hasRecording && !_isRecording ? Border.all(color: AppTheme.border) : null,
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : (hasRecording ? Icons.check_rounded : Icons.mic_rounded),
                    color: hasRecording && !_isRecording ? AppTheme.accent : Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isRecording
                ? '${_elapsed.inSeconds}s recording...'
                : hasRecording ? 'Recorded ${_elapsed.inSeconds}s' : 'Tap to record',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          if (hasRecording) ...[
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () {
                  _player.stop();
                  setState(() { _filePath = null; _waveform.clear(); _elapsed = Duration.zero; _isPlaying = false; });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textMuted,
                  side: const BorderSide(color: AppTheme.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Redo'),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: _uploading ? null : _send,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
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
