import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

import 'tabs/vocabulary_tab.dart';
import 'tabs/training_tab.dart';
import 'tabs/profile_tab.dart';

import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/email_verification_page.dart';

import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Hive.initFlutter();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Vocab App',
          themeMode: mode,
          theme: ThemeController.lightTheme,
          darkTheme: ThemeController.darkTheme,
          home: const AuthGate(),
          routes: {
            '/login': (_) => LoginPage(),
            '/register': (_) => RegisterPage(),
            '/verify-email': (_) => EmailVerificationPage(),
            '/home': (_) => const HomeTabsPage(),
          },
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: CircularProgressIndicator(
                color: colorScheme.primary,
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

        return const HomeTabsPage();
      },
    );
  }
}

class HomeTabsPage extends StatefulWidget {
  const HomeTabsPage({super.key});

  @override
  State<HomeTabsPage> createState() => _HomeTabsPageState();
}

class _HomeTabsPageState extends State<HomeTabsPage> {
  int _selectedIndex = 0;
  late final PageController _pageController;

  late final List<Widget> _pages = [
    const VocabularyTab(),
    TrainingTab(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  void _onNavTapped(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navTheme = Theme.of(context).bottomNavigationBarTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final navBg = navTheme.backgroundColor ?? colorScheme.surface;
    final selectedColor = navTheme.selectedItemColor ?? colorScheme.primary;
    final unselectedColor =
        navTheme.unselectedItemColor ?? colorScheme.onSurface.withOpacity(0.6);

    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: navBg,
        selectedItemColor: selectedColor,
        unselectedItemColor: unselectedColor,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
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
    );
  }
}
