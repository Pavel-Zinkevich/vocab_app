import 'package:flutter/material.dart';
import '../pages/flashcards_page.dart';
import '../theme/app_colors.dart';

class TrainingTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: AppColors.navBar,
        title: Text(
          "Training",
          style: TextStyle(color: AppColors.navBarText),
        ),
        iconTheme: IconThemeData(color: AppColors.navBarIcon),
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
              color: AppColors.learning,
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
                  color: Colors.white,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Text(
                  "Flashcards",
                  style: const TextStyle(
                    fontSize: 20,
                    color: Colors.white,
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
