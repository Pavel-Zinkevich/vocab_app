import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class WordsCategoryPage extends StatefulWidget {
  final Box? box;
  final List<Map<String, dynamic>>? words;
  final List<Map<String, dynamic>>? allWords;
  final String? initialCategory;

  /// Provide either a Hive [box] or a preloaded [words] list. If [words]
  /// is provided it takes precedence and the widget will not read from Hive.
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

  // ---------------- SAFE CONVERTER ----------------
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

  // ---------------- GET ITEMS ----------------
  List<Map<String, dynamic>> _getAllItems() {
    // This returns the source set used for DISPLAY/Filtering. Prefer
    // `allWords` (global set) if provided, then `box` values, then the
    // local `words` list.
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

  // ---------------- CATEGORIES ----------------
  List<String> _getCategories(List<Map<String, dynamic>> items) {
    final explicit = <String>{};
    final statusFallback = <String>{};

    int _safeStep(dynamic step) {
      if (step is int) return step;
      if (step is String) return int.tryParse(step) ?? 0;
      if (step is double) return step.toInt();
      return 0;
    }

    for (final item in items) {
      // Prefer explicit 'category' field, otherwise consider 'status' as an
      // explicit bucket too (users store status in Firestore/Hive).
      final rawCat = item['category'] ?? item['status'];
      if (rawCat != null && rawCat.toString().trim().isNotEmpty) {
        explicit.add(rawCat.toString().trim().toLowerCase());
        continue;
      }

      // collect status-derived buckets if no explicit category/status
      final step = _safeStep(item['step']);
      if (step >= 6) {
        statusFallback.add('learned');
      } else if (step >= 2) {
        statusFallback.add('known');
      } else {
        statusFallback.add('learning');
      }
    }

    // If we have explicit categories, prefer them. Otherwise, show status buckets.
    if (explicit.isNotEmpty) {
      final list = explicit.toList()..sort();
      return ['all', ...list];
    }

    final list = statusFallback.toList()..sort();
    return ['all', ...list];
  }

  // ---------------- FILTER CATEGORY ----------------
  List<Map<String, dynamic>> _filterByCategory(
      List<Map<String, dynamic>> items) {
    if (_selectedCategory == 'all') return items;

    final sel = _selectedCategory.toLowerCase();

    // First try to match explicit category or status fields
    final explicitMatches = items.where((item) {
      final rawCat = item['category'] ?? item['status'];
      if (rawCat == null) return false;
      return rawCat.toString().trim().toLowerCase() == sel;
    }).toList();

    if (explicitMatches.isNotEmpty) return explicitMatches;

    // Otherwise, treat selection as a status bucket (learning/known/learned)
    int _safeStep(dynamic step) {
      if (step is int) return step;
      if (step is String) return int.tryParse(step) ?? 0;
      if (step is double) return step.toInt();
      return 0;
    }

    if (sel == 'learning' || sel == 'known' || sel == 'learned') {
      return items.where((item) {
        final step = _safeStep(item['step']);
        if (sel == 'learned') return step >= 6;
        if (sel == 'known') return step >= 2 && step < 6;
        return step < 2;
      }).toList();
    }

    // Fallback: match status field if present
    return items.where((item) {
      final cat = (item['status'] ?? '').toString().trim().toLowerCase();
      return cat == sel;
    }).toList();
  }

  // ---------------- SEARCH ----------------
  List<Map<String, dynamic>> _applySearch(List<Map<String, dynamic>> items) {
    if (_searchQuery.isEmpty) return items;

    final q = _searchQuery.toLowerCase();

    return items.where((item) {
      final word = (item['word'] ?? '').toString().toLowerCase();
      final translation = (item['translation'] ?? '').toString().toLowerCase();

      return word.contains(q) || translation.contains(q);
    }).toList();
  }

  // ---------------- EMPTY STATE ----------------
  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, size: 60, color: Colors.grey),
          SizedBox(height: 10),
          Text(
            "No words found",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Words by Category'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Builder(builder: (context) {
        // If a preloaded words list is provided, build synchronously from it.
        if (widget.words != null) {
          final allItems = _getAllItems();
          final categories = _getCategories(allItems);

          final filtered = _applySearch(
            _filterByCategory(allItems),
          );

          return Column(
            children: [
              const SizedBox(height: 10),

              // ---------------- HEADER CARD ----------------
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 10,
                        color: Colors.black.withOpacity(0.05),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      // CATEGORY
                      DropdownButtonFormField<String>(
                        value: categories.contains(_selectedCategory)
                            ? _selectedCategory
                            : 'all',
                        items: categories
                            .map((cat) => DropdownMenuItem(
                                  value: cat,
                                  child: Text(
                                    cat.toUpperCase(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value ?? 'all';
                          });
                        },
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // SEARCH
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Search words...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.grey.withOpacity(0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.trim();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ---------------- LIST ----------------
              Expanded(
                child: filtered.isEmpty
                    ? _emptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = filtered[index];

                          final word = item['word'] ?? '';
                          final translation = item['translation'] ?? '';
                          // category value removed from display (badge removed)

                          return Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 8,
                                  color: Colors.black.withOpacity(0.04),
                                )
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              title: Text(
                                word,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                translation,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              // trailing removed per user request
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        }

        // Otherwise build from the Hive box listenable
        if (widget.box == null) return _emptyState();

        return ValueListenableBuilder(
          valueListenable: widget.box!.listenable(),
          builder: (context, Box box, _) {
            final allItems = _getAllItems();
            final categories = _getCategories(allItems);

            final filtered = _applySearch(
              _filterByCategory(allItems),
            );

            return Column(
              children: [
                const SizedBox(height: 10),

                // ---------------- HEADER CARD ----------------
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 10,
                          color: Colors.black.withOpacity(0.05),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        // CATEGORY
                        DropdownButtonFormField<String>(
                          value: categories.contains(_selectedCategory)
                              ? _selectedCategory
                              : 'all',
                          items: categories
                              .map((cat) => DropdownMenuItem(
                                    value: cat,
                                    child: Text(
                                      cat.toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategory = value ?? 'all';
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // SEARCH
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search words...',
                            prefixIcon: const Icon(Icons.search),
                            filled: true,
                            fillColor: Colors.grey.withOpacity(0.08),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value.trim();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ---------------- LIST ----------------
                Expanded(
                  child: filtered.isEmpty
                      ? _emptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = filtered[index];

                            final word = item['word'] ?? '';
                            final translation = item['translation'] ?? '';
                            // category value removed from display (badge removed)

                            return Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 8,
                                    color: Colors.black.withOpacity(0.04),
                                  )
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                title: Text(
                                  word,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  translation,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                // trailing removed per user request
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      }),
    );
  }
}
