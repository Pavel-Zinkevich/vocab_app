import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/vocab_item.dart';
import '../pages/definition_page.dart';
import '../theme/app_colors.dart';
import '../theme/sparkle_decorator.dart';
import '../service/vocabulary_tab_service.dart';

class VocabularyTab extends StatefulWidget {
  const VocabularyTab({Key? key}) : super(key: key);

  @override
  State<VocabularyTab> createState() => _VocabularyTabState();
}

class _VocabularyTabState extends State<VocabularyTab> {
  final VocabularyTabController _service = VocabularyTabController();

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
    await _service.initHive();

    if (!mounted) return;
    setState(() {});
  }

  Future<void> _showWordFormSheet({
    required String title,
    required String actionLabel,
    String? docId,
    VocabItem? existing,
  }) async {
    final wordController = TextEditingController(text: existing?.word ?? '');
    final translationController =
        TextEditingController(text: existing?.translation ?? '');
    final contextController =
        TextEditingController(text: existing?.context ?? '');

    final theme = Theme.of(context);
    final colors = context.colors;
    final bgColor =
        theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        Future<void> submit() async {
          final word = wordController.text.trim();
          if (word.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please enter a word')),
            );
            return;
          }

          if (existing == null) {
            await _service.addWord(
              word: word,
              translation: translationController.text.trim(),
              context: contextController.text.trim(),
            );

            if (mounted) {
              setState(() {});
              Navigator.of(sheetContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Added locally (sync pending)'),
                ),
              );
            }
          } else {
            await _service.updateWord(
              docId: docId ?? '',
              word: word,
              translation: translationController.text.trim(),
              context: contextController.text.trim(),
            );

            if (mounted) {
              setState(() {});
              Navigator.of(sheetContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Word updated (pending sync)'),
                ),
              );
            }
          }
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: colors.textMuted.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimaryStrong,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: wordController,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Word',
                      hintText: 'Enter word',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: translationController,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Translation',
                      hintText: 'Enter translation',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contextController,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'Context',
                      hintText: 'Enter example or context',
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: submit,
                      icon: Icon(existing == null ? Icons.add : Icons.save),
                      label: Text(actionLabel),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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

    wordController.dispose();
    translationController.dispose();
    contextController.dispose();
  }

  Future<void> _showAddWordDialog() async {
    await _showWordFormSheet(
      title: 'Add Word',
      actionLabel: 'Add',
    );
  }

  void _showEditWordDialog(String docId, VocabItem existing) {
    _showWordFormSheet(
      title: 'Edit Word',
      actionLabel: 'Update',
      docId: docId,
      existing: existing,
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

                await _service.recordLookupHistory(word);
              },
              child: const Text('Look Up'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteWord(String docId) async {
    final user = _service.auth.currentUser;
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
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _service.deleteWord(docId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Word deleted (pending sync)'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark word deleted: $e'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget _buildCardContent(
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
                  color: colors.iconBg,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.edit,
                    color: subTextColor,
                  ),
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
                  color: colors.dangerBg,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: colors.danger,
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

    final Color appBarColor = Theme.of(context).appBarTheme.backgroundColor ??
        Theme.of(context).colorScheme.surface;
    final Color textColor =
        Theme.of(context).appBarTheme.titleTextStyle?.color ??
            Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: appBarColor,
        iconTheme: IconThemeData(
          color: textColor,
        ),
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search your words...',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: textColor.withOpacity(0.6),
            ),
            prefixIcon: Icon(
              Icons.search,
              color: textColor,
            ),
          ),
          style: TextStyle(
            color: textColor,
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim().toLowerCase();
            });
          },
        ),
      ),
      body: Stack(
        children: [
          if (!_service.hiveReady)
            Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            )
          else
            ValueListenableBuilder(
              valueListenable: _service.box.listenable(),
              builder: (context, Box box, _) {
                final all = box.values
                    .map((e) => VocabItem.fromMap(_service.toStringKeyedMap(e)))
                    .where((item) => item.deleted != true)
                    .toList();

                all.sort((a, b) {
                  final pa = _service.parseCreatedAt(a.createdAt);
                  final pb = _service.parseCreatedAt(b.createdAt);
                  return pb.compareTo(pa);
                });

                final filtered = all.where((item) {
                  final word = _service.normalize(item.word);
                  final translation = _service.normalize(item.translation);
                  final query = _service.normalize(_searchQuery);

                  return word.contains(query) || translation.contains(query);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No words yet. Tap + to add one.',
                      style: TextStyle(
                        fontSize: 16,
                        color: colors.textSecondary,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 70),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final VocabItem item = filtered[index];

                    final bgColor = colors.fromStatus(item.status);
                    final textColor = colors.textForBackground(bgColor);
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
                                  child: _buildCardContent(
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
                                      color: colors.shadow,
                                      blurRadius: 6,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: _buildCardContent(
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
