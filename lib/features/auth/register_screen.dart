import 'dart:async';
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

  // Username availability
  Timer? _usernameDebounce;
  bool? _usernameAvailable; // null = unchecked, true = available, false = taken
  bool _checkingUsername = false;
  String? _usernameError;

  // Email validation
  String? _emailError;

  // Password strength
  int _passwordStrength = 0; // 0-3

  @override
  void initState() {
    super.initState();
    _username.addListener(_onUsernameChanged);
    _email.addListener(_onEmailChanged);
    _password.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final val = _username.text;
    _usernameDebounce?.cancel();
    setState(() { _usernameAvailable = null; _usernameError = null; });

    if (val.isEmpty) return;
    if (val.length < 3) {
      setState(() => _usernameError = 'At least 3 characters');
      return;
    }
    if (val.length > 30) {
      setState(() => _usernameError = 'Max 30 characters');
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(val)) {
      setState(() => _usernameError = 'Letters, numbers and _ only');
      return;
    }

    _usernameDebounce = Timer(const Duration(milliseconds: 600), () => _checkUsername(val));
  }

  Future<void> _checkUsername(String username) async {
    setState(() => _checkingUsername = true);
    try {
      final client = GraphQLProvider.of(context).value;
      final result = await client.query(QueryOptions(
        document: gql(kCheckUsername),
        variables: {'username': username},
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      if (!mounted) return;
      final available = result.data?['checkUsername'] as bool? ?? false;
      setState(() {
        _usernameAvailable = available;
        _usernameError = available ? null : 'Username already taken';
        _checkingUsername = false;
      });
    } catch (_) {
      if (mounted) setState(() => _checkingUsername = false);
    }
  }

  void _onEmailChanged() {
    final val = _email.text.trim();
    if (val.isEmpty) { setState(() => _emailError = null); return; }
    final valid = RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(val);
    setState(() => _emailError = valid ? null : 'Invalid email format');
  }

  void _onPasswordChanged() {
    final val = _password.text;
    int strength = 0;
    if (val.length >= 6) strength++;
    if (val.length >= 10) strength++;
    if (RegExp(r'[A-Z]').hasMatch(val) || RegExp(r'[0-9]').hasMatch(val)) strength++;
    setState(() => _passwordStrength = strength);
  }

  Future<void> _register() async {
    if (_name.text.trim().isEmpty || _username.text.trim().isEmpty ||
        _email.text.trim().isEmpty) {
      setState(() => _error = 'All fields are required');
      return;
    }
    if (_usernameError != null) {
      setState(() => _error = _usernameError);
      return;
    }
    if (_usernameAvailable == false) {
      setState(() => _error = 'Username already taken');
      return;
    }
    if (_emailError != null) {
      setState(() => _error = 'Please enter a valid email');
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
      setState(() {
        _error = result.exception!.graphqlErrors.isNotEmpty
            ? result.exception!.graphqlErrors.first.message
            : 'Registration failed';
        _loading = false;
      });
      return;
    }
    final token = result.data!['register']['token'] as String;
    await widget.auth.setToken(token);
    if (mounted) context.go('/voice-bio');
  }

  Color get _strengthColor => switch (_passwordStrength) {
    1 => Colors.red,
    2 => Colors.orange,
    3 => Colors.green,
    _ => AppTheme.border,
  };

  String get _strengthLabel => switch (_passwordStrength) {
    1 => 'Weak',
    2 => 'Good',
    3 => 'Strong',
    _ => '',
  };

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

              // Full name
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  hintText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline, color: AppTheme.textMuted),
                ),
              ),
              const SizedBox(height: 12),

              // Username with availability indicator
              TextField(
                controller: _username,
                decoration: InputDecoration(
                  hintText: 'Username',
                  prefixIcon: const Icon(Icons.alternate_email, color: AppTheme.textMuted),
                  suffixIcon: _checkingUsername
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent)),
                        )
                      : _usernameAvailable == true
                          ? const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20)
                          : _usernameAvailable == false
                              ? const Icon(Icons.cancel_rounded, color: Colors.red, size: 20)
                              : null,
                  errorText: _usernameError,
                  helperText: _usernameAvailable == true ? 'Available ✓' : null,
                  helperStyle: const TextStyle(color: Colors.green, fontSize: 12),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9_]')),
                  LengthLimitingTextInputFormatter(30),
                ],
              ),
              const SizedBox(height: 12),

              // Email with inline validation
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.textMuted),
                  errorText: _emailError,
                ),
              ),
              const SizedBox(height: 12),

              // Password with strength indicator
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Password (min 6 chars)',
                  prefixIcon: Icon(Icons.lock_outline, color: AppTheme.textMuted),
                ),
              ),
              if (_password.text.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    ...List.generate(3, (i) => Expanded(
                      child: Container(
                        height: 3,
                        margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                        decoration: BoxDecoration(
                          color: i < _passwordStrength ? _strengthColor : AppTheme.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )),
                    const SizedBox(width: 8),
                    Text(_strengthLabel, style: TextStyle(color: _strengthColor, fontSize: 11)),
                  ],
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
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
