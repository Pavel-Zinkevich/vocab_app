import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/app_colors.dart';
import 'definition_page.dart';

import '../theme/sparkle_decorator.dart';

class WordsCategoryPage extends StatefulWidget {
  final Box? box;
  final List<Map<String, dynamic>>? words;
  final List<Map<String, dynamic>>? allWords;
  final String? initialCategory;

  const WordsCategoryPage({
    Key? key,
    this.box,
    this.words,
    this.allWords,
    this.initialCategory,
  }) : super(key: key);

  @override
  State<WordsCategoryPage> createState() => _WordsCategoryPageState();
}

class _WordsCategoryPageState extends State<WordsCategoryPage> {
  String _selectedCategory = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      _selectedCategory = widget.initialCategory!.toLowerCase();
    }
  }

  Map<String, dynamic> _normalize(dynamic raw) {
    if (raw == null) return {};

    if (raw is Map) {
      return Map<String, dynamic>.from(raw);
    }

    try {
      final map = raw.toMap();
      if (map is Map) return Map<String, dynamic>.from(map);
    } catch (_) {}

    return {};
  }

  List<Map<String, dynamic>> _getAllItems() {
    if (widget.allWords != null) {
      return widget.allWords!
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e.isNotEmpty && e['deleted'] != true)
          .toList();
    }

    if (widget.box != null) {
      return widget.box!.values
          .map(_normalize)
          .where((e) => e.isNotEmpty && e['deleted'] != true)
          .toList();
    }

    if (widget.words != null) {
      return widget.words!
          .map((e) => Map<String, dynamic>.from(e))
          .where((e) => e.isNotEmpty && e['deleted'] != true)
          .toList();
    }

    return [];
  }

  List<String> _getCategories(List<Map<String, dynamic>> items) {
    final explicit = <String>{};
    final statusFallback = <String>{};

    int safeStep(dynamic step) {
      if (step is int) return step;
      if (step is String) return int.tryParse(step) ?? 0;
      if (step is double) return step.toInt();
      return 0;
    }

    for (final item in items) {
      final rawCat = item['category'] ?? item['status'];

      if (rawCat != null && rawCat.toString().trim().isNotEmpty) {
        explicit.add(rawCat.toString().trim().toLowerCase());
        continue;
      }

      final step = safeStep(item['step']);

      if (step >= 6) {
        statusFallback.add('learned');
      } else if (step >= 2) {
        statusFallback.add('known');
      } else {
        statusFallback.add('learning');
      }
    }

    if (explicit.isNotEmpty) {
      final list = explicit.toList()..sort();
      return ['all', ...list];
    }

    final list = statusFallback.toList()..sort();
    return ['all', ...list];
  }

  List<Map<String, dynamic>> _filterByCategory(
      List<Map<String, dynamic>> items) {
    if (_selectedCategory == 'all') return items;

    final sel = _selectedCategory.toLowerCase();

    final explicitMatches = items.where((item) {
      final rawCat = item['category'] ?? item['status'];
      if (rawCat == null) return false;

      return rawCat.toString().trim().toLowerCase() == sel;
    }).toList();

    if (explicitMatches.isNotEmpty) return explicitMatches;

    int safeStep(dynamic step) {
      if (step is int) return step;
      if (step is String) return int.tryParse(step) ?? 0;
      if (step is double) return step.toInt();
      return 0;
    }

    if (sel == 'learning' || sel == 'known' || sel == 'learned') {
      return items.where((item) {
        final step = safeStep(item['step']);

        if (sel == 'learned') return step >= 6;
        if (sel == 'known') return step >= 2 && step < 6;
        return step < 2;
      }).toList();
    }

    return items.where((item) {
      final cat = (item['status'] ?? '').toString().trim().toLowerCase();
      return cat == sel;
    }).toList();
  }

  List<Map<String, dynamic>> _applySearch(List<Map<String, dynamic>> items) {
    if (_searchQuery.isEmpty) return items;

    final q = _searchQuery.toLowerCase();

    return items.where((item) {
      final word = (item['word'] ?? '').toString().toLowerCase();
      final translation = (item['translation'] ?? '').toString().toLowerCase();

      return word.contains(q) || translation.contains(q);
    }).toList();
  }

  String _statusFromItem(Map<String, dynamic> item) {
    final explicit = item['status'];

    if (explicit != null) {
      return explicit.toString().toLowerCase();
    }

    int step = 0;
    final raw = item['step'];

    if (raw is int) step = raw;
    if (raw is String) step = int.tryParse(raw) ?? 0;

    if (step >= 6) return 'learned';
    if (step >= 2) return 'known';
    return 'learning';
  }

  Widget _emptyStateModern() {
    final colors = context.colors;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.cardBackground,
            ),
            child: Icon(
              Icons.menu_book_rounded,
              size: 42,
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No words found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try another search or category',
            style: TextStyle(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget content(List<Map<String, dynamic>> allItems) {
      final categories = _getCategories(allItems);

      final filtered = _applySearch(
        _filterByCategory(allItems),
      );

      return Column(
        children: [
          SizedBox(
            height: 54,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final selected = cat == _selectedCategory;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? colors.fab : colors.cardBackground,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: colors.cardShadow,
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        cat.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? colors.white : colors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? _emptyStateModern()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];

                      final word = item['word']?.toString() ?? '';
                      final translation = item['translation']?.toString() ?? '';

                      final status = _statusFromItem(item);

                      final bg = colors.fromStatus(status);
                      final textColor = colors.textForBackground(bg);
                      final subColor = textColor.withOpacity(0.75);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DefinitionPage(
                                  word: word,
                                ),
                              ),
                            );
                          },
                          child: item['status'] == 'learned'
                              ? SparkleDecorator(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: bg,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.amber.withOpacity(0.55),
                                          blurRadius: 18,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 10,
                                      ),
                                      title: Text(
                                        word,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          translation,
                                          style: TextStyle(
                                            color: subColor,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: bg,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors.shadow,
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 10,
                                    ),
                                    title: Text(
                                      word,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        translation,
                                        style: TextStyle(
                                          color: subColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: colors.pageBackground,
        foregroundColor: colors.appBarText,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: colors.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim();
                });
              },
              style: TextStyle(
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Search words...',
                hintStyle: TextStyle(
                  color: colors.textMuted,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: colors.textSecondary,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
      ),
      body: widget.words != null
          ? content(_getAllItems())
          : widget.box == null
              ? _emptyStateModern()
              : ValueListenableBuilder(
                  valueListenable: widget.box!.listenable(),
                  builder: (_, __, ___) {
                    return content(
                      _getAllItems(),
                    );
                  },
                ),
    );
  }
}
