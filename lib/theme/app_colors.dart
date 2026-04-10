import 'package:flutter/material.dart';

class AppColors {
  static Color textForBackground(Color bg) {
    final double luminance = bg.computeLuminance();
    return luminance > 0.55 ? const Color(0xFF3A3A3A) : Colors.white;
  }

  // =========================
  // Core status colors (refreshed palette)
  // =========================

  // learning → soft periwinkle (calmer than strong purple)
  static const Color learning = Color(0xFF9B8CFF);

  // known → muted sage green (more natural, less saturated)
  static const Color known = Color(0xFF9FC7A6);

  // learned → soft lavender-gray (cleaner background feel)
  static const Color learned = Color(0xFFE9E4F5);

  static const Color textOnStatus = Colors.white;

  // app background → warm off-white (less yellow, more modern)
  static const Color background = Color(0xFFF7F7FB);

  // =========================
  // Navbar / AppBar
  // =========================

  static const Color navBar = Color(0xFFEDEAFF);

  static const Color navBarText = Color(0xFF2B2B3A);
  static const Color navBarIcon = Color(0xFF2B2B3A);

  // =========================
  // Status mapping
  // =========================

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

  // =========================
  // Heatmap (more modern teal → blue gradient)
  // =========================

  static const Color heatEmpty = Color(0xFFE6E6EB);

  static const Color heatLow = Color(0xFFBEE3DB);
  static const Color heatMidLow = Color(0xFF86D1C1);
  static const Color heatMid = Color(0xFF4FBFA8);
  static const Color heatHigh = Color(0xFF2AAE91);

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

  // =========================
  // Links / accents
  // =========================

  static const Color infoLink = Color(0xFF4C7DFF);
}
