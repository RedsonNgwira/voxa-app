import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme.dart';
import 'core/services.dart';
import 'core/fcm_service.dart';
import 'core/phoenix_socket.dart';
import 'core/me_provider.dart';
import 'features/auth/splash_screen.dart';
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
      final onAuth = ['/login', '/register', '/voice-bio'].contains(state.matchedLocation);
      if (!loggedIn && !onAuth) return '/login';
      if (loggedIn && onAuth && state.matchedLocation != '/voice-bio') return '/';
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

class ClipDetailScreen extends StatelessWidget {
  final String id;
  const ClipDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clip')),
      body: Center(child: Text('Clip $id', style: Theme.of(context).textTheme.bodyLarge)),
    );
  }
}
