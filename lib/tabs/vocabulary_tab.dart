import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/vocab_item.dart';
import '../pages/definition_page.dart';
import '../service/vocabulary_tab_service.dart';
import '../theme/app_colors.dart';
import '../theme/sparkle_decorator.dart';

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

  void _unfocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _showWordFormSheet({
    required String title,
    required String actionLabel,
    String? docId,
    VocabItem? existing,
  }) async {
    _unfocus();

    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final bgColor =
        theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return _WordFormBottomSheet(
          title: title,
          actionLabel: actionLabel,
          existing: existing,
          onSubmit: (word, translation, contextValue) async {
            if (existing == null) {
              await _service.addWord(
                word: word,
                translation: translation,
                context: contextValue,
              );

              if (!mounted) return;

              Navigator.of(sheetContext).pop();
              await Future<void>.delayed(const Duration(milliseconds: 10));

              if (!mounted) return;
              setState(() {});

              messenger?.showSnackBar(
                const SnackBar(
                  content: Text('Added locally (sync pending)'),
                ),
              );
            } else {
              await _service.updateWord(
                docId: docId ?? '',
                word: word,
                translation: translation,
                context: contextValue,
              );

              if (!mounted) return;

              Navigator.of(sheetContext).pop();
              await Future<void>.delayed(const Duration(milliseconds: 10));

              if (!mounted) return;
              setState(() {});

              messenger?.showSnackBar(
                const SnackBar(
                  content: Text('Word updated (pending sync)'),
                ),
              );
            }
          },
        );
      },
    );
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
    _unfocus();

    final lookupController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Look up a word'),
          content: TextField(
            controller: lookupController,
            decoration: const InputDecoration(hintText: 'Enter word'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final word = lookupController.text.trim();
                if (word.isEmpty) return;

                Navigator.pop(dialogContext);
                await Future<void>.delayed(const Duration(milliseconds: 10));

                if (!mounted) return;

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

  Future<bool> _showDeleteConfirmSheet() async {
    _unfocus();

    final theme = Theme.of(context);
    final colors = context.colors;
    final bgColor =
        theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface;

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: colors.textMuted.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Delete Word?',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimaryStrong,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete this word?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _ActionSheetButton(
                        label: 'Cancel',
                        backgroundColor: colors.iconBg,
                        textColor: colors.textPrimaryStrong,
                        onTap: () => Navigator.pop(sheetContext, false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionSheetButton(
                        label: 'Delete',
                        backgroundColor: colors.danger,
                        textColor: Colors.white,
                        onTap: () => Navigator.pop(sheetContext, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<void> _deleteWord(String docId) async {
    final user = _service.auth.currentUser;
    if (user == null) return;

    final messenger = ScaffoldMessenger.maybeOf(context);

    final confirm = await _showDeleteConfirmSheet();
    if (!confirm || !mounted) return;

    try {
      _unfocus();

      // Let the bottom sheet finish closing before removing the row.
      await Future<void>.delayed(const Duration(milliseconds: 40));

      if (!mounted) return;

      await _service.deleteWord(docId);

      if (!mounted) return;
      setState(() {});

      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Word deleted (pending sync)'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      messenger?.showSnackBar(
        SnackBar(
          content: Text('Failed to mark word deleted: $e'),
          duration: const Duration(seconds: 1),
        ),
      );
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
    final theme = Theme.of(context);

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
              _CircleIconAction(
                backgroundColor: colors.iconBg,
                icon: Icons.edit,
                iconColor: subTextColor,
                onTap: () => _showEditWordDialog(
                  item.localKey ?? item.remoteId ?? '',
                  item,
                ),
              ),
              const SizedBox(width: 8),
              _CircleIconAction(
                backgroundColor: colors.dangerBg,
                icon: Icons.close,
                iconColor: colors.danger,
                onTap: () => _deleteWord(
                  item.localKey ?? item.remoteId ?? '',
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

    final Color appBarColor =
        theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface;
    final Color textColor =
        theme.appBarTheme.titleTextStyle?.color ?? theme.colorScheme.onSurface;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: appBarColor,
        iconTheme: IconThemeData(color: textColor),
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
          style: TextStyle(color: textColor),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim().toLowerCase();
            });
          },
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _unfocus,
        child: Stack(
          children: [
            if (!_service.hiveReady)
              Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              )
            else
              ValueListenableBuilder(
                valueListenable: _service.box.listenable(),
                builder: (context, Box box, _) {
                  final all = box.values
                      .map(
                        (e) => VocabItem.fromMap(_service.toStringKeyedMap(e)),
                      )
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
                      final itemTextColor = colors.textForBackground(bgColor);
                      final subTextColor = itemTextColor.withOpacity(0.7);
                      final displayWord = item.word;
                      final displayTranslation = item.translation;

                      final card = item.status == 'learned'
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
                                  itemTextColor,
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
                              child: buildCardContent(
                                item,
                                displayWord,
                                displayTranslation,
                                itemTextColor,
                                subTextColor,
                              ),
                            );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _unfocus();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    DefinitionPage(word: displayWord),
                              ),
                            );
                          },
                          child: card,
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
                    theme.floatingActionButtonTheme.backgroundColor ??
                        theme.colorScheme.primary,
                onPressed: _showLookupDialog,
                child: Icon(
                  Icons.search,
                  color: theme.floatingActionButtonTheme.foregroundColor ??
                      theme.colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_word_fab',
        onPressed: _showAddWordDialog,
        label: Text(
          'Add a New Word',
          style: TextStyle(
            color: theme.floatingActionButtonTheme.foregroundColor ??
                theme.colorScheme.onPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        icon: Icon(
          Icons.add,
          color: theme.floatingActionButtonTheme.foregroundColor ??
              theme.colorScheme.onPrimary,
        ),
        backgroundColor: theme.floatingActionButtonTheme.backgroundColor ??
            theme.colorScheme.primary,
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

class _WordFormBottomSheet extends StatefulWidget {
  final String title;
  final String actionLabel;
  final VocabItem? existing;
  final Future<void> Function(
    String word,
    String translation,
    String context,
  ) onSubmit;

  const _WordFormBottomSheet({
    required this.title,
    required this.actionLabel,
    required this.onSubmit,
    this.existing,
  });

  @override
  State<_WordFormBottomSheet> createState() => _WordFormBottomSheetState();
}

class _WordFormBottomSheetState extends State<_WordFormBottomSheet> {
  late final TextEditingController _wordController;
  late final TextEditingController _translationController;
  late final TextEditingController _contextController;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(text: widget.existing?.word ?? '');
    _translationController =
        TextEditingController(text: widget.existing?.translation ?? '');
    _contextController =
        TextEditingController(text: widget.existing?.context ?? '');
  }

  @override
  void dispose() {
    _wordController.dispose();
    _translationController.dispose();
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final word = _wordController.text.trim();
    final translation = _translationController.text.trim();
    final contextValue = _contextController.text.trim();

    if (word.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a word')),
      );
      return;
    }

    if (_submitting) return;

    setState(() {
      _submitting = true;
    });

    try {
      await widget.onSubmit(word, translation, contextValue);
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
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
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimaryStrong,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _wordController,
                autofocus: widget.existing == null,
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
                controller: _translationController,
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
                controller: _contextController,
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
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(widget.existing == null ? Icons.add : Icons.save),
                  label: Text(_submitting ? 'Saving...' : widget.actionLabel),
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
  }
}

class _CircleIconAction extends StatelessWidget {
  final Color backgroundColor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _CircleIconAction({
    required this.backgroundColor,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        onTap();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: iconColor,
          size: 20,
        ),
      ),
    );
  }
}

class _ActionSheetButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionSheetButton({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
