import 'package:flutter/material.dart';
import '../pages/definition_page.dart';

/// A StatefulWidget representing the Vocabulary tab
class VocabularyTab extends StatefulWidget {
  @override
  State<VocabularyTab> createState() => _VocabularyTabState();
}

class _VocabularyTabState extends State<VocabularyTab> {
  /// List of words, each word is represented as a map with keys: 'word', 'translation', 'context'
  final List<Map<String, String>> _words = [
    {'word': 'Apple', 'context': 'A fruit', 'translation': 'Manzana'},
    {'word': 'Run', 'context': 'To move fast on feet', 'translation': 'Correr'},
    {'word': 'Hello', 'context': 'A greeting', 'translation': 'Hola'},
  ];

  /// Shows a dialog to add a new word
  void _showAddWordDialog() {
    // Controllers for text fields
    final wordController = TextEditingController();
    final translationController = TextEditingController();
    final contextController = TextEditingController();

    /// Handles adding the new word to the list
    void addWord() {
      final word = wordController.text.trim();
      final translation = translationController.text.trim();
      final contextText = contextController.text.trim();

      if (word.isEmpty) {
        // Show a snackbar if word is empty
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Please enter a word')));
        return;
      }

      // Add the new word at the beginning of the list
      setState(() {
        _words.insert(0, {
          'word': word,
          'translation': translation,
          'context': contextText,
        });
      });

      // Close the dialog
      Navigator.of(context).pop();
    }

    showDialog<void>(
      context: context,
      barrierDismissible: true, // Allow closing by tapping outside
      builder: (context) {
        final isWide = MediaQuery.of(context).size.width >= 600;

        /// Helper function to create a styled input field
        InputDecoration inputDecoration(String hint) => InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            );

        /// Builds a container with a TextField and consistent styling
        Widget buildInput(
            TextEditingController controller, String hint, Color color) {
          return Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
                controller: controller, decoration: inputDecoration(hint)),
          );
        }

        // The actual dialog widget
        return Dialog(
          insetPadding:
              EdgeInsets.symmetric(horizontal: isWide ? 40 : 8, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Wrap content vertically
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Add New Word',
                      style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 12),
                  // Word input
                  buildInput(wordController, 'Word', Colors.white),
                  SizedBox(height: 12),
                  // Translation input
                  buildInput(
                      translationController, 'Translation', Colors.white),
                  SizedBox(height: 12),
                  // Context input
                  buildInput(contextController, 'Context', Colors.white),
                  SizedBox(height: 16),
                  // Add Word button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: addWord,
                      icon: Icon(Icons.add),
                      label: Text('Add Word'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding:
                            EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
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
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            DefinitionPage(word: item['word'] ?? ''),
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
                          // Word and translation row
                          Row(
                            children: [
                              Text(item['word'] ?? '',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                              Text(' - ',
                                  style: TextStyle(color: Colors.white)),
                              Text(item['translation'] ?? '',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            ],
                          ),
                          SizedBox(height: 6),
                          // Context description
                          Text(item['context'] ?? '',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
      // Bottom button to add a new word
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
