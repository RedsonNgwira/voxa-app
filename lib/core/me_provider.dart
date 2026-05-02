import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'queries.dart';

/// Loads and caches the current user's me data
class MeProvider extends InheritedWidget {
  final Map<String, dynamic>? me;

  const MeProvider({super.key, required this.me, required super.child});

  static Map<String, dynamic>? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MeProvider>()?.me;

  @override
  bool updateShouldNotify(MeProvider old) => me != old.me;
}

class MeLoader extends StatefulWidget {
  final Widget child;
  const MeLoader({super.key, required this.child});

  @override
  State<MeLoader> createState() => _MeLoaderState();
}

class _MeLoaderState extends State<MeLoader> {
  Map<String, dynamic>? _me;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  Future<void> _load() async {
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(
      document: gql(kMe),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted || result.hasException || result.data == null) return;
    setState(() => _me = result.data!['me'] as Map<String, dynamic>?);
  }

  @override
  Widget build(BuildContext context) => MeProvider(me: _me, child: widget.child);
}
