import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme.dart';
import 'core/services.dart';
import 'core/constants.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/feed/feed_screen.dart';
import 'features/record/record_screen.dart';
import 'features/profile/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initHiveForFlutter();
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
  late GoRouter _router;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuthChange);
    _router = _buildRouter();
  }

  void _onAuthChange() => setState(() { _router = _buildRouter(); });

  GoRouter _buildRouter() => GoRouter(
    initialLocation: widget.auth.isLoggedIn ? '/' : '/login',
    redirect: (context, state) {
      final loggedIn = widget.auth.isLoggedIn;
      final onAuth = state.matchedLocation == '/login' || state.matchedLocation == '/register';
      if (!loggedIn && !onAuth) return '/login';
      if (loggedIn && onAuth) return '/';
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => widget.auth.isLoggedIn
            ? MainShell(child: child)
            : child,
        routes: [
          GoRoute(path: '/', builder: (_, __) => const FeedScreen()),
          GoRoute(path: '/record', builder: (_, __) => const RecordScreen()),
          GoRoute(path: '/profile/:username', builder: (_, state) => ProfileScreen(username: state.pathParameters['username']!)),
          GoRoute(path: '/clip/:id', builder: (_, state) => ClipDetailScreen(id: state.pathParameters['id']!)),
        ],
      ),
      GoRoute(path: '/login', builder: (_, __) => LoginScreen(auth: widget.auth)),
      GoRoute(path: '/register', builder: (_, __) => RegisterScreen(auth: widget.auth)),
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
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = location.startsWith('/record') ? 1 : location.startsWith('/profile') ? 2 : 0;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: idx,
          onTap: (i) {
            if (i == 0) context.go('/');
            if (i == 1) context.go('/record');
            if (i == 2) context.go('/profile/me');
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Feed'),
            BottomNavigationBarItem(icon: Icon(Icons.mic_rounded), label: 'Record'),
            BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// Placeholder for clip detail
class ClipDetailScreen extends StatelessWidget {
  final String id;
  const ClipDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clip')),
      body: Center(child: Text('Clip $id')),
    );
  }
}
