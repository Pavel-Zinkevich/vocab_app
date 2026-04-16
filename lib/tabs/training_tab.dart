import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../pages/flashcards_page.dart';

class TrainingTab extends StatelessWidget {
  TrainingTab({super.key});

  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;

    final bg = Theme.of(context).scaffoldBackgroundColor;

    final textColor =
        Theme.of(context).floatingActionButtonTheme.foregroundColor ??
            Theme.of(context).colorScheme.onPrimary;

    final cardColor =
        Theme.of(context).floatingActionButtonTheme.backgroundColor ??
            Theme.of(context).colorScheme.primary;

    if (user == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
              Theme.of(context).colorScheme.surface,
          title: Text(
            "Training",
            style: TextStyle(
              color: Theme.of(context).appBarTheme.titleTextStyle?.color ??
                  Theme.of(context).colorScheme.onSurface,
            ),
          ),
          iconTheme: IconThemeData(
            color: Theme.of(context).appBarTheme.iconTheme?.color ??
                Theme.of(context).colorScheme.onSurface,
          ),
        ),
        body: const Center(
          child: Text("No user logged in"),
        ),
      );
    }

    final vocabStream = db
        .collection('users')
        .doc(user.uid)
        .collection('vocabulary')
        .snapshots();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        title: Text(
          "Training",
          style: TextStyle(
            color: Theme.of(context).appBarTheme.titleTextStyle?.color ??
                Theme.of(context).colorScheme.onSurface,
          ),
        ),
        iconTheme: IconThemeData(
          color: Theme.of(context).appBarTheme.iconTheme?.color ??
              Theme.of(context).colorScheme.onSurface,
        ),
      ),
      body: Center(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: vocabStream,
          builder: (context, vocabSnap) {
            if (!vocabSnap.hasData) {
              return _flashcardCard(
                context: context,
                text: "Flashcards",
                textColor: textColor,
                cardColor: cardColor,
              );
            }

            final docs = vocabSnap.data!.docs;

            // This extra StreamBuilder makes the count refresh automatically
            // when time passes, even if Firestore data didn't change.
            return StreamBuilder<DateTime>(
              stream: Stream.periodic(
                const Duration(seconds: 30),
                (_) => DateTime.now(),
              ),
              initialData: DateTime.now(),
              builder: (context, timeSnap) {
                final now = timeSnap.data ?? DateTime.now();

                final dueCount = docs.where((doc) {
                  final data = doc.data();
                  final n = data['nextReview'];
                  final t =
                      n is Timestamp ? n.toDate() : DateTime.tryParse('$n');

                  return t == null || !t.isAfter(now);
                }).length;

                return _flashcardCard(
                  context: context,
                  text: "Flashcards ($dueCount)",
                  textColor: textColor,
                  cardColor: cardColor,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _flashcardCard({
    required BuildContext context,
    required String text,
    required Color textColor,
    required Color cardColor,
  }) {
    return GestureDetector(
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
          color: cardColor,
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
              color: textColor,
              size: 30,
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 20,
                color: textColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
