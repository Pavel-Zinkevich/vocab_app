import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../pages/words_category_page.dart';

class ProgressPainter extends CustomPainter {
  final int learning;
  final int known;
  final int learned;
  final int total;
  final Color learningColor;
  final Color knownColor;
  final Color learnedColor;
  final Color trackColor;

  ProgressPainter({
    required this.learning,
    required this.known,
    required this.learned,
    required this.total,
    required this.learningColor,
    required this.knownColor,
    required this.learnedColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 14;
    final rect = Rect.fromCircle(center: center, radius: radius);

    const strokeWidth = 18.0;
    const gap = 0.04;

    double startAngle = -pi / 2;

    final bgPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    void drawSegment(int value, Color color) {
      if (value <= 0 || total <= 0) return;

      final sweep = (value / total) * 2 * pi;
      final adjusted = max(0.0, sweep - gap);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(rect, startAngle, adjusted, false, paint);
      startAngle += sweep;
    }

    drawSegment(learning, learningColor);
    drawSegment(known, knownColor);
    drawSegment(learned, learnedColor);
  }

  @override
  bool shouldRepaint(covariant ProgressPainter oldDelegate) {
    return oldDelegate.learning != learning ||
        oldDelegate.known != known ||
        oldDelegate.learned != learned ||
        oldDelegate.total != total ||
        oldDelegate.learningColor != learningColor ||
        oldDelegate.knownColor != knownColor ||
        oldDelegate.learnedColor != learnedColor ||
        oldDelegate.trackColor != trackColor;
  }
}

class ProgressPage extends StatelessWidget {
  final List<Map<String, dynamic>> words;

  const ProgressPage({super.key, required this.words});

  AppSemanticColors? _semantic(BuildContext context) {
    return Theme.of(context).extension<AppSemanticColors>();
  }

  int _safeStep(dynamic step) {
    if (step is int) return step;
    if (step is String) return int.tryParse(step) ?? 0;
    if (step is double) return step.toInt();
    return 0;
  }

  Map<String, int> _calculateStats() {
    int learning = 0;
    int known = 0;
    int learned = 0;

    for (final w in words) {
      final step = _safeStep(w['step']);

      if (step >= 6) {
        learned++;
      } else if (step >= 2) {
        known++;
      } else {
        learning++;
      }
    }

    return {
      'learning': learning,
      'known': known,
      'learned': learned,
    };
  }

  List<Map<String, dynamic>> _filterByStatus(String status) {
    return words.where((w) {
      final step = _safeStep(w['step']);

      if (status == 'learned') return step >= 6;
      if (status == 'known') return step >= 2 && step < 6;
      return step < 2;
    }).toList();
  }

  Color _learningColor(BuildContext context) {
    final semantic = _semantic(context);
    return semantic?.learning ?? Theme.of(context).colorScheme.primary;
  }

  Color _knownColor(BuildContext context) {
    final semantic = _semantic(context);
    return semantic?.known ?? Theme.of(context).colorScheme.tertiary;
  }

  Color _learnedColor(BuildContext context) {
    final semantic = _semantic(context);
    return semantic?.learned ?? Colors.green;
  }

  Color _trackColor(BuildContext context) {
    final semantic = _semantic(context);
    if (semantic != null) {
      return semantic.background.withOpacity(0.35);
    }

    final scheme = Theme.of(context).colorScheme;
    return scheme.surfaceVariant.withOpacity(0.8);
  }

  Color _secondaryTextColor(BuildContext context) {
    final semantic = _semantic(context);
    if (semantic != null) {
      return semantic.textSecondary;
    }
    return Theme.of(context).colorScheme.onSurface.withOpacity(0.65);
  }

  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();
    final realTotal = words.length;
    final painterTotal = realTotal == 0 ? 1 : realTotal;

    final learningColor = _learningColor(context);
    final knownColor = _knownColor(context);
    final learnedColor = _learnedColor(context);
    final trackColor = _trackColor(context);

    final items = [
      ("Learning", stats['learning'] ?? 0, learningColor, 'learning'),
      ("Known", stats['known'] ?? 0, knownColor, 'known'),
      ("Learned", stats['learned'] ?? 0, learnedColor, 'learned'),
    ];

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(260, 260),
                painter: ProgressPainter(
                  learning: stats['learning'] ?? 0,
                  known: stats['known'] ?? 0,
                  learned: stats['learned'] ?? 0,
                  total: painterTotal,
                  learningColor: learningColor,
                  knownColor: knownColor,
                  learnedColor: learnedColor,
                  trackColor: trackColor,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$realTotal",
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Total Words",
                    style: TextStyle(
                      color: _secondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          ...items.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _statRow(
                context,
                e.$1,
                e.$2,
                e.$3,
                _filterByStatus(e.$4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(
    BuildContext context,
    String title,
    int value,
    Color color,
    List<Map<String, dynamic>> filteredWords,
  ) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WordsCategoryPage(
            words: filteredWords,
            allWords: words,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: textColor),
              ),
            ),
            Text(
              "$value",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
