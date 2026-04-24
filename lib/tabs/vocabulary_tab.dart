import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/vocab_item.dart';
import '../pages/definition_page.dart';
import '../service/language_service.dart';
import '../theme/app_colors.dart';
import '../theme/sparkle_decorator.dart';

const String kDefaultLanguage = 'fr';

// 23 April 2026 14:28:33 UTC+3 = 23 April 2026 11:28:33 UTC
final DateTime kLegacyFrenchCutoff = DateTime.utc(2026, 4, 23, 11, 28, 33);

class VocabularyTab extends StatefulWidget {
  const VocabularyTab({Key? key}) : super(key: key);

  @override
  State<VocabularyTab> createState() => _VocabularyTabState();
}

class _VocabularyTabState extends State<VocabularyTab> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  final TextEditingController _searchController = TextEditingController();

  Box? _box;
  bool _hiveReady = false;
  bool _syncing = false;
  String _searchQuery = '';
  String _currentBoxName = '';
  int _reloadGeneration = 0;

  StreamSubscription? _firestoreSub;
  Timer? _pendingSyncTimer;

  DateTime parseCreatedAt(dynamic value) {
    if (value == null) return DateTime.utc(2000);

    if (value is Timestamp) {
      return value.toDate().toUtc();
    }

    if (value is num) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt()).toUtc();
      } catch (_) {
        return DateTime.utc(2000);
      }
    }

    if (value is String) {
      try {
        return DateTime.parse(value).toUtc();
      } catch (_) {
        return DateTime.utc(2000);
      }
    }

    return DateTime.utc(2000);
  }

  String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâäãå]'), 'a')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[òóôöõ]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ýÿ]'), 'y');
  }

  bool _hasExplicitLanguage(dynamic value) {
    return value is String && value.trim().isNotEmpty;
  }

  String _effectiveLanguage(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim().toLowerCase();
    }
    return kDefaultLanguage;
  }

  bool _isLegacyFrenchByCreatedAt(dynamic createdAt) {
    if (createdAt == null) return false;
    final dt = parseCreatedAt(createdAt);
    return !dt.isAfter(kLegacyFrenchCutoff); // <= cutoff => French
  }

  String _resolvedLanguage({
    required dynamic language,
    required dynamic createdAt,
  }) {
    // IMPORTANT:
    // If language is explicitly present, trust it first.
    // Only use cutoff fallback for old docs that have no language.
    if (_hasExplicitLanguage(language)) {
      return _effectiveLanguage(language);
    }

    if (_isLegacyFrenchByCreatedAt(createdAt)) {
      return 'fr';
    }

    return kDefaultLanguage;
  }

  Map<String, dynamic> _toStringKeyedMap(dynamic raw) {
    if (raw == null) return <String, dynamic>{};
    if (raw is Map<String, dynamic>) return Map<String, dynamic>.from(raw);

    if (raw is Map) {
      final out = <String, dynamic>{};
      raw.forEach((k, v) {
        out[k?.toString() ?? ''] = v;
      });
      return out;
    }

    return <String, dynamic>{};
  }

  Future<void> _backfillAndCleanLocalBox(Box box, String currentLang) async {
    final keys = List.from(box.keys);

    for (final key in keys) {
      final raw = box.get(key);
      if (raw == null) continue;

      final map = _toStringKeyedMap(raw);
      final resolvedLang = _resolvedLanguage(
        language: map['language'],
        createdAt: map['createdAt'],
      );

      final updated = Map<String, dynamic>.from(map);
      bool changed = false;

      if (updated['language'] != resolvedLang) {
        updated['language'] = resolvedLang;
        changed = true;
      }

      if (changed) {
        await box.put(key, updated);
      }

      // Each Hive box is language-specific
      if (resolvedLang != currentLang) {
        await box.delete(key);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    LanguageService.instance.addListener(_onLangChanged);
    _openCurrentLanguageBox();
  }

  void _onLangChanged() {
    _openCurrentLanguageBox();
  }

  Future<void> _openCurrentLanguageBox() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final generation = ++_reloadGeneration;
    final lang = LanguageService.instance.currentLang;
    final boxName = 'vocab_${user.uid}_$lang';

    _pendingSyncTimer?.cancel();
    _pendingSyncTimer = null;

    await _firestoreSub?.cancel();
    _firestoreSub = null;

    if (mounted) {
      setState(() {
        _hiveReady = false;
      });
    }

    final box = Hive.isBoxOpen(boxName)
        ? Hive.box(boxName)
        : await Hive.openBox(boxName);

    await _backfillAndCleanLocalBox(box, lang);

    if (!mounted || generation != _reloadGeneration) return;

    _box = box;
    _currentBoxName = boxName;

    setState(() {
      _hiveReady = true;
    });

    _startFirestoreListenerForCurrentUser(
      box: box,
      currentLang: lang,
      generation: generation,
    );

    _pendingSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (generation != _reloadGeneration) return;
      _syncPendingItems();
    });

    _syncPendingItems();
  }

  void _startFirestoreListenerForCurrentUser({
    required Box box,
    required String currentLang,
    required int generation,
  }) {
    final user = _auth.currentUser;
    if (user == null) return;

    final coll =
        _firestore.collection('users').doc(user.uid).collection('vocabulary');

    _firestoreSub = coll.snapshots().listen((snapshot) async {
      if (generation != _reloadGeneration) return;

      for (final change in snapshot.docChanges) {
        if (generation != _reloadGeneration) return;

        final doc = change.doc;
        final data = doc.data();
        final localKey = doc.id;

        if (change.type == DocumentChangeType.removed) {
          await box.delete(localKey);
          continue;
        }

        if (data == null) continue;

        final rawLanguage = data['language'];
        final docLang = _resolvedLanguage(
          language: rawLanguage,
          createdAt: data['createdAt'],
        );

        // Backfill ONLY if language is missing and cutoff says French
        if (!_hasExplicitLanguage(rawLanguage) && docLang == 'fr') {
          doc.reference.set(
              {'language': 'fr'}, SetOptions(merge: true)).catchError((_) {});
        }

        if (docLang != currentLang) {
          if (box.containsKey(localKey)) {
            await box.delete(localKey);
          }
          continue;
        }

        final remoteItem = <String, dynamic>{
          'word': data['word'] ?? '',
          'translation': data['translation'] ?? '',
          'context': data['context'] ?? '',
          'status': data['status'] ?? 'learning',
          'step': data['step'] ?? 0,
          'nextReview': data['nextReview'] != null
              ? (data['nextReview'] as Timestamp).toDate().toIso8601String()
              : null,
          'remoteId': doc.id,
          'deleted': false,
          'pending': false,
          'createdAt': data['createdAt'] != null
              ? parseCreatedAt(data['createdAt']).toIso8601String()
              : null,
          'updatedAt': data['updatedAt'] != null
              ? parseCreatedAt(data['updatedAt']).toIso8601String()
              : null,
          'language': docLang,
          '__localKey': localKey,
        };

        final localRaw = box.get(localKey);
        final local =
            localRaw is Map ? Map<String, dynamic>.from(localRaw) : null;

        if (local == null) {
          await box.put(localKey, remoteItem);
          continue;
        }

        if (local['pending'] == true || local['deleted'] == true) {
          continue;
        }

        final merged = <String, dynamic>{
          ...local,
          ...remoteItem,
          'language': docLang,
          '__localKey': localKey,
        };

        await box.put(localKey, merged);
      }
    });
  }

  Future<void> _syncPendingItems() async {
    final box = _box;
    if (box == null) return;

    try {
      if (!box.isOpen) return;
    } catch (_) {
      return;
    }

    if (_syncing) return;
    _syncing = true;

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final coll =
          _firestore.collection('users').doc(user.uid).collection('vocabulary');

      final keys = List.from(box.keys);

      for (final key in keys) {
        final raw = box.get(key);
        if (raw == null) continue;

        final v = _toStringKeyedMap(raw);

        if (v['deleted'] == true && v['pending'] == true) {
          try {
            final remoteId = v['remoteId'];
            if (remoteId != null) {
              await coll.doc(remoteId).delete();
            }
          } catch (_) {}

          await box.delete(key);
          continue;
        }

        if (v['pending'] != true) continue;

        DateTime? nextReviewDate;
        final nr = v['nextReview'];
        if (nr is String) {
          nextReviewDate = DateTime.tryParse(nr);
        }

        final resolvedLang = _resolvedLanguage(
          language: v['language'],
          createdAt: v['createdAt'],
        );

        final basePayload = <String, dynamic>{
          'word': v['word'] ?? '',
          'translation': v['translation'] ?? '',
          'context': v['context'] ?? '',
          'status': v['status'] ?? 'learning',
          'step': v['step'] ?? 0,
          'nextReview': nextReviewDate != null
              ? Timestamp.fromDate(nextReviewDate)
              : FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'language': resolvedLang,
        };

        try {
          final remoteId = v['remoteId'];

          if (remoteId == null) {
            final createPayload = <String, dynamic>{
              ...basePayload,
              'createdAt': FieldValue.serverTimestamp(),
            };

            try {
              await coll.doc(key).set(createPayload);
            } catch (_) {
              final docRef = await coll.add(createPayload);
              final updated = Map<String, dynamic>.from(v);
              updated['remoteId'] = docRef.id;
              updated['pending'] = false;
              updated['deleted'] = false;
              updated['language'] = resolvedLang;
              updated['__localKey'] = docRef.id;
              await box.put(docRef.id, updated);
              if (docRef.id != key) {
                await box.delete(key);
              }
              continue;
            }

            final updated = Map<String, dynamic>.from(v);
            updated['remoteId'] = key;
            updated['pending'] = false;
            updated['deleted'] = false;
            updated['language'] = resolvedLang;
            updated['__localKey'] = key;
            await box.put(key, updated);
          } else {
            await coll.doc(remoteId).set(basePayload, SetOptions(merge: true));

            final updated = Map<String, dynamic>.from(v);
            updated['pending'] = false;
            updated['updatedAt'] = DateTime.now().toIso8601String();
            updated['language'] = resolvedLang;
            updated['__localKey'] = remoteId;
            await box.put(key, updated);
          }
        } catch (_) {
          continue;
        }
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _showAddWordDialog() async {
    final box = _box;
    if (box == null) return;

    final wordController = TextEditingController();
    final translationController = TextEditingController();
    final contextController = TextEditingController();

    Future<void> addWord() async {
      final word = wordController.text.trim();
      if (word.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Please enter a word')));
        return;
      }

      final now = DateTime.now().toUtc();
      final localKey = const Uuid().v4();
      final currentLang = LanguageService.instance.currentLang;

      final item = {
        'word': word,
        'translation': translationController.text.trim(),
        'context': contextController.text.trim(),
        'status': 'learning',
        'step': 0,
        'nextReview': now.toIso8601String(),
        'pending': true,
        'deleted': false,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
        'language': currentLang,
        '__localKey': localKey,
      };

      await box.put(localKey, item);

      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added locally (sync pending)')),
      );

      _syncPendingItems();
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Add Word', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                TextField(
                  controller: wordController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(hintText: 'Word'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: translationController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(hintText: 'Translation'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contextController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(hintText: 'Context'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: addWord, child: const Text('Add')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditWordDialog(String docId, VocabItem existing) {
    final box = _box;
    if (box == null) return;

    final wordController = TextEditingController(text: existing.word);
    final translationController =
        TextEditingController(text: existing.translation);
    final contextController = TextEditingController(text: existing.context);

    Future<void> updateWord() async {
      final word = wordController.text.trim();
      if (word.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Please enter a word')));
        return;
      }

      final raw = box.get(docId);
      final v = raw != null ? _toStringKeyedMap(raw) : null;

      if (v == null) {
        final now = DateTime.now().toUtc();
        final currentLang = LanguageService.instance.currentLang;

        final newItem = {
          'word': word,
          'translation': translationController.text.trim(),
          'context': contextController.text.trim(),
          'status': 'learning',
          'step': 0,
          'nextReview': now.toIso8601String(),
          'pending': true,
          'deleted': false,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'language': currentLang,
          '__localKey': docId,
        };
        await box.put(docId, newItem);
      } else {
        final updated = Map<String, dynamic>.from(v);
        updated['word'] = word;
        updated['translation'] = translationController.text.trim();
        updated['context'] = contextController.text.trim();
        updated['pending'] = true;
        updated['updatedAt'] = DateTime.now().toIso8601String();
        updated['step'] = v['step'] ?? 0;
        updated['nextReview'] = v['nextReview'];
        updated['status'] = v['status'] ?? 'learning';
        updated['language'] = _resolvedLanguage(
          language: v['language'],
          createdAt: v['createdAt'],
        );
        await box.put(docId, updated);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Word updated (pending sync)')),
      );

      _syncPendingItems();
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Edit Word',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                TextField(
                  controller: wordController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(hintText: 'Word'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: translationController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(hintText: 'Translation'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: contextController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: const InputDecoration(hintText: 'Context'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: updateWord,
                  child: const Text('Update'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLookupDialog() {
    final lookupController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Look up a word'),
          content: TextField(
            controller: lookupController,
            decoration: const InputDecoration(hintText: 'Enter word'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final word = lookupController.text.trim();
                if (word.isEmpty) return;

                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DefinitionPage(word: word),
                  ),
                );

                final user = _auth.currentUser;
                if (user != null) {
                  final historyRef = _firestore
                      .collection('users')
                      .doc(user.uid)
                      .collection('history');

                  try {
                    await historyRef.add({
                      'word': word,
                      'lookedUpAt': FieldValue.serverTimestamp(),
                    });

                    final snapshot = await historyRef
                        .orderBy('lookedUpAt', descending: true)
                        .get();

                    if (snapshot.docs.length > 100) {
                      for (var doc in snapshot.docs.skip(100)) {
                        await historyRef.doc(doc.id).delete();
                      }
                    }
                  } catch (_) {}
                }
              },
              child: const Text('Look Up'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteWord(String docId) async {
    final box = _box;
    if (box == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Word?'),
        content: const Text('Are you sure you want to delete this word?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final raw = box.get(docId);
      final v = raw != null ? _toStringKeyedMap(raw) : null;
      if (v == null) return;

      if ((v['remoteId'] ?? null) == null &&
          docId.toString().startsWith('local_')) {
        await box.delete(docId);
      } else {
        final updated = Map<String, dynamic>.from(v);
        updated['deleted'] = true;
        updated['pending'] = true;
        updated['updatedAt'] = DateTime.now().toIso8601String();
        updated['language'] = _resolvedLanguage(
          language: updated['language'],
          createdAt: updated['createdAt'],
        );

        await box.put(docId, updated);
        _syncPendingItems();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Word deleted (pending sync)'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to mark word deleted: $e'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  void dispose() {
    _reloadGeneration++;
    _firestoreSub?.cancel();
    _pendingSyncTimer?.cancel();
    LanguageService.instance.removeListener(_onLangChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget buildCardContent(
      VocabItem item,
      String displayWord,
      String displayTranslation,
      Color textColor,
      Color subTextColor,
    ) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$displayWord - $displayTranslation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context)
                          .extension<AppSemanticColors>()
                          ?.iconBg ??
                      Colors.grey,
                ),
                child: IconButton(
                  icon: Icon(Icons.edit, color: subTextColor),
                  onPressed: () => _showEditWordDialog(
                    item.localKey ?? item.remoteId ?? '',
                    item,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context)
                          .extension<AppSemanticColors>()
                          ?.dangerBg ??
                      Colors.red.withOpacity(0.2),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: Theme.of(context)
                            .extension<AppSemanticColors>()
                            ?.danger ??
                        Colors.redAccent,
                  ),
                  onPressed: () => _deleteWord(
                    item.localKey ?? item.remoteId ?? '',
                  ),
                ),
              ),
            ],
          ),
          if (item.context.isNotEmpty) const SizedBox(height: 6),
          if (item.context.isNotEmpty)
            Text(
              item.context,
              style: TextStyle(color: subTextColor),
            ),
        ],
      );
    }

    final appBarColor = Theme.of(context).appBarTheme.backgroundColor ??
        Theme.of(context).colorScheme.surface;
    final appBarTextColor =
        Theme.of(context).appBarTheme.titleTextStyle?.color ??
            Theme.of(context).colorScheme.onSurface;

    final box = _box;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: appBarColor,
        iconTheme: IconThemeData(color: appBarTextColor),
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
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search your words...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: appBarTextColor.withOpacity(0.6)),
            prefixIcon: Icon(Icons.search, color: appBarTextColor),
          ),
          style: TextStyle(color: appBarTextColor),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim().toLowerCase();
            });
          },
        ),
      ),
      body: Stack(
        children: [
          if (!_hiveReady || box == null)
            Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          else
            ValueListenableBuilder(
              key: ValueKey(_currentBoxName),
              valueListenable: box.listenable(),
              builder: (context, Box activeBox, _) {
                final currentLang = LanguageService.instance.currentLang;

                final all = activeBox.values
                    .map((e) => _toStringKeyedMap(e))
                    .where((m) {
                      final resolvedLang = _resolvedLanguage(
                        language: m['language'],
                        createdAt: m['createdAt'],
                      );
                      return resolvedLang == currentLang;
                    })
                    .map((m) {
                      final fixed = Map<String, dynamic>.from(m);
                      fixed['language'] = _resolvedLanguage(
                        language: m['language'],
                        createdAt: m['createdAt'],
                      );
                      return VocabItem.fromMap(fixed);
                    })
                    .where((item) => item.deleted != true)
                    .toList();

                all.sort((a, b) {
                  final pa = parseCreatedAt(a.createdAt);
                  final pb = parseCreatedAt(b.createdAt);
                  return pb.compareTo(pa);
                });

                final filtered = all.where((item) {
                  final word = _normalize(item.word);
                  final translation = _normalize(item.translation);
                  final query = _normalize(_searchQuery);

                  return word.contains(query) || translation.contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No words yet. Tap + to add one.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context)
                            .extension<AppSemanticColors>()
                            ?.textSecondary,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 70),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];

                    final bgColor = Theme.of(context)
                            .extension<AppSemanticColors>()
                            ?.fromStatus(item.status) ??
                        Colors.grey;

                    final textColor = Theme.of(context)
                            .extension<AppSemanticColors>()
                            ?.textForBackground(bgColor) ??
                        Colors.white;
                    final subTextColor = textColor.withOpacity(0.7);

                    final displayWord = item.word;
                    final displayTranslation = item.translation;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DefinitionPage(word: displayWord),
                          ),
                        ),
                        child: item.status == 'learned'
                            ? SparkleDecorator(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.amber.withOpacity(0.55),
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: buildCardContent(
                                    item,
                                    displayWord,
                                    displayTranslation,
                                    textColor,
                                    subTextColor,
                                  ),
                                ),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context)
                                              .extension<AppSemanticColors>()
                                              ?.shadow ??
                                          Colors.black26,
                                      blurRadius: 6,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: buildCardContent(
                                  item,
                                  displayWord,
                                  displayTranslation,
                                  textColor,
                                  subTextColor,
                                ),
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'lookupWord',
              backgroundColor:
                  Theme.of(context).floatingActionButtonTheme.backgroundColor ??
                      Theme.of(context).colorScheme.primary,
              onPressed: _showLookupDialog,
              child: Icon(
                Icons.search,
                color: Theme.of(context)
                        .floatingActionButtonTheme
                        .foregroundColor ??
                    Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_word_fab',
        onPressed: _showAddWordDialog,
        label: Text(
          "Add a New Word",
          style: TextStyle(
            color:
                Theme.of(context).floatingActionButtonTheme.foregroundColor ??
                    Theme.of(context).colorScheme.onPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        icon: Icon(
          Icons.add,
          color: Theme.of(context).floatingActionButtonTheme.foregroundColor ??
              Theme.of(context).colorScheme.onPrimary,
        ),
        backgroundColor:
            Theme.of(context).floatingActionButtonTheme.backgroundColor ??
                Theme.of(context).colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        extendedPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
