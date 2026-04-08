import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import '../pages/definition_page.dart';

/// VocabularyTab
///
/// Local-first vocabulary list. Uses Hive for instant UI and Firestore for
/// durable remote storage. Local edits are marked with `pending: true` and
/// synced in the background. Remote writes insert a remote-keyed entry
/// before removing local-only keys to avoid ValueListenableBuilder flicker.
class VocabularyTab extends StatefulWidget {
  const VocabularyTab({Key? key}) : super(key: key);

  @override
  State<VocabularyTab> createState() => _VocabularyTabState();
}

class _VocabularyTabState extends State<VocabularyTab> {
  // ---- ADD THIS FUNCTION HERE ----
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

  // Firebase and Hive instances
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  late Box _box;
  bool _hiveReady = false;
  StreamSubscription? _firestoreSub;
  Timer? _pendingSyncTimer;

  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    if (Hive.isBoxOpen('vocab')) {
      _box = Hive.box('vocab');
    } else {
      _box = await Hive.openBox('vocab');
    }
    setState(() => _hiveReady = true);

    // Start Firestore listener and periodic sync
    _startFirestoreListenerForCurrentUser();
    _pendingSyncTimer = Timer.periodic(Duration(seconds: 30), (_) {
      _syncPendingItems();
    });
  }

  void _startFirestoreListenerForCurrentUser() {
    final user = _auth.currentUser;
    if (user == null) return;
    final coll =
        _firestore.collection('users').doc(user.uid).collection('vocabulary');

    _firestoreSub?.cancel();
    _firestoreSub = coll.snapshots().listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        final doc = change.doc;
        if (change.type == DocumentChangeType.removed) {
          await _box.delete(doc.id);
          if (mounted) setState(() {});
          continue;
        }

        final data = doc.data();
        // Convert createdAt/updatedAt to ISO strings to keep Hive serializable
        final createdAtIso =
            parseCreatedAt(data?['createdAt']).toIso8601String();
        final updatedAtIso =
            parseCreatedAt(data?['updatedAt']).toIso8601String();

        final map = <String, dynamic>{
          'word': data?['word'] ?? '',
          'translation': data?['translation'] ?? '',
          'context': data?['context'] ?? '',
          'status': data?['status'] ?? 'uncategorized',
          'remoteId': doc.id,
          '__localKey': doc.id,
          'pending': false,
          'deleted': false,
          'createdAt': createdAtIso,
          'updatedAt': updatedAtIso,
        };

        final raw = _box.get(doc.id);
        final existing =
            raw != null ? Map<String, dynamic>.from(raw as Map) : null;
        if (existing == null || existing['pending'] != true) {
          await _box.put(doc.id, map);
          if (mounted) setState(() {});
        }
      }
    }, onError: (_) {
      // ignore — rely on cache and background sync
    });
  }

  Future<void> _syncPendingItems() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final coll =
        _firestore.collection('users').doc(user.uid).collection('vocabulary');

    for (final key in _box.keys) {
      final raw = _box.get(key);
      if (raw == null) continue;
      final v = Map<String, dynamic>.from(raw as Map);

      // Handle local deletions
      if (v['deleted'] == true) {
        final remoteId = v['remoteId'];
        if (remoteId != null) {
          try {
            await coll.doc(remoteId).delete();
            await _box.delete(key);
          } catch (_) {}
        } else {
          await _box.delete(key);
        }
        continue;
      }

      if (v['pending'] == true) {
        final remoteId = v['remoteId'];
        final payload = {
          'word': v['word'] ?? '',
          'translation': v['translation'] ?? '',
          'context': v['context'] ?? '',
          'status': v['status'] ?? 'uncategorized',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        };

        try {
          if (remoteId == null) {
            final docRef = await coll.add(payload);
            final newKey = docRef.id;
            final remoteMap = Map<String, dynamic>.from(v);
            remoteMap['remoteId'] = newKey;
            remoteMap['__localKey'] = newKey;
            remoteMap['pending'] = false;
            await _box.put(newKey, remoteMap);
            await _box.delete(key);
            if (mounted) setState(() {});
          } else {
            await coll.doc(remoteId).set(payload, SetOptions(merge: true));
            final updated = Map<String, dynamic>.from(v);
            updated['pending'] = false;
            updated['updatedAt'] = DateTime.now().toIso8601String();
            await _box.put(key, updated);
            if (mounted) setState(() {});
          }
        } catch (_) {
          // ignore and retry later
        }
      }
    }
  }

  Future<void> _showAddWordDialog() async {
    final wordController = TextEditingController();
    final translationController = TextEditingController();
    final contextController = TextEditingController();

    Future<void> addWord() async {
      final word = wordController.text.trim();
      if (word.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Please enter a word')));
        return;
      }

      final now = DateTime.now().toUtc(); // force UTC
      final localKey = 'local_${now.millisecondsSinceEpoch}';
      final item = {
        'word': word,
        'translation': translationController.text.trim(),
        'context': contextController.text.trim(),
        'status': 'uncategorized',
        'pending': true,
        'deleted': false,
        'createdAt': now.toIso8601String(),
        'updatedAt': now.toIso8601String(),
      };

      await _box.put(localKey, item);
      if (mounted) setState(() {});
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added locally (sync pending)')));
      _syncPendingItems();
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Add Word', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 8),
            TextField(
                controller: wordController,
                decoration: InputDecoration(hintText: 'Word')),
            SizedBox(height: 8),
            TextField(
                controller: translationController,
                decoration: InputDecoration(hintText: 'Translation')),
            SizedBox(height: 8),
            TextField(
                controller: contextController,
                decoration: InputDecoration(hintText: 'Context')),
            SizedBox(height: 12),
            ElevatedButton(onPressed: addWord, child: Text('Add')),
          ]),
        ),
      ),
    );
  }

  void _showEditWordDialog(String docId, Map<String, dynamic> existingData) {
    final wordController = TextEditingController(text: existingData['word']);
    final translationController =
        TextEditingController(text: existingData['translation']);
    final contextController =
        TextEditingController(text: existingData['context']);

    Future<void> updateWord() async {
      final word = wordController.text.trim();
      if (word.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Please enter a word')));
        return;
      }

      // Use docId to get Hive value
      final raw = _box.get(docId);
      final v = raw != null ? Map<String, dynamic>.from(raw as Map) : null;

      if (v == null) {
        final newItem = {
          'word': word,
          'translation': translationController.text.trim(),
          'context': contextController.text.trim(),
          'status': 'uncategorized',
          'pending': true,
          'deleted': false,
          'createdAt': DateTime.now().toIso8601String(),
          'updatedAt': DateTime.now().toIso8601String(),
        };
        await _box.put(docId, newItem);
      } else {
        final updated = Map<String, dynamic>.from(v);
        updated['word'] = word;
        updated['translation'] = translationController.text.trim();
        updated['context'] = contextController.text.trim();
        updated['pending'] = true;
        updated['updatedAt'] = DateTime.now().toIso8601String();
        await _box.put(docId, updated);
      }

      if (mounted) {
        Navigator.of(context).pop();
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Word updated (pending sync)')));
      }

      _syncPendingItems();
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Edit Word', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 8),
            TextField(
                controller: wordController,
                decoration: InputDecoration(hintText: 'Word')),
            SizedBox(height: 8),
            TextField(
                controller: translationController,
                decoration: InputDecoration(hintText: 'Translation')),
            SizedBox(height: 8),
            TextField(
                controller: contextController,
                decoration: InputDecoration(hintText: 'Context')),
            SizedBox(height: 12),
            ElevatedButton(onPressed: updateWord, child: Text('Update')),
          ]),
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
          title: Text('Look up a word'),
          content: TextField(
            controller: lookupController,
            decoration: InputDecoration(
              hintText: 'Enter word',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final word = lookupController.text.trim();
                if (word.isNotEmpty) {
                  final user = _auth.currentUser;
                  if (user != null) {
                    final historyRef = _firestore
                        .collection('users')
                        .doc(user.uid)
                        .collection('history');

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
                  }

                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DefinitionPage(word: word),
                    ),
                  );
                }
              },
              child: Text('Look Up'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteWord(String docId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Word?'),
        content: Text('Are you sure you want to delete this word?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final raw = _box.get(docId);
      final v = raw != null ? Map<String, dynamic>.from(raw as Map) : null;
      if (v == null) return;

      if ((v['remoteId'] ?? null) == null &&
          docId.toString().startsWith('local_')) {
        await _box.delete(docId);
      } else {
        final updated = Map<String, dynamic>.from(v);
        updated['deleted'] = true;
        updated['pending'] = true;
        updated['updatedAt'] = DateTime.now().toIso8601String();
        await _box.put(docId, updated);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Word deleted (pending sync)'),
            duration: Duration(seconds: 1)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to mark word deleted: $e'),
            duration: Duration(seconds: 1)));
      }
    }
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    _pendingSyncTimer?.cancel();
    if (Hive.isBoxOpen('vocab')) {
      _box.compact();
      _box.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search your words...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
            prefixIcon: Icon(Icons.search, color: Colors.white),
          ),
          style: TextStyle(color: Colors.white),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim().toLowerCase();
            });
          },
        ),
      ),
      body: Stack(
        children: [
          if (!_hiveReady)
            Center(
                child: CircularProgressIndicator(
              color: Colors.deepPurple,
            ))
          else
            ValueListenableBuilder(
              valueListenable: _box.listenable(),
              builder: (context, Box box, _) {
                // Convert to list of maps and exclude deleted flag
                final all = box.values
                    .map((e) => Map<String, dynamic>.from(
                        (e as Map).cast<String, dynamic>()))
                    .where((m) => m['deleted'] != true)
                    .toList();

                // Sort newest-first by createdAt (best-effort parse)
                all.sort((a, b) {
                  DateTime pa;
                  DateTime pb;
                  try {
                    pa = parseCreatedAt(a['createdAt']);
                  } catch (_) {
                    pa = DateTime(2000);
                  }
                  try {
                    pb = parseCreatedAt(b['createdAt']);
                  } catch (_) {
                    pb = DateTime(2000);
                  }
                  return pb.compareTo(pa);
                });

                final filtered = all.where((item) {
                  final word = (item['word'] ?? '').toString().toLowerCase();
                  final translation =
                      (item['translation'] ?? '').toString().toLowerCase();
                  return word.contains(_searchQuery) ||
                      translation.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                      child: Text('No words yet. Tap + to add one.',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey[700])));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];

                    Color bgColor;
                    switch (item['status'] ?? 'uncategorized') {
                      case 'known':
                        bgColor = Colors.green;
                        break;
                      case 'unknown':
                        bgColor = const Color.fromARGB(255, 194, 94, 87);
                        break;
                      default:
                        bgColor = Colors.white;
                    }

                    final displayWord = item['word'] ?? '';
                    final displayTranslation = item['translation'] ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    DefinitionPage(word: displayWord))),
                        child: Container(
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 4),
                              )
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Column(
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
                                        color: bgColor == Colors.white
                                            ? Colors.black
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          const Color.fromARGB(58, 46, 35, 35),
                                    ),
                                    child: IconButton(
                                      icon: Icon(Icons.edit,
                                          color: bgColor == Colors.white
                                              ? Colors.black54
                                              : Colors.white70),
                                      onPressed: () => _showEditWordDialog(
                                          item['__localKey'] ??
                                              item['remoteId'] ??
                                              '',
                                          item),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.redAccent.withOpacity(0.2),
                                    ),
                                    child: IconButton(
                                      icon: Icon(Icons.close,
                                          color: Colors.redAccent),
                                      onPressed: () => _deleteWord(
                                          item['__localKey'] ??
                                              item['remoteId'] ??
                                              ''),
                                    ),
                                  ),
                                ],
                              ),
                              if ((item['context'] ?? '').isNotEmpty)
                                SizedBox(height: 6),
                              if ((item['context'] ?? '').isNotEmpty)
                                Text(
                                  item['context'] ?? '',
                                  style: TextStyle(
                                    color: bgColor == Colors.white
                                        ? Colors.black54
                                        : Colors.white70,
                                  ),
                                ),
                            ],
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
              backgroundColor: Colors.deepPurple,
              onPressed: _showLookupDialog,
              child: Icon(Icons.search, color: Colors.white),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddWordDialog,
        label: Text(
          "Add a New Word",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        icon: Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.deepPurple,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        extendedPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
