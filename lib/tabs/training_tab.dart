import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../pages/flashcards_page.dart';
import '../service/language_service.dart';

const String kDefaultLanguage = 'fr';

class TrainingTab extends StatefulWidget {
  @override
  State<TrainingTab> createState() => _TrainingTabState();
}

class _TrainingTabState extends State<TrainingTab> {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  int dueCount = 0;
  bool loading = true;

  String _effectiveLanguage(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim().toLowerCase();
    }
    return kDefaultLanguage;
  }

  @override
  void initState() {
    super.initState();
    loadDueCount();
    LanguageService.instance.addListener(_onLangChanged);
  }

  void _onLangChanged() {
    loadDueCount();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    LanguageService.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  Future<void> loadDueCount() async {
    final currentLang = LanguageService.instance.currentLang;
    final u = auth.currentUser;
    if (u == null) return;

    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    final snap =
        await db.collection('users').doc(u.uid).collection('vocabulary').get();

    final now = DateTime.now();

    final words = snap.docs
        .map((d) => d.data())
        .where((w) => _effectiveLanguage(w['language']) == currentLang)
        .toList();

    final due = words.where((w) {
      final n = w['nextReview'];
      final t = n is Timestamp ? n.toDate() : DateTime.tryParse('$n');
      return t == null || t.isBefore(now);
    }).length;

    if (!mounted) return;

    setState(() {
      dueCount = due;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;

    final textColor =
        Theme.of(context).floatingActionButtonTheme.foregroundColor ??
            Theme.of(context).colorScheme.onPrimary;

    final cardColor =
        Theme.of(context).floatingActionButtonTheme.backgroundColor ??
            Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        title: Text(
          "Training",
          style: TextStyle(
            color: Theme.of(context).appBarTheme.titleTextStyle?.color ??
                Theme.of(context).colorScheme.onSurface,
          ),
        ),
        iconTheme: IconThemeData(
          color: Theme.of(context).appBarTheme.iconTheme?.color ??
              Theme.of(context).colorScheme.onSurface,
        ),
        actions: [
          IconButton(
            tooltip: 'Toggle language',
            onPressed: () async {
              final next =
                  LanguageService.instance.currentLang == 'fr' ? 'es' : 'fr';
              await LanguageService.instance.setLanguage(next);
            },
            icon: Text(
              LanguageService.instance.currentLang == 'fr' ? '🇫🇷' : '🇪🇸',
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
      body: Center(
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FlashcardsPage()),
            ).then((_) => loadDueCount());
          },
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.style,
                  color: textColor,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Text(
                  loading ? "Flashcards" : "Flashcards ($dueCount)",
                  style: TextStyle(
                    fontSize: 20,
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
