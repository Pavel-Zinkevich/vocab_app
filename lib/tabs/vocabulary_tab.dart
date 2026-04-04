import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pages/definition_page.dart';

class VocabularyTab extends StatefulWidget {
  @override
  State<VocabularyTab> createState() => _VocabularyTabState();
}

class _VocabularyTabState extends State<VocabularyTab> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey =
      GlobalKey<ScaffoldMessengerState>();

  void _showAddWordDialog() {
    final wordController = TextEditingController();
    final translationController = TextEditingController();
    final contextController = TextEditingController();

    Future<void> addWord() async {
      final word = wordController.text.trim();
      final translation = translationController.text.trim();
      final contextText = contextController.text.trim();
      final user = _auth.currentUser;

      if (word.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Please enter a word')));
        return;
      }
      if (user == null) return;

      try {
        await _firestore
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

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Word added')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to add word: $e')));
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Add New Word',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                TextField(
                  controller: wordController,
                  decoration: InputDecoration(
                      hintText: 'Word',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: translationController,
                  decoration: InputDecoration(
                      hintText: 'Translation',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: contextController,
                  decoration: InputDecoration(
                      hintText: 'Context',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: addWord,
                  icon: Icon(Icons.add),
                  label: Text(
                    'Add Word',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.deepPurple,
                  ),
                )
              ],
            ),
          ),
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
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('vocabulary')
          .doc(docId)
          .delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Word deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to delete word: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('My Vocabulary'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: user != null
            ? _firestore
                .collection('users')
                .doc(user.uid)
                .collection('vocabulary')
                .orderBy('createdAt', descending: true)
                .snapshots()
            : null,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
                child: CircularProgressIndicator(
              color: Colors.deepPurple,
            ));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
                child: Text('No words yet. Tap + to add one.',
                    style: TextStyle(fontSize: 16, color: Colors.grey[700])));
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final item = doc.data() as Map<String, dynamic>;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) =>
                          DefinitionPage(word: item['word'] ?? ''))),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.deepPurple, Colors.purpleAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
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
                                '${item['word'] ?? ''} - ${item['translation'] ?? ''}',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                              ),
                            ),
                            // 🔥 Improved Delete Button
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.redAccent.withOpacity(0.2),
                              ),
                              child: IconButton(
                                icon:
                                    Icon(Icons.close, color: Colors.redAccent),
                                onPressed: () => _deleteWord(doc.id),
                              ),
                            ),
                          ],
                        ),
                        if ((item['context'] ?? '').isNotEmpty)
                          SizedBox(height: 6),
                        if ((item['context'] ?? '').isNotEmpty)
                          Text(
                            item['context'] ?? '',
                            style: TextStyle(color: Colors.white70),
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
