import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class WordsCategoryPage extends StatefulWidget {
  final Box box;

  const WordsCategoryPage({
    Key? key,
    required this.box,
  }) : super(key: key);

  @override
  State<WordsCategoryPage> createState() => _WordsCategoryPageState();
}

class _WordsCategoryPageState extends State<WordsCategoryPage> {
  String _selectedCategory = 'all';
  String _searchQuery = '';

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
    return widget.box.values
        .map(_normalize)
        .where((e) => e.isNotEmpty && e['deleted'] != true)
        .toList();
  }

  // ---------------- CATEGORIES ----------------
  List<String> _getCategories(List<Map<String, dynamic>> items) {
    final set = <String>{};

    for (final item in items) {
      final cat =
          (item['category'] ?? 'uncategorized').toString().trim().toLowerCase();
      set.add(cat);
    }

    final list = set.toList()..sort();
    return ['all', ...list];
  }

  // ---------------- FILTER CATEGORY ----------------
  List<Map<String, dynamic>> _filterByCategory(
      List<Map<String, dynamic>> items) {
    if (_selectedCategory == 'all') return items;

    return items.where((item) {
      final cat =
          (item['category'] ?? 'uncategorized').toString().trim().toLowerCase();
      return cat == _selectedCategory.toLowerCase();
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
      body: ValueListenableBuilder(
        valueListenable: widget.box.listenable(),
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
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = filtered[index];

                          final word = item['word'] ?? '';
                          final translation = item['translation'] ?? '';
                          final category = item['category'] ?? 'uncategorized';

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
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  category,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
