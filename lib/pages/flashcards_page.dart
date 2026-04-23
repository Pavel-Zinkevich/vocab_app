import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_colors.dart';
import '../service/language_service.dart';
import 'package:audioplayers/audioplayers.dart';

class FlashcardsPage extends StatefulWidget {
  const FlashcardsPage({super.key});

  @override
  State<FlashcardsPage> createState() => _FlashcardsPageState();
}

class _FlashcardsPageState extends State<FlashcardsPage>
    with SingleTickerProviderStateMixin {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  final gaps = [3, 6, 12, 24, 48, 120].map((h) => Duration(hours: h)).toList();
  final rnd = Random();

  List<Map<String, dynamic>> words = [];
  Map<String, dynamic>? current;

  bool loading = true;
  bool showBack = false;

  int initial = 0;
  double drag = 0;

  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  late final a = Tween(begin: 0.0, end: pi).animate(c);

  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _player.setSource(AssetSource('sounds/knew.wav'));
    _player.setSource(AssetSource('sounds/didnt_know.mp3'));
    load();
    // react to global language changes
    LanguageService.instance.addListener(_onLangChanged);
  }

  void _onLangChanged() {
    // reload words for the newly selected language
    load();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.dispose();
    _player.dispose();
    LanguageService.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  Future<void> playSwipeSound(bool knew) async {
    final file = knew ? 'sounds/knew.wav' : 'sounds/didnt_know.mp3';
    _player.stop(); // important to avoid queue delay
    _player.play(AssetSource(file));
  }

  Future<void> load() async {
    final u = auth.currentUser;
    if (u == null) return;

    final currentLang = LanguageService.instance.currentLang;

    final s =
        await db.collection('users').doc(u.uid).collection('vocabulary').get();

    words = s.docs
        .map((d) {
          final data = d.data();
          return {
            'id': d.id,
            ...data,
            'step': data['step'] ?? 0,
            'status': data['status'] ?? 'learning',
            'language': data['language'],
          };
        })
        // include items that either have no language (legacy) or match the current language
        .where((w) => w['language'] == null || w['language'] == currentLang)
        .toList();

    setState(() {
      initial = words.length;
      loading = false;
      pick();
    });
  }

  void pick() {
    if (words.isEmpty) {
      current = null;
      return;
    }

    final now = DateTime.now();

    final due = words.where((w) {
      final n = w['nextReview'];
      final t = n is Timestamp ? n.toDate() : DateTime.tryParse('$n');
      return t == null || t.isBefore(now);
    }).toList();

    final learned = words.where((w) => w['status'] == 'learned').toList();

    current = due.isNotEmpty
        ? due[rnd.nextInt(due.length)]
        : learned.isNotEmpty && rnd.nextDouble() < .2
            ? learned[rnd.nextInt(learned.length)]
            : null;

    showBack = false;
    c.reset();
  }

  String status(int step) => step >= gaps.length
      ? 'learned'
      : step >= 2
          ? 'known'
          : 'learning';

  String txt(v, f) => v == null || '$v'.trim().isEmpty ? f : '$v';

  Future<void> _handleSwipe(Map<String, dynamic> item, bool knew) async {
    playSwipeSound(knew);

    final u = auth.currentUser;
    if (u == null) return;

    int step = (item['step'] as int?) ?? 0;
    step = knew ? step + 1 : max<int>(0, step - 1);

    await db
        .collection('users')
        .doc(u.uid)
        .collection('vocabulary')
        .doc(item['id'])
        .update({
      'step': step,
      'status': status(step),
      'updatedAt': Timestamp.now(),
      'nextReview': Timestamp.fromDate(
        DateTime.now().add(gaps[min(step, gaps.length - 1)]),
      ),
    });
  }

  void swipe(DismissDirection direction) {
    final item = current;
    if (item == null) return;

    final knew = direction == DismissDirection.endToStart;

    // 🔥 play instantly (no await)
    playSwipeSound(knew);

    setState(() {
      words.removeWhere((w) => w['id'] == item['id']);
      drag = 0;
      pick();
    });

    _handleSwipe(item, knew);
  }

  Color cardColor() {
    final ext = Theme.of(context).extension<AppSemanticColors>() ??
        AppSemanticColors.light();

    switch (current?['status']) {
      case 'known':
        return ext.known;
      case 'learned':
        return ext.learned;
      default:
        return ext.learning;
    }
  }

  Color bg() {
    final base = Theme.of(context).scaffoldBackgroundColor;
    if (drag == 0) return base;

    final p = (drag.abs() / 180).clamp(0.0, 0.6);

    final t = drag > 0 ? context.colors.danger : context.colors.known;

    return Color.lerp(base, t, p)!;
  }

  PreferredSizeWidget bar() => AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Flashcards'),
      );

  Widget card(String t) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        height: 250,
        decoration: BoxDecoration(
          color: cardColor(),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Center(
          child: Text(
            t,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: (Theme.of(context).extension<AppSemanticColors>() ??
                      AppSemanticColors.light())
                  .textForBackground(cardColor()),
            ),
          ),
        ),
      );

  Widget centerBody(String t) => Center(child: Text(t));

  @override
  Widget build(BuildContext context) {
    final body = loading
        ? const Center(child: CircularProgressIndicator())
        : initial == 0
            ? centerBody('No words yet')
            : current == null
                ? centerBody('No words to review right now 🎉')
                : Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: GestureDetector(
                            onTap: () {
                              if (c.isCompleted) {
                                c.reverse();
                              } else {
                                c.forward();
                              }

                              Future.delayed(
                                const Duration(milliseconds: 200),
                                () {
                                  setState(() => showBack = !showBack);
                                },
                              );
                            },
                            child: Dismissible(
                              key: ValueKey(current!['id']),
                              direction: DismissDirection.horizontal,
                              onUpdate: (d) => setState(() {
                                drag = d.progress *
                                    (d.direction == DismissDirection.startToEnd
                                        ? 180
                                        : -180);
                              }),
                              onDismissed: swipe,
                              child: AnimatedBuilder(
                                animation: a,
                                builder: (_, __) {
                                  final back = a.value > pi / 2;

                                  return Transform(
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..setEntry(3, 2, .001)
                                      ..rotateY(a.value),
                                    child: back
                                        ? Transform(
                                            alignment: Alignment.center,
                                            transform: Matrix4.rotationY(pi),
                                            child: card(txt(
                                              current!['translation'],
                                              'No translation',
                                            )),
                                          )
                                        : card(txt(
                                            current!['word'],
                                            'No word',
                                          )),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 30),
                        child: Column(
                          children: [
                            Text('Tap to flip'),
                            SizedBox(height: 10),
                            Text('Swipe left = knew it | right = didn’t'),
                          ],
                        ),
                      ),
                    ],
                  );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      color: bg(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: bar(),
        body: body,
      ),
    );
  }
}
