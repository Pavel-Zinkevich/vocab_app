import 'package:flutter/material.dart';

class AppColors {
  static Color textForBackground(Color bg) {
    // Compute luminance (0 = dark, 1 = light)
    final double luminance = bg.computeLuminance();

    // threshold (you can tweak 0.5 → 0.6 if you want earlier switch)
    return luminance > 0.55
        ? const Color.fromARGB(255, 75, 72, 72)
        : Colors.white;
  }

  // learning → soft lavender
  static const Color learning = Color(0xFFB57EDC);

  // known → sage green
  static const Color known = Color(0xFFA8C3A0);

  // learned → slightly deeper cream/purple-tinted neutral for contrast
  static const Color learned = Color(0xFFEDE7F6);

  static const Color textOnStatus = Colors.white;

  static const Color background = Color(0xFFF6F1EB); // cream background

  static Color fromStatus(String status) {
    switch (status) {
      case 'learned':
        return learned;
      case 'known':
        return known;
      case 'learning':
      default:
        return learning;
    }
  }

  static Color textFromStatus(String status) {
    return textOnStatus;
  }
}
