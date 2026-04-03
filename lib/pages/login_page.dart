import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'register_page.dart';

/// Login page supporting email/password sign-in and Google sign-in.
class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _error = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // userChanges() in AuthGate will react and navigate automatically
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message ?? 'Authentication failed';
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        await FirebaseAuth.instance.signInWithPopup(provider);
        return;
      }

      // Initialize the sign-in plugin
      await GoogleSignIn.instance.initialize();

      // Launch Google account selector
      final account = await GoogleSignIn.instance.authenticate();
      if (account == null) return; // user cancelled

      // Get ID token
      final googleAuth = await account.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null) {
        throw Exception('Failed to get Google ID token');
      }

      // Create credential for Firebase
      final credential = GoogleAuthProvider.credential(idToken: idToken);

      // Sign in to Firebase
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Google sign-in failed');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Google sign-in failed')));
    } catch (e) {
      final msg = 'Google Sign-In error: $e';
      setState(() => _error = msg);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailCtrl = TextEditingController(text: _emailController.text);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset password'),
        content: TextField(
          controller: emailCtrl,
          decoration: InputDecoration(labelText: 'Email'),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel')),
          TextButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;
              Navigator.of(context).pop();
              try {
                await FirebaseAuth.instance
                    .sendPasswordResetEmail(email: email);
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Password reset email sent')));
              } on FirebaseAuthException catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message ?? 'Error')));
              }
            },
            child: Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty)
                            return 'Email is required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(labelText: 'Password'),
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Password is required';
                          if (v.length < 6)
                            return 'Password must be at least 6 characters';
                          if (!RegExp(r'[A-Za-z]').hasMatch(v))
                            return 'Password must contain at least one letter';
                          return null;
                        },
                      ),
                      SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: Text('Forgot password?'),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(_error!,
                              style: TextStyle(color: Colors.red)),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _signIn,
                          child: _loading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text('Sign in'),
                        ),
                      ),
                      SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.login),
                          label: Text('Sign in with Google'),
                          onPressed: _loading ? null : _signInWithGoogle,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Don't have an account?"),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) => RegisterPage()));
                                  },
                            child: Text('Register'),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
