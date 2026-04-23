import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../service/language_service.dart';
import '../theme/app_colors.dart';

class FlashcardsPage extends StatefulWidget {
  const FlashcardsPage({super.key});

  @override
  State<FlashcardsPage> createState() => _FlashcardsPageState();
}

class _FlashcardsPageState extends State<FlashcardsPage>
    with TickerProviderStateMixin {
  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;
  final rnd = Random();

  final gaps = [3, 6, 12, 24, 48, 120].map((h) => Duration(hours: h)).toList();

  late final ConfettiController _confettiController;
  late final AudioPlayer _player;

  List<Map<String, dynamic>> words = [];
  Map<String, dynamic>? current;

  bool loading = true;
  int initial = 0;
  double drag = 0;
  int streak = 0;

  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  late final AnimationController _cardFloatController;
  late final Animation<double> _cardFloat;

  late final AnimationController _streakFloatController;
  late final Animation<double> _streakFloat;

  late final AnimationController _streakScaleController;
  late final Animation<double> _streakScale;

  late final AnimationController _milestoneController;
  late final Animation<double> _milestoneScale;
  late final Animation<double> _milestoneShake;
  late final Animation<double> _milestoneGlow;

  late final AnimationController _bgController;

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    _player = AudioPlayer();

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _flipAnimation = Tween<double>(
      begin: 0.0,
      end: pi,
    ).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _cardFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat(reverse: true);

    _cardFloat = Tween<double>(
      begin: -6,
      end: 6,
    ).animate(
      CurvedAnimation(parent: _cardFloatController, curve: Curves.easeInOut),
    );

    _streakFloatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _streakFloat = Tween<double>(
      begin: -2,
      end: 4,
    ).animate(
      CurvedAnimation(parent: _streakFloatController, curve: Curves.easeInOut),
    );

    _streakScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );

    _streakScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.10,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.10,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 55,
      ),
    ]).animate(_streakScaleController);

    _milestoneController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _milestoneScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.18,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.18,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 60,
      ),
    ]).animate(_milestoneController);

    _milestoneShake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 12),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 18),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -3.0), weight: 14),
      TweenSequenceItem(tween: Tween(begin: -3.0, end: 0.0), weight: 20),
    ]).animate(
      CurvedAnimation(parent: _milestoneController, curve: Curves.easeOut),
    );

    _milestoneGlow = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(parent: _milestoneController, curve: Curves.easeOut),
    );

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    load();
    LanguageService.instance.addListener(_onLangChanged);
  }

  void _onLangChanged() {
    load();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _flipController.dispose();
    _cardFloatController.dispose();
    _streakFloatController.dispose();
    _streakScaleController.dispose();
    _milestoneController.dispose();
    _bgController.dispose();
    _player.dispose();
    _confettiController.dispose();
    LanguageService.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  Future<void> playSwipeSound(bool knew) async {
    final file = knew ? 'sounds/knew.wav' : 'sounds/didnt_know.mp3';
    await _player.stop();
    await _player.play(AssetSource(file));
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

    _flipController.reset();
  }

  String status(int step) => step >= gaps.length
      ? 'learned'
      : step >= 2
          ? 'known'
          : 'learning';

  String txt(dynamic v, String f) =>
      v == null || '$v'.trim().isEmpty ? f : '$v';

  int get _streakLevel {
    if (streak >= 20) return 4;
    if (streak >= 12) return 3;
    if (streak >= 6) return 2;
    if (streak >= 1) return 1;
    return 0;
  }

  bool get _isMilestone => streak > 0 && streak % 5 == 0;

  int get _backgroundTier {
    if (streak >= 25) return 5;
    if (streak >= 20) return 4;
    if (streak >= 15) return 3;
    if (streak >= 10) return 2;
    if (streak >= 5) return 1;
    return 0;
  }

  Future<void> _handleSwipe(Map<String, dynamic> item, bool knew) async {
    await playSwipeSound(knew);

    final u = auth.currentUser;
    if (u == null) return;

    int step = (item['step'] as int?) ?? 0;
    step = knew ? step + 1 : max<int>(0, step - 1);

    final newStatus = status(step);

    if (knew) {
      streak++;
      _streakScaleController.forward(from: 0);

      if (_isMilestone) {
        _milestoneController.forward(from: 0);
      }
    } else {
      streak = 0;
    }

    if (newStatus == 'learned') {
      _confettiController.play();
    }

    if (mounted) {
      setState(() {});
    }

    await db
        .collection('users')
        .doc(u.uid)
        .collection('vocabulary')
        .doc(item['id'])
        .update({
      'step': step,
      'status': newStatus,
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

    setState(() {
      words.removeWhere((w) => w['id'] == item['id']);
      drag = 0;
      pick();
    });

    _handleSwipe(item, knew);
  }

  void _toggleFlip() {
    if (_flipController.status == AnimationStatus.completed ||
        _flipController.value > 0.5) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
  }

  Color cardColor() {
    final ext = context.colors;
    switch (current?['status']) {
      case 'known':
        return ext.known;
      case 'learned':
        return ext.learned;
      default:
        return ext.learning;
    }
  }

  Color _blend(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  List<Color> _paletteGradient(AppSemanticColors c, int tier) {
    switch (tier) {
      case 1:
        return const [
          Color(0xFF1E1B4B),
          Color(0xFF6D28D9),
          Color(0xFFDB2777),
          Color(0xFF60A5FA),
        ];
      case 2:
        return const [
          Color(0xFF022C22),
          Color(0xFF0F766E),
          Color(0xFF06B6D4),
          Color(0xFFA3E635),
        ];
      case 3:
        return const [
          Color(0xFF3B0764),
          Color(0xFF9333EA),
          Color(0xFFF43F5E),
          Color(0xFFF59E0B),
        ];
      case 4:
        return const [
          Color(0xFF0F172A),
          Color(0xFF1D4ED8),
          Color(0xFF7C3AED),
          Color(0xFFEC4899),
        ];
      case 5:
        return const [
          Color(0xFF111827),
          Color(0xFF4C1D95),
          Color(0xFFC026D3),
          Color(0xFFFBBF24),
        ];
      default:
        return [
          c.flashGradientA,
          c.flashGradientB,
          c.flashGradientC,
          c.flashGradientD,
        ];
    }
  }

  List<Color> _paletteOrbs(AppSemanticColors c, int tier) {
    switch (tier) {
      case 1:
        return const [
          Color(0xFFE879F9),
          Color(0xFF60A5FA),
          Color(0xFFF472B6),
        ];
      case 2:
        return const [
          Color(0xFF34D399),
          Color(0xFF22D3EE),
          Color(0xFFA3E635),
        ];
      case 3:
        return const [
          Color(0xFFC084FC),
          Color(0xFFFB7185),
          Color(0xFFFBBF24),
        ];
      case 4:
        return const [
          Color(0xFF38BDF8),
          Color(0xFFA78BFA),
          Color(0xFFF472B6),
        ];
      case 5:
        return const [
          Color(0xFFF59E0B),
          Color(0xFFE879F9),
          Color(0xFF818CF8),
        ];
      default:
        return [
          c.flashOrb1,
          c.flashOrb2,
          c.flashOrb3,
        ];
    }
  }

  List<Color> _backgroundColors(BuildContext context) {
    final c = context.colors;
    final swipePower = (drag.abs() / 180).clamp(0.0, 1.0);
    final swipeAccent = drag > 0 ? c.danger : c.known;
    final milestoneMix = _isMilestone ? _milestoneGlow.value * 0.18 : 0.0;

    final palette = _paletteGradient(c, _backgroundTier);

    return [
      _blend(palette[0], c.streakMilestone, milestoneMix * 0.35),
      _blend(palette[1], c.streakMilestone, milestoneMix * 0.22),
      _blend(palette[2], Colors.white, milestoneMix * 0.08),
      _blend(
        _blend(palette[3], swipeAccent, swipePower * 0.18),
        c.streakMilestone,
        milestoneMix * 0.28,
      ),
    ];
  }

  Widget _glowOrb({
    required double size,
    required Color color,
  }) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 46, sigmaY: 46),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }

  Widget _buildBackground() {
    final c = context.colors;

    return AnimatedBuilder(
      animation: Listenable.merge([_bgController, _milestoneController]),
      builder: (_, __) {
        final t = _bgController.value;
        final colors = _backgroundColors(context);
        final orbs = _paletteOrbs(c, _backgroundTier);

        final shiftX = sin(t * pi * 2) * 26;
        final shiftY = cos(t * pi * 2) * 18;
        final milestoneBoost = _isMilestone ? _milestoneGlow.value : 0.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(
                -1.0 + sin(t * pi) * 0.18,
                -1.0,
              ),
              end: Alignment(
                1.0,
                1.0 - cos(t * pi) * 0.16,
              ),
              colors: colors,
              stops: const [0.02, 0.28, 0.68, 1.0],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -90 + shiftY,
                left: -70 + shiftX,
                child: _glowOrb(
                  size: 240,
                  color: _blend(orbs[0], Colors.white, milestoneBoost * 0.18)
                      .withOpacity(0.18 + milestoneBoost * 0.06),
                ),
              ),
              Positioned(
                top: 140 - shiftY,
                right: -70 - shiftX,
                child: _glowOrb(
                  size: 220,
                  color:
                      _blend(orbs[1], c.streakMilestone, milestoneBoost * 0.22)
                          .withOpacity(0.20 + milestoneBoost * 0.05),
                ),
              ),
              Positioned(
                bottom: -90 + shiftY * 0.8,
                left: 20 - shiftX * 0.5,
                child: _glowOrb(
                  size: 280,
                  color: _blend(orbs[2], Colors.white, milestoneBoost * 0.12)
                      .withOpacity(0.18 + milestoneBoost * 0.04),
                ),
              ),
              Positioned(
                bottom: 110 - shiftY,
                right: 30 + shiftX * 0.4,
                child: _glowOrb(
                  size: 120,
                  color: Colors.white.withOpacity(0.08 + milestoneBoost * 0.06),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget bar() {
    final c = context.colors;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: c.flashcardsAppBarText,
      iconTheme: IconThemeData(color: c.flashcardsAppBarText),
      title: Text(
        'Flashcards',
        style: TextStyle(
          color: c.flashcardsAppBarText,
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(
              color: Colors.black38,
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget card(String t) {
    final c = context.colors;
    final base = cardColor();
    final width = min(MediaQuery.of(context).size.width - 40.0, 420.0);

    return Container(
      width: width,
      height: 250,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _blend(base, Colors.white, 0.10),
            _blend(base, Colors.black, 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: c.cardShadow.withOpacity(0.8),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Center(
        child: Text(
          t,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: c.textForBackground(base),
          ),
        ),
      ),
    );
  }

  List<Color> _badgeGradientColors(BuildContext context) {
    final c = context.colors;

    switch (_streakLevel) {
      case 4:
        return [
          c.streakLevel4,
          _blend(c.streakMilestone, c.streakLevel4, 0.35),
        ];
      case 3:
        return [
          c.streakLevel3,
          _blend(c.streakLevel4, c.streakLevel3, 0.45),
        ];
      case 2:
        return [
          c.streakLevel2,
          _blend(c.streakLevel3, c.streakLevel2, 0.30),
        ];
      case 1:
        return [
          c.streakLevel1,
          _blend(c.streakLevel2, c.streakLevel1, 0.18),
        ];
      default:
        return [
          Colors.white.withOpacity(0.16),
          Colors.white.withOpacity(0.10),
        ];
    }
  }

  Widget _buildStreakBadge() {
    final c = context.colors;

    return SizedBox(
      height: 64,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _streakFloatController,
          _streakScaleController,
          _milestoneController,
        ]),
        builder: (_, __) {
          final badgeColors = _badgeGradientColors(context);
          final milestoneMix =
              _milestoneGlow.value * (_isMilestone ? 1.0 : 0.0);

          final start = _blend(
            badgeColors[0],
            c.streakMilestone,
            milestoneMix * 0.55,
          );
          final end = _blend(
            badgeColors[1],
            Colors.white,
            milestoneMix * 0.14,
          );

          final baseScale = streak > 0 ? _streakScale.value : 1.0;
          final milestoneScale = _isMilestone ? _milestoneScale.value : 1.0;

          return Transform.translate(
            offset: Offset(
              _isMilestone ? _milestoneShake.value : 0,
              streak > 0 ? _streakFloat.value : 0,
            ),
            child: Transform.scale(
              scale: baseScale * milestoneScale,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: streak > 0 ? 1.0 : 0.55,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [start, end],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _blend(start, Colors.black, 0.5).withOpacity(
                          0.20 + milestoneMix * 0.18,
                        ),
                        blurRadius: 18 + milestoneMix * 8,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isMilestone && streak > 0 ? '⚡' : '🔥',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        streak > 0 ? 'Streak $streak' : 'Streak 0',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      if (_isMilestone && streak > 0) ...[
                        const SizedBox(width: 8),
                        const Text(
                          'LEVEL UP',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardWidget() {
    if (current == null) {
      return const SizedBox(
        height: 250,
        width: double.infinity,
      );
    }

    return GestureDetector(
      onTap: _toggleFlip,
      child: Dismissible(
        key: ValueKey(current!['id']),
        direction: DismissDirection.horizontal,
        onUpdate: (d) {
          setState(() {
            drag = d.progress *
                (d.direction == DismissDirection.startToEnd ? 180 : -180);
          });
        },
        onDismissed: swipe,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _flipController,
            _cardFloatController,
          ]),
          builder: (_, __) {
            final isBack = _flipAnimation.value > pi / 2;
            final dragFactor = (drag / 180).clamp(-1.0, 1.0);

            final rotationY = _flipAnimation.value + (dragFactor * 0.35);
            final rotationX = dragFactor * 0.10;
            final floating = _cardFloat.value;

            final child = isBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(pi),
                    child: card(
                      txt(current!['translation'], 'No translation'),
                    ),
                  )
                : card(
                    txt(current!['word'], 'No word'),
                  );

            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0018)
                ..translate(0.0, floating, 0.0)
                ..rotateX(rotationX)
                ..rotateY(rotationY),
              child: child,
            );
          },
        ),
      ),
    );
  }

  Widget _centerMessage(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            shadows: const [
              Shadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (loading) {
      return Center(
        child: CircularProgressIndicator(
          color: context.colors.white,
        ),
      );
    }

    if (initial == 0) {
      return _centerMessage('No words yet');
    }

    if (current == null) {
      return Column(
        children: [
          const SizedBox(height: 24),
          const SizedBox(height: 250),
          Expanded(
            child: _centerMessage('No words to review right now 🎉'),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 30),
            child: Text(
              'Come back later for more reviews',
              style: TextStyle(
                color: context.colors.white.withOpacity(0.85),
                fontSize: 14,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        const SizedBox(height: 24),
        Expanded(
          child: Center(
            child: _buildCardWidget(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 30),
          child: Column(
            children: [
              Text(
                'Tap to flip',
                style: TextStyle(
                  color: context.colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Swipe left = knew it | right = didn’t',
                style: TextStyle(
                  color: context.colors.white.withOpacity(0.82),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final topOffset = MediaQuery.of(context).padding.top + kToolbarHeight + 8;

    return Stack(
      children: [
        Positioned.fill(child: _buildBackground()),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: bar(),
          body: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 84),
                    child: _buildContent(),
                  ),
                ),
              ),
              Positioned(
                top: topOffset,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: _buildStreakBadge(),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: 25,
                gravity: 0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
