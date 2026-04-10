import 'package:flutter/material.dart';
import 'tabs/vocabulary_tab.dart';
import 'tabs/training_tab.dart';
import 'tabs/profile_tab.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/email_verification_page.dart';

import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();
  await Hive.openBox('vocab');

  runApp(VocabApp());
}

class VocabApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vocab App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.learning,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.navBar,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppColors.navBarIcon),
          titleTextStyle: TextStyle(
            color: AppColors.navBarText,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppColors.navBar,
          selectedItemColor: AppColors.learning,
          unselectedItemColor: AppColors.navBarIcon.withOpacity(0.5),
          showUnselectedLabels: true,
          elevation: 8,
          type: BottomNavigationBarType.fixed,
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.learning,
          foregroundColor: Colors.white,
          elevation: 6,
        ),
      ),
      home: AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.learning,
              ),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return LoginPage();
        }

        if (!user.emailVerified) {
          return EmailVerificationPage();
        }

        return HomePage();
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
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          backgroundColor: AppColors.navBar,
          selectedItemColor: AppColors.learning,
          unselectedItemColor: AppColors.navBarIcon.withOpacity(0.6),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.book),
              label: 'Vocabulary',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school),
              label: 'Training',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
