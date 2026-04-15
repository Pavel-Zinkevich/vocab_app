import 'package:flutter/material.dart';

class SparkleDecorator extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final Color glowColor;

  const SparkleDecorator({
    super.key,
    required this.child,
    this.enabled = true,
    this.glowColor = const Color(0xFFFFD54F),
  });

  @override
  State<SparkleDecorator> createState() => _SparkleDecoratorState();
}

class _SparkleDecoratorState extends State<SparkleDecorator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Stack(
          children: [
            // glowing layer
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: widget.glowColor.withOpacity(0.45),
                    blurRadius: 18 * _pulse.value,
                    spreadRadius: 1.5,
                  ),
                ],
              ),
              child: widget.child,
            ),

            // sparkles
            Positioned(
              top: 6,
              right: 10,
              child: Opacity(
                opacity: 0.9,
                child: Icon(
                  Icons.auto_awesome,
                  size: 16 * _pulse.value,
                  color: widget.glowColor.withOpacity(0.9),
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 10,
              child: Icon(
                Icons.star,
                size: 12,
                color: widget.glowColor.withOpacity(0.7),
              ),
            ),
          ],
        );
      },
    );
  }
}
