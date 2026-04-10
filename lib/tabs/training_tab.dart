import 'package:flutter/material.dart';
import '../pages/flashcards_page.dart';
// migrated to Theme.of(context) colors

class TrainingTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        title: Text(
          "Training",
          style: TextStyle(
              color: Theme.of(context).appBarTheme.titleTextStyle?.color ??
                  Theme.of(context).colorScheme.onSurface),
        ),
        iconTheme: IconThemeData(
            color: Theme.of(context).appBarTheme.iconTheme?.color ??
                Theme.of(context).colorScheme.onSurface),
      ),
      body: Center(
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FlashcardsPage()),
            );
          },
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).floatingActionButtonTheme.backgroundColor ??
                      Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.style,
                  color: Theme.of(context)
                          .floatingActionButtonTheme
                          .foregroundColor ??
                      Theme.of(context).colorScheme.onPrimary,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Text(
                  "Flashcards",
                  style: TextStyle(
                    fontSize: 20,
                    color: Theme.of(context)
                            .floatingActionButtonTheme
                            .foregroundColor ??
                        Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
