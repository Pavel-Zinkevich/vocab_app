import 'package:flutter/material.dart';

class AppColors {
  static Color textForBackground(Color bg) {
    final double luminance = bg.computeLuminance();
    return luminance > 0.55 ? const Color(0xFF3A3A3A) : Colors.white;
  }

  // =========================
  // Core status colors
  // =========================

  static const Color learning = Color(0xFF9B8CFF);
  static const Color known = Color(0xFF9FC7A6);
  static const Color learned = Color(0xFFE9E4F5);

  static const Color textOnStatus = Colors.white;

  // unified background
  static const Color background = Color(0xFFF7F7FB);

  // =========================
  // Navbar / AppBar
  // =========================

  static const Color navBar = Color(0xFFEDEAFF);

  // unified primary text
  static const Color textPrimary = Color(0xFF2B2B3A);
  static const Color navBarText = textPrimary;
  static const Color navBarIcon = textPrimary;

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
  // Heatmap
  // =========================

  static const Color heatEmpty = Color(0xFFE6E6EB);
  static const Color heatLow = Color(0xFFBEE3DB);
  static const Color heatMidLow = Color(0xFF86D1C1);
  static const Color heatMid = Color(0xFF4FBFA8);
  static const Color heatHigh = Color(0xFF2AAE91);

  // =========================
  // UI / components
  // =========================

  // unified accent purple
  static const Color fab = Color(0xFF7C6CFF);
  static const Color loader = fab;

  static const Color shadow = Color(0x42000000);

  static const Color danger = Color(0xFFFF6B6B);
  static const Color dangerBg = Color(0x33FF6B6B);

  static const Color iconBg = Color(0x1F2E2323);

  // secondary text unified
  static const Color textSecondary = Color(0xFF6B6B7A);

  static const Color white = Colors.white;

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
  // Definition page specific
  // =========================

  // unified background reuse
  static const Color pageBackground = background;

  static const Color appBarTransparent = Colors.transparent;
  static const Color appBarText = Color(0xFF1F1F28);

  // unified white
  static const Color cardBackground = white;
  static const Color cardShadow = Color(0x11000000);

  // unified border
  static const Color border = Color(0x1F000000);
  static const Color controlBorder = border;

  static const Color badge = Color(0xFF5C7CF2);
  static const Color badgeBg = Color(0x295C7CF2);

  static const Color textPrimaryStrong = Color(0xFF1F1F28);

  // unified secondary text
  static const Color textMuted = textSecondary;

  // =========================
  // Links / accents
  // =========================

  static const Color infoLink = Color(0xFF4C7DFF);
}
