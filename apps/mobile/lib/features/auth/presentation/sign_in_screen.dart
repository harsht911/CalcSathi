import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/auth_repository.dart';
import 'email_link_sign_in_screen.dart';
import 'sign_up_screen.dart';

// Apple Sign-In is deliberately not wired up yet: it needs the $99/year
// Apple Developer Program membership, which hasn't been decided on (see
// the milestone roadmap's M1 notes). The `sign_in_with_apple` dependency
// is already in pubspec.yaml so adding the button later is additive, not a
// redesign — no UI element for it here in the meantime.

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await context.read<AuthRepository>().signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    } on AuthFailure catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await context.read<AuthRepository>().signInWithGoogle();
    } on AuthFailure catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorText = 'Enter your email above first, then tap "Forgot password?" again.';
      });
      return;
    }
    try {
      await context.read<AuthRepository>().sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to $email.')),
        );
      }
    } on AuthFailure catch (e) {
      setState(() => _errorText = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome back',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to CalcSathi',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || !value.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value == null || value.length < 6) ? 'At least 6 characters' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _submitting ? null : _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorText!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const EmailLinkSignInScreen()),
                            ),
                    child: const Text('Sign in with an email link instead'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const SignUpScreen()),
                                ),
                        child: const Text('Sign up'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
