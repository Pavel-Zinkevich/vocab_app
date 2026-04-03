import 'package:flutter/material.dart';
import 'tabs/vocabulary_tab.dart';
import 'tabs/training_tab.dart';
import 'tabs/profile_tab.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(VocabApp());
}

class VocabApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vocab App',
      theme: ThemeData(
        useMaterial3: true,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor:
            const Color.fromARGB(255, 167, 86, 86), // light grey background for the whole app
      ),
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return LoginPage();
        } else {
          return HomePage();
        }
      },
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final _pages = [
    VocabularyTab(),
    TrainingTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Each page provides its own AppBar / FAB when needed.
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Vocabulary'),
          BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Training'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
