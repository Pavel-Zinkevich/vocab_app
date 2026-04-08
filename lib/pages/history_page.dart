import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import '../pages/definition_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  late Box _box;
  bool _hiveReady = false;
  StreamSubscription? _firestoreSub;

  @override
  void initState() {
    super.initState();
    _initHive();
  }

  Future<void> _initHive() async {
    if (Hive.isBoxOpen('history')) {
      _box = Hive.box('history');
    } else {
      _box = await Hive.openBox('history');
    }
    setState(() => _hiveReady = true);
    _startListener();
  }

  String _toIso(dynamic ts) {
    if (ts == null) return DateTime.utc(2000).toIso8601String();
    if (ts is Timestamp) return ts.toDate().toUtc().toIso8601String();
    if (ts is DateTime) return ts.toUtc().toIso8601String();
    if (ts is num)
      return DateTime.fromMillisecondsSinceEpoch(ts.toInt())
          .toUtc()
          .toIso8601String();
    if (ts is String) {
      try {
        return DateTime.parse(ts).toUtc().toIso8601String();
      } catch (_) {
        return ts;
      }
    }
    return ts.toString();
  }

  void _startListener() {
    final user = _auth.currentUser;
    if (user == null) return;

    final coll =
        _firestore.collection('users').doc(user.uid).collection('history');
    _firestoreSub?.cancel();
    _firestoreSub = coll
        .orderBy('lookedUpAt', descending: true)
        .limit(100)
        .snapshots()
        .listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        final doc = change.doc;
        if (change.type == DocumentChangeType.removed) {
          await _box.delete(doc.id);
          if (mounted) setState(() {});
          continue;
        }

        final data = doc.data();
        final map = <String, dynamic>{
          'word': data?['word'] ?? '',
          'lookedUpAt': _toIso(data?['lookedUpAt']),
          '__localKey': doc.id,
        };

        await _box.put(doc.id, map);
        if (mounted) setState(() {});
      }
    }, onError: (_) {
      // rely on cache
    });
  }

  Future<void> _clearHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Clear history?'),
        content: Text('Are you sure you want to delete all history?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete')),
        ],
      ),
    );

    if (confirm != true) return;

    // Delete remote and local
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .get();
    for (var doc in snapshot.docs) batch.delete(doc.reference);
    await batch.commit();

    await _box.clear();

    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('History cleared')));
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    if (Hive.isBoxOpen('history')) {
      _box.compact();
      _box.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null)
      return Center(child: Text('Please log in to see history.'));

    return Scaffold(
      body: _hiveReady
          ? ValueListenableBuilder(
              valueListenable: _box.listenable(),
              builder: (context, Box box, _) {
                final all = box.values
                    .map((e) => Map<String, dynamic>.from(
                        (e as Map).cast<String, dynamic>()))
                    .toList();

                // sort newest-first by lookedUpAt
                all.sort((a, b) {
                  DateTime pa;
                  DateTime pb;
                  try {
                    pa = DateTime.parse(
                        a['lookedUpAt'] ?? DateTime(2000).toIso8601String());
                  } catch (_) {
                    pa = DateTime(2000);
                  }
                  try {
                    pb = DateTime.parse(
                        b['lookedUpAt'] ?? DateTime(2000).toIso8601String());
                  } catch (_) {
                    pb = DateTime(2000);
                  }
                  return pb.compareTo(pa);
                });

                if (all.isEmpty) {
                  return Center(
                      child: Text('No history yet.',
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey[700])));
                }

                return ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: all.length,
                  itemBuilder: (context, index) {
                    final item = all[index];
                    final word = item['word'] ?? '';
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => DefinitionPage(word: word))),
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        margin: EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Colors.deepPurple, Color(0xFFC940FB)]),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black26,
                                blurRadius: 4,
                                offset: Offset(0, 2))
                          ],
                        ),
                        child: Text(word,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ),
                    );
                  },
                );
              },
            )
          : Center(child: CircularProgressIndicator(color: Colors.deepPurple)),
      floatingActionButton: FloatingActionButton(
        onPressed: _clearHistory,
        backgroundColor: Colors.deepPurple,
        child: Icon(Icons.delete, color: Colors.white),
        tooltip: 'Clear history',
      ),
    );
  }
}
