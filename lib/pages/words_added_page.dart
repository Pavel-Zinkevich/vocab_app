import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';

class WordsAddedPage extends StatefulWidget {
  final DateTime selectedDate;

  const WordsAddedPage({required this.selectedDate, Key? key})
      : super(key: key);

  @override
  _WordsAddedPageState createState() => _WordsAddedPageState();
}

final List<String> months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class _WordsAddedPageState extends State<WordsAddedPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late Future<List<Map<String, dynamic>>> _wordsFuture;

  @override
  void initState() {
    super.initState();
    //print("WordsAddedPage opened for date: ${widget.selectedDate}");
    _wordsFuture = _fetchWords();
  }

  Future<List<Map<String, dynamic>>> _fetchWords() async {
    final user = _auth.currentUser;
    if (user == null) {
      print("No user logged in.");
      return [];
    }

    // --- Use local time instead of UTC to match Firestore timestamps ---
    final start = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    final end = start.add(Duration(days: 1));

    //print("Querying words from $start to $end for user ${user.uid}");

    try {
      // Firestore query with where + orderBy
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('vocabulary')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('createdAt', isLessThan: Timestamp.fromDate(end))
          .orderBy('createdAt', descending: true)
          .get();

      //print("Documents found: ${snapshot.docs.length}");
      // for (var doc in snapshot.docs) {
      //   print("Word doc: ${doc.data()}");
      // }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'word': data['word'] ?? '',
          'translation': data['translation'] ?? '',
          'context': data['context'] ?? '',
          'status':
              data.containsKey('status') ? data['status'] : 'uncategorized',
        };
      }).toList();
    } catch (e) {
      //print("Error fetching words: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            Theme.of(context).extension<AppSemanticColors>()?.navBar,
        title: Text(
          'Words on ${widget.selectedDate.day} ${months[widget.selectedDate.month - 1]} ${widget.selectedDate.year}',
          style: TextStyle(
              color:
                  Theme.of(context).extension<AppSemanticColors>()?.appBarText),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _wordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            //print("No words returned from Firestore.");
            return const Center(
              child: Text(
                'No words added on this day.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final words = snapshot.data!;
          //print("Displaying ${words.length} words");

          return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: words.length,
              itemBuilder: (context, index) {
                final item = words[index];

                final bgColor = Theme.of(context)
                        .extension<AppSemanticColors>()
                        ?.fromStatus(item['status'] ?? 'learning') ??
                    Colors.grey;

                final textColor = Theme.of(context)
                        .extension<AppSemanticColors>()
                        ?.textForBackground(bgColor) ??
                    Colors.white;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 4),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['word']} - ${item['translation']}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        if ((item['context'] ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            item['context'],
                            style: TextStyle(
                              color: textColor.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              });
        },
      ),
    );
  }
}
