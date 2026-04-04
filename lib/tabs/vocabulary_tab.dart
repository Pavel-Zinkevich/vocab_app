import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/definition_page.dart';

class VocabularyTab extends StatefulWidget {
  @override
  State<VocabularyTab> createState() => _VocabularyTabState();
}

class _VocabularyTabState extends State<VocabularyTab> {
  final List<Map<String, String>> _words = [];

  /// Reference to Firestore collection
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  /// Load user's words from Firestore
  Future<void> _loadWords() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('vocabulary')
        .get();

    setState(() {
      _words.clear();
      _words.addAll(snapshot.docs.map((doc) => {
            'id': doc.id,
            'word': doc['word'] ?? '',
            'translation': doc['translation'] ?? '',
            'context': doc['context'] ?? '',
          }));
    });
  }

  /// Show dialog to add a new word
  void _showAddWordDialog() {
    final wordController = TextEditingController();
    final translationController = TextEditingController();
    final contextController = TextEditingController();

    // Capture the parent context
    final parentContext = context;

    Future<void> addWord() async {
      final word = wordController.text.trim();
      final translation = translationController.text.trim();
      final contextText = contextController.text.trim();

      if (word.isEmpty) {
        ScaffoldMessenger.of(parentContext)
            .showSnackBar(SnackBar(content: Text('Please enter a word')));
        return;
      }

      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(parentContext)
            .showSnackBar(SnackBar(content: Text('User not signed in')));
        return;
      }

      try {
        final docRef = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('vocabulary')
            .add({
          'word': word,
          'translation': translation,
          'context': contextText,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        setState(() {
          _words.insert(0, {
            'id': docRef.id,
            'word': word,
            'translation': translation,
            'context': contextText,
          });
        });

        // Close dialog first
        Navigator.of(parentContext).pop();

        // Then show snack bar using the parent context
        ScaffoldMessenger.of(parentContext)
            .showSnackBar(SnackBar(content: Text('Word added')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(parentContext)
            .showSnackBar(SnackBar(content: Text('Failed to add word: $e')));
      }
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        // Use dialogContext only for building UI, not ScaffoldMessenger
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Add New Word',
                    style: Theme.of(context).textTheme.titleLarge),
                TextField(
                    controller: wordController,
                    decoration: InputDecoration(hintText: 'Word')),
                TextField(
                    controller: translationController,
                    decoration: InputDecoration(hintText: 'Translation')),
                TextField(
                    controller: contextController,
                    decoration: InputDecoration(hintText: 'Context')),
                ElevatedButton(onPressed: addWord, child: Text('Add Word')),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Vocabulary')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(_auth.currentUser?.uid)
            .collection('vocabulary')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No words yet. Tap + to add one.'));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final item = doc.data() as Map<String, dynamic>;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DefinitionPage(word: item['word'] ?? ''),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green[800],
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2))
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                  '${item['word'] ?? ''} - ${item['translation'] ?? ''}',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () async {
                                final user = _auth.currentUser;
                                if (user == null) return;

                                try {
                                  await _firestore
                                      .collection('users')
                                      .doc(user.uid)
                                      .collection('vocabulary')
                                      .doc(doc.id)
                                      .delete();

                                  if (!mounted)
                                    return; // добавлено для безопасности
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Word deleted')));
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              'Failed to delete word: $e')));
                                }
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(item['context'] ?? '',
                            style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _showAddWordDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Add New Word',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }
}
