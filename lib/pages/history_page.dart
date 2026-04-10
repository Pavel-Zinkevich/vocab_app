import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:async';
import '../pages/definition_page.dart';
import '../theme/app_colors.dart'; // 👈 add this

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
        };

        await _box.put(doc.id, map);
        if (mounted) setState(() {});
      }
    });
  }

  Future<void> _clearHistory() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text('Clear history',
            style: TextStyle(
                color: AppColors.textForBackground(AppColors.background))),
        content: Text('Are you sure you want to delete all history?',
            style: TextStyle(
                color: AppColors.textForBackground(AppColors.background))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  Text('Cancel', style: TextStyle(color: AppColors.learning))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );

    if (confirm != true) return;

    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .get();

    for (var doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    await _box.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.learning,
          content: Text('History cleared'),
        ),
      );
    }
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

    if (user == null) {
      return Center(
        child: Text('Please log in to see history.',
            style: TextStyle(color: AppColors.learning)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: _hiveReady
          ? ValueListenableBuilder(
              valueListenable: _box.listenable(),
              builder: (context, Box box, _) {
                final all = box.values
                    .map((e) => Map<String, dynamic>.from(
                        (e as Map).cast<String, dynamic>()))
                    .toList();

                all.sort((a, b) {
                  final pa = DateTime.tryParse(a['lookedUpAt'] ?? '') ??
                      DateTime(2000);
                  final pb = DateTime.tryParse(b['lookedUpAt'] ?? '') ??
                      DateTime(2000);
                  return pb.compareTo(pa);
                });

                if (all.isEmpty) {
                  return Center(
                    child: Text(
                      'No history yet.',
                      style: TextStyle(
                        fontSize: 16,
                        color:
                            AppColors.textForBackground(AppColors.background),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: all.length,
                  itemBuilder: (context, index) {
                    final item = all[index];
                    final word = item['word'] ?? '';

                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DefinitionPage(word: word),
                        ),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.heatHigh.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                        child: Text(
                          word,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            )
          : Center(
              child: CircularProgressIndicator(
                color: AppColors.learning,
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _clearHistory,
        backgroundColor: AppColors.known,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
    );
  }
}
