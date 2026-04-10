import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';

class FlashcardsPage extends StatefulWidget {
  @override
  State<FlashcardsPage> createState() => _FlashcardsPageState();
}

class _FlashcardsPageState extends State<FlashcardsPage>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _words = [];
  Map<String, dynamic>? _currentWord;

  bool _showTranslation = false;
  bool _isLoading = true;
  int _initialWordCount = 0;

  late AnimationController _controller;
  late Animation<double> _animation;

  final List<Duration> _intervals = [
    Duration(hours: 3),
    Duration(hours: 6),
    Duration(hours: 12),
    Duration(days: 1),
    Duration(days: 2),
    Duration(days: 5),
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: pi).animate(_controller);

    _loadWords();
  }

  String getStatus(int step) {
    if (step >= _intervals.length) return 'learned';
    if (step >= 2) return 'known';
    return 'learning';
  }

  Future<void> _loadWords() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('vocabulary')
        .get();

    final words = snapshot.docs.map((doc) {
      final data = doc.data();

      return {
        'id': doc.id,
        ...data,
        'status': data['status'] ?? 'learning',
        'step': data['step'] ?? 0,
        'nextReview': data['nextReview'],
      };
    }).toList();

    setState(() {
      _words = words;
      _initialWordCount = words.length;
      _isLoading = false;
      _pickRandomWord();
    });
  }

  void _pickRandomWord() {
    if (_words.isEmpty) {
      _currentWord = null;
      return;
    }

    final now = DateTime.now();
    final random = Random();

    final dueWords = _words.where((w) {
      DateTime? next;
      if (w['nextReview'] is Timestamp) {
        next = (w['nextReview'] as Timestamp).toDate();
      } else if (w['nextReview'] is String) {
        next = DateTime.tryParse(w['nextReview']);
      }
      return next == null || next.isBefore(now);
    }).toList();

    final learnedWords = _words.where((w) => w['status'] == 'learned').toList();

    if (dueWords.isNotEmpty) {
      _currentWord = dueWords[random.nextInt(dueWords.length)];
    } else if (learnedWords.isNotEmpty && random.nextDouble() < 0.2) {
      _currentWord = learnedWords[random.nextInt(learnedWords.length)];
    } else {
      _currentWord = null;
    }

    _showTranslation = false;
  }

  Future<void> _handleSwipe(bool knewIt) async {
    if (_currentWord == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('vocabulary')
        .doc(_currentWord!['id']);

    int step = _currentWord!['step'] ?? 0;

    if (knewIt) {
      step++;
    } else {
      step = max(0, step - 1);
    }

    final status = getStatus(step);

    await docRef.update({
      'step': step,
      'status': status,
      'nextReview': Timestamp.fromDate(
        DateTime.now().add(
          _intervals[min(step, _intervals.length - 1)],
        ),
      ),
      'updatedAt': Timestamp.now(),
    });

    setState(() {
      _words.removeWhere((w) => w['id'] == _currentWord!['id']);
      _pickRandomWord();
    });
  }

  Color _cardColor() {
    final status = _currentWord?['status'] ?? 'learning';

    switch (status) {
      case 'known':
        return AppColors.known;
      case 'learned':
        return AppColors.learned;
      default:
        return AppColors.learning;
    }
  }

  Widget _buildCard(String text) {
    final bg = _cardColor();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24),
      height: 250,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textForBackground(bg),
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppColors.background;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: Text("Flashcards",
              style: TextStyle(color: AppColors.textForBackground(bg))),
        ),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.learning),
        ),
      );
    }

    if (_initialWordCount == 0) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: Text("Flashcards",
              style: TextStyle(color: AppColors.textForBackground(bg))),
        ),
        body: Center(
          child: Text("No words yet",
              style: TextStyle(color: AppColors.textForBackground(bg))),
        ),
      );
    }

    if (_currentWord == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: Text("Flashcards",
              style: TextStyle(color: AppColors.textForBackground(bg))),
        ),
        body: Center(
          child: Text(
            "No words to review right now 🎉",
            style: TextStyle(
              color: AppColors.textForBackground(bg),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          "Flashcards",
          style: TextStyle(
            color: AppColors.textForBackground(bg),
          ),
        ),
      ),
      body: Column(
        children: [
          /// 👇 This takes all available space and centers the card
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (_controller.isCompleted) {
                    _controller.reverse();
                  } else {
                    _controller.forward();
                  }

                  Future.delayed(Duration(milliseconds: 200), () {
                    setState(() {
                      _showTranslation = !_showTranslation;
                    });
                  });
                },
                child: Dismissible(
                  key: ValueKey(_currentWord!['id']),
                  direction: DismissDirection.horizontal,
                  onDismissed: (direction) {
                    _handleSwipe(direction == DismissDirection.endToStart);
                  },
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      final isUnder = (_animation.value > pi / 2);

                      return Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(_animation.value),
                        alignment: Alignment.center,
                        child: isUnder
                            ? Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.rotationY(pi),
                                child: _buildCard(
                                  _currentWord!['translation'] ?? '',
                                ),
                              )
                            : _buildCard(_currentWord!['word'] ?? ''),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          /// 👇 Fixed bottom section (won’t move anymore)
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Column(
              children: [
                Text(
                  "Tap to flip",
                  style: TextStyle(color: AppColors.learning),
                ),
                SizedBox(height: 10),
                Text(
                  "Swipe left = knew it | right = didn’t",
                  style: TextStyle(
                    color: AppColors.textForBackground(bg),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
