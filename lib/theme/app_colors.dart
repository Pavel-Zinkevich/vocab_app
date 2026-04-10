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
  // =========================
  // Navbar / AppBar colors
  // =========================

  static const Color navBar = Color(0xFFEEE6FF); // soft lavender tint

  static Color navBarText = const Color(0xFF2E2A3A);

  static Color navBarIcon = const Color(0xFF2E2A3A);
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
  // =========================
  // Heatmap / activity colors
  // =========================

  static const Color heatEmpty = Color(0xFFE0E0E0);

  static const Color heatLow = Color(0xFFB2DFDB);
  static const Color heatMidLow = Color(0xFF80CBC4);
  static const Color heatMid = Color(0xFF4DB6AC);
  static const Color heatHigh = Color(0xFF26A69A);

  static Color heatColor(double ratio) {
    if (ratio <= 0) return heatEmpty;
    if (ratio < 0.25) return heatLow;
    if (ratio < 0.5) return heatMidLow;
    if (ratio < 0.75) return heatMid;
    return heatHigh;
  }

  static Color heatFromCount(int count, int maxCount) {
    if (count == 0 || maxCount == 0) return heatEmpty;
    return heatColor(count / maxCount);
  }

  // UI helper colors
  static const Color infoLink = Color(0xFF4A90E2);
  static Color textFromStatus(String status) {
    return textOnStatus;
  }
}
