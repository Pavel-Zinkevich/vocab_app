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

    _sent = false; // reset any message
    _cooldown = 60; // start at 60 seconds
    _startCooldown(); // start the countdown immediately
    _startPolling(); // keep polling email verification
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
        // Do NOT call Navigator.pop() here — let the AuthGate rebuild and
        // replace this page. Popping here can cause the page to close
        // unexpectedly if this widget was presented in different ways.
        return;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cooldownTimer?.cancel(); // ✅ ADD THIS
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();

    _cooldownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  int _cooldown = 0;
  Timer? _cooldownTimer;
  Future<void> _sendVerification() async {
    print("BUTTON CLICKED");
    if (_cooldown > 0) return;

    setState(() => _loading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();

        setState(() {
          _sent = true;
          _cooldown = 60; // 60 seconds
        });

        _startCooldown();
      }
    } catch (e) {
      // handle error if needed
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent the user from using the system back button to escape the
      // verification flow. Use the "Cancel and sign out" button instead.
      onWillPop: () async => false,
      child: Scaffold(
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
                        onPressed: (_loading || _cooldown > 0)
                            ? null
                            : _sendVerification,
                        child: _loading
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _cooldown > 0
                                    ? 'Resend in $_cooldown s'
                                    : 'Resend email',
                              ),
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
      ),
    );
  }
}
