import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    Duration(days: 4),
    Duration(days: 8),
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

      if (step >= _intervals.length) {
        await docRef.update({
          'step': step,
          'status': 'learned',
          'nextReview': Timestamp.fromDate(
            DateTime.now().add(Duration(days: 30)),
          ),
          'updatedAt': Timestamp.now(),
        });
      } else {
        await docRef.update({
          'step': step,
          'status': 'learning',
          'nextReview': Timestamp.fromDate(
            DateTime.now().add(_intervals[step]),
          ),
          'updatedAt': Timestamp.now(),
        });
      }
    } else {
      step = max(0, step - 1);

      await docRef.update({
        'step': step,
        'status': 'learning',
        'nextReview': Timestamp.fromDate(
          DateTime.now().add(_intervals[step]),
        ),
        'updatedAt': Timestamp.now(),
      });
    }

    setState(() {
      _words.remove(_currentWord);
      _pickRandomWord();
    });
  }

  Widget _buildCard(String text) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24),
      height: 250,
      decoration: BoxDecoration(
        color: Colors.deepPurple,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text("Flashcards")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_initialWordCount == 0) {
      return Scaffold(
        appBar: AppBar(title: Text("Flashcards")),
        body: Center(child: Text("No words yet")),
      );
    }

    if (_currentWord == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Flashcards")),
        body: Center(
          child: Text("No words to review right now 🎉"),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Flashcards")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              if (_controller.isCompleted)
                _controller.reverse();
              else
                _controller.forward();

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
                            child:
                                _buildCard(_currentWord!['translation'] ?? ''),
                          )
                        : _buildCard(_currentWord!['word'] ?? ''),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 20),
          Text("Tap to flip"),
          SizedBox(height: 10),
          Text("Swipe left = knew it | right = didn’t"),
        ],
      ),
    );
  }
}
