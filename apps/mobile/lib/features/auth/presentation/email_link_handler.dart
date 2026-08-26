import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/auth_repository.dart';
import '../data/email_link_config.dart';

/// Wraps the app and listens for the email-link sign-in deep link (App
/// Links on Android, Universal Links on iOS — see
/// `apps/mobile/docs/email-link-setup.md` for the native-side config this
/// depends on).
///
/// When a valid sign-in link arrives, completes the sign-in using the
/// email cached by [EmailLinkSignInScreen] (same device), or prompts for it
/// if the link was opened on a different device than it was requested
/// from.
class EmailLinkHandler extends StatefulWidget {
  const EmailLinkHandler({
    required this.navigatorKey,
    required this.child,
    super.key,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<EmailLinkHandler> createState() => _EmailLinkHandlerState();
}

class _EmailLinkHandlerState extends State<EmailLinkHandler> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  @override
  void initState() {
    super.initState();
    // `uriLinkStream` delivers both the cold-start link (app opened fresh
    // from the emailed link) and any link received while already running.
    // Guarded: the platform channel this relies on isn't available in the
    // widget-test environment (or on a platform where app_links hasn't been
    // set up yet), and that shouldn't crash the rest of the app.
    try {
      _subscription = _appLinks.uriLinkStream.listen(_handleUri, onError: (_) {});
    } catch (_) {
      // No-op — email-link sign-in just won't auto-complete from a deep
      // link in this environment.
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _handleUri(Uri uri) async {
    final link = uri.toString();
    final repository = context.read<AuthRepository>();
    if (!repository.isSignInWithEmailLink(link)) return;

    final prefs = await SharedPreferences.getInstance();
    var email = prefs.getString(emailLinkCachedEmailKey);

    if (email == null) {
      final navContext = widget.navigatorKey.currentContext;
      if (navContext == null) return;
      email = await showDialog<String>(
        context: navContext,
        barrierDismissible: false,
        builder: (context) => const _ConfirmEmailDialog(),
      );
    }
    if (email == null || email.isEmpty) return;

    try {
      await repository.signInWithEmailLink(email: email, emailLink: link);
      await prefs.remove(emailLinkCachedEmailKey);
    } on AuthFailure catch (e) {
      final ctx = widget.navigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ConfirmEmailDialog extends StatefulWidget {
  const _ConfirmEmailDialog();

  @override
  State<_ConfirmEmailDialog> createState() => _ConfirmEmailDialogState();
}

class _ConfirmEmailDialogState extends State<_ConfirmEmailDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm your email'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.emailAddress,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'you@example.com'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
