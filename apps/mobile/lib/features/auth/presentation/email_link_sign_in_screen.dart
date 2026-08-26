import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/auth_repository.dart';
import '../data/email_link_config.dart';

class EmailLinkSignInScreen extends StatefulWidget {
  const EmailLinkSignInScreen({super.key});

  @override
  State<EmailLinkSignInScreen> createState() => _EmailLinkSignInScreenState();
}

class _EmailLinkSignInScreenState extends State<EmailLinkSignInScreen> {
  final _emailController = TextEditingController();
  bool _submitting = false;
  bool _sent = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _errorText = 'Enter a valid email');
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await context.read<AuthRepository>().sendSignInLinkToEmail(
            email: email,
            actionCodeSettings: emailLinkActionCodeSettings,
          );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(emailLinkCachedEmailKey, email);
      if (mounted) setState(() => _sent = true);
    } on AuthFailure catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in with email link')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _sent ? _buildSentView(context) : _buildFormView(context),
        ),
      ),
    );
  }

  Widget _buildSentView(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 64),
        const SizedBox(height: 16),
        Text(
          'Check your inbox — we sent a sign-in link to ${_emailController.text.trim()}.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text('Open it on this device to finish signing in.', textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildFormView(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text("We'll email you a link — no password needed."),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 8),
          Text(_errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _submitting ? null : _send,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send link'),
        ),
      ],
    );
  }
}
