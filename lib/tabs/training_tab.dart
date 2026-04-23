import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

import '../pages/flashcards_page.dart';
import '../service/language_service.dart';

class TrainingTab extends StatefulWidget {
  @override
  State<TrainingTab> createState() => _TrainingTabState();
}

class _TrainingTabState extends State<TrainingTab> {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  int dueCount = 0;
  bool loading = true;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreVocabSub;
  ValueListenable<dynamic>? _boxListenable;
  Box? _box;

  @override
  void initState() {
    super.initState();
    LanguageService.instance.addListener(_onLangChanged);
    _initListeners();
  }

  void _onLangChanged() {
    // reinitialize listeners when language changes
    _initListeners();
  }

  @override
  void dispose() {
    LanguageService.instance.removeListener(_onLangChanged);
    _disposeListeners();
    super.dispose();
  }

  Future<void> loadDueCount() async {
    final currentLang = LanguageService.instance.currentLang;
    final u = auth.currentUser;
    if (u == null) return;

    final snap =
        await db.collection('users').doc(u.uid).collection('vocabulary').get();

    final now = DateTime.now();

    final words = snap.docs
        .map((d) => d.data())
        .where((w) => w['language'] == null || w['language'] == currentLang)
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

  Future<void> _disposeListeners() async {
    try {
      await _firestoreVocabSub?.cancel();
    } catch (_) {}
    _firestoreVocabSub = null;

    try {
      if (_boxListenable != null)
        _boxListenable!.removeListener(_onHiveChanged);
    } catch (_) {}
    _boxListenable = null;

    try {
      if (_box != null && _box!.isOpen) await _box!.close();
    } catch (_) {}
    _box = null;
  }

  Future<void> _initListeners() async {
    // tear down existing first
    await _disposeListeners();

    final u = auth.currentUser;
    if (u == null) return;

    final currentLang = LanguageService.instance.currentLang;

    // Firestore realtime listener
    final coll = db.collection('users').doc(u.uid).collection('vocabulary');
    _firestoreVocabSub = coll.snapshots().listen((snapshot) {
      final now = DateTime.now();
      int cnt = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lang = data['language'];
        if (lang != null && lang != currentLang) continue;

        final n = data['nextReview'];
        DateTime? t;
        if (n is Timestamp)
          t = n.toDate();
        else if (n is String) t = DateTime.tryParse(n);

        if (t == null || t.isBefore(now)) cnt++;
      }

      if (mounted)
        setState(() {
          dueCount = cnt;
          loading = false;
        });
    });

    // Hive local box listenable for immediate local updates
    final boxName = 'vocab_${u.uid}_$currentLang';
    try {
      _box = Hive.isBoxOpen(boxName)
          ? Hive.box(boxName)
          : await Hive.openBox(boxName);
      _boxListenable = _box!.listenable();
      _boxListenable!.addListener(_onHiveChanged);
      // initialize from box now
      _onHiveChanged();
    } catch (_) {
      // ignore hive errors; firestore listener will still update counts
    }
  }

  void _onHiveChanged() {
    try {
      if (_box == null) return;
      final now = DateTime.now();
      int cnt = 0;
      for (final raw in _box!.values) {
        final m =
            raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        if (m['deleted'] == true) continue;
        final n = m['nextReview'];
        DateTime? t;
        if (n is String)
          t = DateTime.tryParse(n);
        else if (n is Timestamp) t = n.toDate();
        if (t == null || t.isBefore(now)) cnt++;
      }
      if (mounted)
        setState(() {
          dueCount = cnt;
          loading = false;
        });
    } catch (_) {}
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
