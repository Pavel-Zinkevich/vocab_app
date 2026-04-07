import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Simple page that tells the user to verify their email.
/// It polls the current user's emailVerified flag every 3 seconds and
/// navigates back automatically when verified.
class EmailVerificationPage extends StatefulWidget {
  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  Timer? _timer;
  bool _sent = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 3), (_) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await user.reload();
      final reloaded = FirebaseAuth.instance.currentUser;
      if (reloaded != null && reloaded.emailVerified) {
        _timer?.cancel();
        // AuthGate will re-evaluate when FirebaseAuth.userChanges emits after reload.
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sendVerification() async {
    setState(() {
      _loading = true;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        setState(() => _sent = true);
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verify your email')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'A verification email was sent to your address.\nPlease open it and tap the verification link.\nYou will be redirected here automatically when verified.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                SizedBox(height: 16),
                if (_sent)
                  Text('Verification email resent',
                      style: TextStyle(color: Colors.green)),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _loading ? null : _sendVerification,
                      child: _loading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('Resend email'),
                    ),
                    SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _signOut,
                      child: Text('Cancel and sign out'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
