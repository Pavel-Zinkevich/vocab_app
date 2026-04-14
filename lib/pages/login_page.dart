import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'register_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Login page supporting email/password sign-in and Google sign-in.
class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

// AuthService singleton for Google sign-in
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google (Web + Mobile)
  Future<User?> signInWithGoogle(BuildContext context) async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        await _auth.signInWithPopup(provider);
        return _auth.currentUser;
      } else {
        final provider = GoogleAuthProvider();
        final userCredential = await _auth.signInWithProvider(provider);
        return userCredential.user;
      }
    } on FirebaseAuthException catch (e) {
      final msg = 'Google Sign-In error: ${e.message}';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return null;
    } catch (e) {
      final msg = 'Unexpected error: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return null;
    }
  }

  Future<void> logout() async {
    final user = FirebaseAuth.instance.currentUser;

    // 1. clear local cache
    if (user != null) {
      await Hive.deleteBoxFromDisk('history_${user.uid}');
      // await Hive.deleteBoxFromDisk('vocab_${user.uid}');
    }

    // 2. sign out
    await FirebaseAuth.instance.signOut();
  }
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  List<String> _savedEmails = [];

  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedEmails(); // 👈 call your function here
  }

  Future<void> _loadSavedEmails() async {
    final box = await Hive.openBox('login_cache');
    final emails = box.get('emails');

    if (emails != null) {
      setState(() {
        _savedEmails = List<String>.from(emails);
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // ---------------------------
      // 1. SAVE LAST 2 EMAILS (FIXED)
      // ---------------------------
      final box = await Hive.openBox('login_cache');
      final email = _emailController.text.trim();

      final raw = box.get('emails');
      List<String> emails = [];

      if (raw is List) {
        emails = raw.map((e) => e.toString()).toList();
      }

      // remove if exists (move to most recent position)
      emails.remove(email);

      // add as latest
      emails.add(email);

      // keep only last 2
      if (emails.length > 2) {
        emails = emails.sublist(emails.length - 2);
      }

      await box.put('emails', emails);

      // update UI list (autocomplete)
      if (mounted) {
        setState(() {
          _savedEmails = List<String>.from(emails.reversed);
        });
      }

      // ---------------------------
      // 2. FIREBASE SIGN IN
      // ---------------------------
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      User? user = userCredential.user;

      if (user != null) {
        await user.reload();
        user = FirebaseAuth.instance.currentUser;

        // ---------------------------
        // 3. EMAIL VERIFICATION CHECK
        // ---------------------------
        if (!user!.emailVerified) {
          try {
            await user.sendEmailVerification();
          } catch (_) {}

          if (mounted) {
            setState(() {
              _error =
                  'Please verify your email before logging in. A verification email has been sent.';
              _loading = false;
            });
          }
          return;
        }

        // ---------------------------
        // 4. SAVE USER TO FIRESTORE
        // ---------------------------
        final userDoc =
            FirebaseFirestore.instance.collection('users').doc(user.uid);

        final docSnapshot = await userDoc.get();

        if (!docSnapshot.exists) {
          await userDoc.set({
            'email': user.email,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Welcome back, ${user.email}!')),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Invalid email or password';
        });
      }
      debugPrint('FirebaseAuth error code: ${e.code}, message: ${e.message}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unexpected error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final user = await AuthService().signInWithGoogle(context);

      if (user == null) return;

      // ✅ Save/update Firestore user
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        await userDoc.set({
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
          'authProvider': 'google',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Signed in as ${user.email}')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Google sign-in failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
            child: Text('Cancel'),
          ),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // EMAIL
                      Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<String>.empty();
                          }

                          return _savedEmails.where((email) => email
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase()));
                        },

                        onSelected: (String selection) {
                          _emailController.text = selection;
                        },

                        // 👇 THIS is where you add it
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              child: SizedBox(
                                width: 300,
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  children: options.map((e) {
                                    return ListTile(
                                      title: Text(e),
                                      onTap: () => onSelected(e),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          );
                        },

                        fieldViewBuilder:
                            (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: controller, // ✅ MUST use this
                            focusNode: focusNode,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(labelText: 'Email'),

                            onChanged: (value) {
                              _emailController.text =
                                  value; // keep your Firebase controller in sync
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      // PASSWORD (FIXED: was missing)
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // LOGIN BUTTON (FIXED: was missing)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _signIn,
                          child: _loading
                              ? CircularProgressIndicator()
                              : Text('Sign in'),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // GOOGLE SIGN-IN
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _loading ? null : _signInWithGoogle,
                          child: Text('Sign in with Google'),
                        ),
                      ),

                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: TextStyle(color: Colors.red),
                        ),
                      ],

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account?"),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => RegisterPage(),
                                      ),
                                    );
                                  },
                            child: const Text("Register"),
                          ),
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
