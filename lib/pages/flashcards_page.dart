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

  late AnimationController _controller;
  late Animation<double> _animation;

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

    final words = snapshot.docs.map((doc) => doc.data()).toList();

    setState(() {
      _words = words;
      _isLoading = false;
      _initialWordCount = words.length;

      if (_words.isNotEmpty) {
        _pickRandomWord();
      }
    });
  }

  void _pickRandomWord() {
    if (_words.isEmpty) return;

    final random = Random();
    _currentWord = _words[random.nextInt(_words.length)];
    _showTranslation = false;
  }

  void _handleSwipe(bool knewIt) {
    if (_words.isEmpty) return;

    setState(() {
      _words.remove(_currentWord);

      if (_words.isEmpty) {
        _currentWord = null;
      } else {
        _pickRandomWord();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  bool _isLoading = true;
  int _initialWordCount = 0;
  @override
  @override
  Widget build(BuildContext context) {
    // 🟡 Loading
    if (_isLoading) {
      return Scaffold(
        floatingActionButton: null,
        appBar: AppBar(title: Text("Flashcards")),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // ❌ No words in vocabulary at all
    if (_initialWordCount == 0) {
      return Scaffold(
        appBar: AppBar(title: Text("Flashcards")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book, size: 80, color: Colors.grey),
                SizedBox(height: 20),
                Text(
                  "No words yet",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "Your vocabulary is empty.\nAdd words to start training.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 🎉 Finished training session
    if (_words.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text("Flashcards")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, size: 80, color: Colors.deepPurple),
                SizedBox(height: 20),
                Text(
                  "Congratulations 🎉",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  "You reviewed all words!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Back"),
                )
              ],
            ),
          ),
        ),
      );
    }

    // ✅ Normal training UI
    return Scaffold(
      appBar: AppBar(title: Text("Flashcards")),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
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
              key: ValueKey(_currentWord!['word']),
              direction: DismissDirection.horizontal,
              onDismissed: (direction) {
                if (direction == DismissDirection.startToEnd) {
                  _handleSwipe(false);
                } else {
                  _handleSwipe(true);
                }
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
                        : _buildCard(
                            _currentWord!['word'] ?? '',
                          ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 24),
          Text("Tap card to flip", style: TextStyle(color: Colors.grey)),
          SizedBox(height: 8),
          Text(
            "Swipe left = you know it\nSwipe right = you don’t",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}
