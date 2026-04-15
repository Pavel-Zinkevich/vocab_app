import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ProgressPainter extends CustomPainter {
  final int learning;
  final int known;
  final int learned;
  final int total;
  final Color learningColor;
  final Color knownColor;
  final Color learnedColor;

  ProgressPainter({
    required this.learning,
    required this.known,
    required this.learned,
    required this.total,
    required this.learningColor,
    required this.knownColor,
    required this.learnedColor,
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
      ..color = Colors.grey.shade200
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ProgressPage extends StatelessWidget {
  final List<Map<String, dynamic>> words;

  const ProgressPage({super.key, required this.words});

  // ---------------- SAFE STEP ----------------
  int _safeStep(dynamic step) {
    if (step is int) return step;
    if (step is String) return int.tryParse(step) ?? 0;
    if (step is double) return step.toInt();
    return 0;
  }

  // ---------------- STATS ----------------
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

  // ---------------- FILTER ----------------
  List<Map<String, dynamic>> _filterByStatus(String status) {
    return words.where((w) {
      final step = _safeStep(w['step']);

      if (status == 'learned') return step >= 6;
      if (status == 'known') return step >= 2 && step < 6;
      return step < 2;
    }).toList();
  }

  // ---------------- BOTTOM SHEET ----------------
  void _showWordsSheet(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> filtered,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    "$title (${filtered.length})",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text("No words found"),
                          )
                        : ListView.builder(
                            controller: controller,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final w = filtered[index];
                              return ListTile(
                                title: Text(w['word'] ?? ''),
                                subtitle: Text(w['translation'] ?? ''),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final stats = _calculateStats();
    final total = words.length == 0 ? 1 : words.length;

    final colors = Theme.of(context).extension<AppSemanticColors>()!;
    final learningColor = colors.learning;
    final knownColor = colors.known;
    final learnedColor = colors.learned;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ---------------- CHART ----------------
          Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(260, 260),
                painter: ProgressPainter(
                  learning: stats['learning']!,
                  known: stats['known']!,
                  learned: stats['learned']!,
                  total: total,
                  learningColor: learningColor,
                  knownColor: knownColor,
                  learnedColor: learnedColor,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$total",
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Total Words",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ---------------- CLICKABLE STATS ----------------
          _statRow(
            context,
            "Learning",
            stats['learning']!,
            learningColor,
            _filterByStatus('learning'),
          ),
          const SizedBox(height: 8),
          _statRow(
            context,
            "Known",
            stats['known']!,
            knownColor,
            _filterByStatus('known'),
          ),
          const SizedBox(height: 8),
          _statRow(
            context,
            "Learned",
            stats['learned']!,
            learnedColor,
            _filterByStatus('learned'),
          ),
        ],
      ),
    );
  }

  // ---------------- STAT ROW ----------------
  Widget _statRow(
    BuildContext context,
    String title,
    int value,
    Color color,
    List<Map<String, dynamic>> filteredWords,
  ) {
    return InkWell(
      onTap: () => _showWordsSheet(context, title, filteredWords),
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
            Expanded(child: Text(title)),
            Text(
              "$value",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
