import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../core/queries.dart';
import '../../core/services.dart';
import '../../core/theme.dart';

class RegisterScreen extends StatefulWidget {
  final AuthService auth;
  const RegisterScreen({super.key, required this.auth});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    if (_name.text.trim().isEmpty || _username.text.trim().isEmpty ||
        _email.text.trim().isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final client = GraphQLProvider.of(context).value;
    final result = await client.mutate(MutationOptions(
      document: gql(kRegister),
      variables: {
        'email': _email.text.trim(),
        'password': _password.text,
        'name': _name.text.trim(),
        'username': _username.text.trim(),
      },
    ));
    if (!mounted) return;
    if (result.hasException) {
      setState(() { _error = result.exception!.graphqlErrors.isNotEmpty
          ? result.exception!.graphqlErrors.first.message
          : 'Registration failed'; _loading = false; });
      return;
    }
    final token = result.data!['register']['token'] as String;
    await widget.auth.setToken(token);
    if (mounted) context.go('/voice-bio');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.mic_rounded, color: Colors.white, size: 36),
                ),
              ),
              const SizedBox(height: 24),
              Text('Join Voxa', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text('Voice-first social network', style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 40),
              TextField(controller: _name, decoration: const InputDecoration(hintText: 'Full Name', prefixIcon: Icon(Icons.person_outline, color: AppTheme.textMuted))),
              const SizedBox(height: 12),
              TextField(
                controller: _username,
                decoration: const InputDecoration(hintText: 'Username (letters, numbers, _)', prefixIcon: Icon(Icons.alternate_email, color: AppTheme.textMuted)),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                  LengthLimitingTextInputFormatter(30),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted))),
              const SizedBox(height: 12),
              TextField(controller: _password, obscureText: true, decoration: const InputDecoration(hintText: 'Password (min 6 chars)', prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textMuted))),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.3))),
                  child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Create Account'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ', style: Theme.of(context).textTheme.bodyMedium),
                  GestureDetector(
                    onTap: () => context.go('/login'),
                    child: const Text('Sign In', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
