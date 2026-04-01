import 'package:flutter/material.dart';
import '../pages/definition_page.dart';

class VocabularyTab extends StatefulWidget {
  @override
  State<VocabularyTab> createState() => _VocabularyTabState();
}

class _VocabularyTabState extends State<VocabularyTab> {
  final List<Map<String, String>> _words = [
    {'word': 'Apple', 'context': 'A fruit'},
    {'word': 'Run', 'context': 'To move fast on feet'},
    {'word': 'Hello', 'context': 'A greeting'},
  ];

  void _showAddWordDialog() {
    final wordController = TextEditingController();
    final contextController = TextEditingController();

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final mq = MediaQuery.of(context);
        final isWide = mq.size.width >= 600;

        // Use a Dialog with adaptive inset padding so on phones it can be nearly full-width
        return Dialog(
          insetPadding: EdgeInsets.symmetric(horizontal: isWide ? 40.0 : 8.0, vertical: 24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Add new word', style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 12),

                  // White rounded input for Word
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: wordController,
                      decoration: InputDecoration(
                        hintText: 'Word',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  SizedBox(height: 12),

                  // White rounded input for Context
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: contextController,
                      decoration: InputDecoration(
                        hintText: 'Context',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Action row: responsive button
                  if (isWide)
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final word = wordController.text.trim();
                          final ctx = contextController.text.trim();
                          if (word.isNotEmpty) {
                            setState(() {
                              _words.insert(0, {'word': word, 'context': ctx});
                            });
                            Navigator.of(context).pop();
                          } else {
                            // show a simple feedback
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a word')));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: Icon(Icons.add),
                        label: Text('+ Add New Word'),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final word = wordController.text.trim();
                          final ctx = contextController.text.trim();
                          if (word.isNotEmpty) {
                            setState(() {
                              _words.insert(0, {'word': word, 'context': ctx});
                            });
                            Navigator.of(context).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a word')));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Add New Word', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                ],
              ),
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
      body: _words.isEmpty
          ? Center(child: Text('No words yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              itemCount: _words.length,
              itemBuilder: (context, index) {
                final item = _words[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      // Open definition page
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => DefinitionPage(word: item['word'] ?? '')));
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['word'] ?? '',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 6),
                          Text(
                            item['context'] ?? '',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Add New Word', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }
}
