import 'package:flutter/material.dart';

// ThemeExtension that holds the app's semantic colors so they can be
// supplied per-theme via ThemeData.extensions. Use `context.colors` to
// read the current theme's semantic colors.

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color background;
  final Color pageBackground;
  final Color navBar;
  final Color white;
  final Color cardBackground;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textPrimaryStrong;

  final Color learning;
  final Color known;
  final Color learned;
  final Color textOnStatus;

  final Color heatEmpty;
  final Color heatLow;
  final Color heatMidLow;
  final Color heatMid;
  final Color heatHigh;

  final Color fab;
  final Color loader;
  final Color shadow;
  final Color danger;
  final Color dangerBg;
  final Color iconBg;

  final Color border;
  final Color controlBorder;
  final Color cardShadow;

  final Color badge;
  final Color badgeBg;
  final Color infoLink;

  final Color appBarText;

  // New flashcards-specific colors
  final Color flashcardsAppBarText;
  final Color flashGlass;
  final Color flashGradientA;
  final Color flashGradientB;
  final Color flashGradientC;
  final Color flashGradientD;
  final Color flashOrb1;
  final Color flashOrb2;
  final Color flashOrb3;

  final Color streakLevel1;
  final Color streakLevel2;
  final Color streakLevel3;
  final Color streakLevel4;
  final Color streakMilestone;

  const AppSemanticColors({
    required this.background,
    required this.pageBackground,
    required this.navBar,
    required this.white,
    required this.cardBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textPrimaryStrong,
    required this.learning,
    required this.known,
    required this.learned,
    required this.textOnStatus,
    required this.heatEmpty,
    required this.heatLow,
    required this.heatMidLow,
    required this.heatMid,
    required this.heatHigh,
    required this.fab,
    required this.loader,
    required this.shadow,
    required this.danger,
    required this.dangerBg,
    required this.iconBg,
    required this.border,
    required this.controlBorder,
    required this.cardShadow,
    required this.badge,
    required this.badgeBg,
    required this.infoLink,
    required this.appBarText,
    required this.flashcardsAppBarText,
    required this.flashGlass,
    required this.flashGradientA,
    required this.flashGradientB,
    required this.flashGradientC,
    required this.flashGradientD,
    required this.flashOrb1,
    required this.flashOrb2,
    required this.flashOrb3,
    required this.streakLevel1,
    required this.streakLevel2,
    required this.streakLevel3,
    required this.streakLevel4,
    required this.streakMilestone,
  });

  factory AppSemanticColors.light() => const AppSemanticColors(
        background: Color(0xFFF7F7FB),
        pageBackground: Color(0xFFF7F7FB),
        navBar: Color(0xFFEDEAFF),
        white: Colors.white,
        cardBackground: Colors.white,

        textPrimary: Color(0xFF2B2B3A),
        textSecondary: Color(0xFF6B6B7A),
        textMuted: Color(0xFF6B6B7A),
        textPrimaryStrong: Color(0xFF1F1F28),

        learning: Color(0xFF9B8CFF),
        known: Color(0xFF9FC7A6),
        learned: Color(0xFFFFD54F),
        textOnStatus: Colors.white,

        heatEmpty: Color(0xFFE6E6EB),
        heatLow: Color(0xFFBEE3DB),
        heatMidLow: Color(0xFF86D1C1),
        heatMid: Color(0xFF4FBFA8),
        heatHigh: Color(0xFF2AAE91),

        fab: Color(0xFF7C6CFF),
        loader: Color(0xFF7C6CFF),
        shadow: Color(0x42000000),
        danger: Color(0xFFFF6B6B),
        dangerBg: Color(0x33FF6B6B),
        iconBg: Color(0x1F2E2323),

        border: Color(0x1F000000),
        controlBorder: Color(0x1F000000),
        cardShadow: Color(0x11000000),

        badge: Color(0xFF5C7CF2),
        badgeBg: Color(0x295C7CF2),
        infoLink: Color(0xFF4C7DFF),
        appBarText: Color(0xFF1F1F28),

        // Flashcards colors
        flashcardsAppBarText: Colors.white,
        flashGlass: Color(0x26FFFFFF),
        flashGradientA: Color(0xFF1E1B4B),
        flashGradientB: Color(0xFF1D4ED8),
        flashGradientC: Color(0xFF0F766E),
        flashGradientD: Color(0xFFF59E0B),
        flashOrb1: Color(0xFFEC4899),
        flashOrb2: Color(0xFF38BDF8),
        flashOrb3: Color(0xFF34D399),

        streakLevel1: Color(0xFF60A5FA),
        streakLevel2: Color(0xFF22C55E),
        streakLevel3: Color(0xFFF59E0B),
        streakLevel4: Color(0xFFEC4899),
        streakMilestone: Color(0xFFFFD54F),
      );

  factory AppSemanticColors.dark() => const AppSemanticColors(
        background: Color(0xFF121212),
        pageBackground: Color(0xFF0F0F12),
        navBar: Color(0xFF15151A),
        white: Colors.white,
        cardBackground: Color(0xFF1A1A1F),

        textPrimary: Color(0xFFF2F2F5),
        textSecondary: Color(0xFFB0B0BD),
        textMuted: Color(0xFF8A8A98),
        textPrimaryStrong: Color(0xFFFFFFFF),

        learning: Color(0xFF7C6CFF),
        known: Color(0xFF7FD1A0),
        learned: Color(0xFFFFC107),
        textOnStatus: Colors.white,

        heatEmpty: Color(0xFF2A2A30),
        heatLow: Color(0xFF1F4D45),
        heatMidLow: Color(0xFF2E7C6F),
        heatMid: Color(0xFF3FAF95),
        heatHigh: Color(0xFF4ED1B0),

        fab: Color(0xFF8A7CFF),
        loader: Color(0xFF8A7CFF),
        shadow: Color(0x33000000),
        danger: Color(0xFFFF6B6B),
        dangerBg: Color(0x33FF6B6B),
        iconBg: Color(0x33FFFFFF),

        border: Color(0x33FFFFFF),
        controlBorder: Color(0x33FFFFFF),
        cardShadow: Color(0x33000000),

        badge: Color(0xFF7A9CFF),
        badgeBg: Color(0x337A9CFF),
        infoLink: Color(0xFF6EA8FF),
        appBarText: Color(0xFFF2F2F5),

        // Flashcards colors
        flashcardsAppBarText: Colors.white,
        flashGlass: Color(0x24FFFFFF),
        flashGradientA: Color(0xFF0F172A),
        flashGradientB: Color(0xFF312E81),
        flashGradientC: Color(0xFF0F766E),
        flashGradientD: Color(0xFFB45309),
        flashOrb1: Color(0xFFDB2777),
        flashOrb2: Color(0xFF2563EB),
        flashOrb3: Color(0xFF10B981),

        streakLevel1: Color(0xFF60A5FA),
        streakLevel2: Color(0xFF4ADE80),
        streakLevel3: Color(0xFFFBBF24),
        streakLevel4: Color(0xFFF472B6),
        streakMilestone: Color(0xFFFFD54F),
      );

  @override
  AppSemanticColors copyWith({
    Color? background,
    Color? pageBackground,
    Color? navBar,
    Color? white,
    Color? cardBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textPrimaryStrong,
    Color? learning,
    Color? known,
    Color? learned,
    Color? textOnStatus,
    Color? heatEmpty,
    Color? heatLow,
    Color? heatMidLow,
    Color? heatMid,
    Color? heatHigh,
    Color? fab,
    Color? loader,
    Color? shadow,
    Color? danger,
    Color? dangerBg,
    Color? iconBg,
    Color? border,
    Color? controlBorder,
    Color? cardShadow,
    Color? badge,
    Color? badgeBg,
    Color? infoLink,
    Color? appBarText,
    Color? flashcardsAppBarText,
    Color? flashGlass,
    Color? flashGradientA,
    Color? flashGradientB,
    Color? flashGradientC,
    Color? flashGradientD,
    Color? flashOrb1,
    Color? flashOrb2,
    Color? flashOrb3,
    Color? streakLevel1,
    Color? streakLevel2,
    Color? streakLevel3,
    Color? streakLevel4,
    Color? streakMilestone,
  }) {
    return AppSemanticColors(
      background: background ?? this.background,
      pageBackground: pageBackground ?? this.pageBackground,
      navBar: navBar ?? this.navBar,
      white: white ?? this.white,
      cardBackground: cardBackground ?? this.cardBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textPrimaryStrong: textPrimaryStrong ?? this.textPrimaryStrong,
      learning: learning ?? this.learning,
      known: known ?? this.known,
      learned: learned ?? this.learned,
      textOnStatus: textOnStatus ?? this.textOnStatus,
      heatEmpty: heatEmpty ?? this.heatEmpty,
      heatLow: heatLow ?? this.heatLow,
      heatMidLow: heatMidLow ?? this.heatMidLow,
      heatMid: heatMid ?? this.heatMid,
      heatHigh: heatHigh ?? this.heatHigh,
      fab: fab ?? this.fab,
      loader: loader ?? this.loader,
      shadow: shadow ?? this.shadow,
      danger: danger ?? this.danger,
      dangerBg: dangerBg ?? this.dangerBg,
      iconBg: iconBg ?? this.iconBg,
      border: border ?? this.border,
      controlBorder: controlBorder ?? this.controlBorder,
      cardShadow: cardShadow ?? this.cardShadow,
      badge: badge ?? this.badge,
      badgeBg: badgeBg ?? this.badgeBg,
      infoLink: infoLink ?? this.infoLink,
      appBarText: appBarText ?? this.appBarText,
      flashcardsAppBarText: flashcardsAppBarText ?? this.flashcardsAppBarText,
      flashGlass: flashGlass ?? this.flashGlass,
      flashGradientA: flashGradientA ?? this.flashGradientA,
      flashGradientB: flashGradientB ?? this.flashGradientB,
      flashGradientC: flashGradientC ?? this.flashGradientC,
      flashGradientD: flashGradientD ?? this.flashGradientD,
      flashOrb1: flashOrb1 ?? this.flashOrb1,
      flashOrb2: flashOrb2 ?? this.flashOrb2,
      flashOrb3: flashOrb3 ?? this.flashOrb3,
      streakLevel1: streakLevel1 ?? this.streakLevel1,
      streakLevel2: streakLevel2 ?? this.streakLevel2,
      streakLevel3: streakLevel3 ?? this.streakLevel3,
      streakLevel4: streakLevel4 ?? this.streakLevel4,
      streakMilestone: streakMilestone ?? this.streakMilestone,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      background: Color.lerp(background, other.background, t)!,
      pageBackground: Color.lerp(pageBackground, other.pageBackground, t)!,
      navBar: Color.lerp(navBar, other.navBar, t)!,
      white: Color.lerp(white, other.white, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textPrimaryStrong:
          Color.lerp(textPrimaryStrong, other.textPrimaryStrong, t)!,
      learning: Color.lerp(learning, other.learning, t)!,
      known: Color.lerp(known, other.known, t)!,
      learned: Color.lerp(learned, other.learned, t)!,
      textOnStatus: Color.lerp(textOnStatus, other.textOnStatus, t)!,
      heatEmpty: Color.lerp(heatEmpty, other.heatEmpty, t)!,
      heatLow: Color.lerp(heatLow, other.heatLow, t)!,
      heatMidLow: Color.lerp(heatMidLow, other.heatMidLow, t)!,
      heatMid: Color.lerp(heatMid, other.heatMid, t)!,
      heatHigh: Color.lerp(heatHigh, other.heatHigh, t)!,
      fab: Color.lerp(fab, other.fab, t)!,
      loader: Color.lerp(loader, other.loader, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      iconBg: Color.lerp(iconBg, other.iconBg, t)!,
      border: Color.lerp(border, other.border, t)!,
      controlBorder: Color.lerp(controlBorder, other.controlBorder, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      badge: Color.lerp(badge, other.badge, t)!,
      badgeBg: Color.lerp(badgeBg, other.badgeBg, t)!,
      infoLink: Color.lerp(infoLink, other.infoLink, t)!,
      appBarText: Color.lerp(appBarText, other.appBarText, t)!,
      flashcardsAppBarText:
          Color.lerp(flashcardsAppBarText, other.flashcardsAppBarText, t)!,
      flashGlass: Color.lerp(flashGlass, other.flashGlass, t)!,
      flashGradientA: Color.lerp(flashGradientA, other.flashGradientA, t)!,
      flashGradientB: Color.lerp(flashGradientB, other.flashGradientB, t)!,
      flashGradientC: Color.lerp(flashGradientC, other.flashGradientC, t)!,
      flashGradientD: Color.lerp(flashGradientD, other.flashGradientD, t)!,
      flashOrb1: Color.lerp(flashOrb1, other.flashOrb1, t)!,
      flashOrb2: Color.lerp(flashOrb2, other.flashOrb2, t)!,
      flashOrb3: Color.lerp(flashOrb3, other.flashOrb3, t)!,
      streakLevel1: Color.lerp(streakLevel1, other.streakLevel1, t)!,
      streakLevel2: Color.lerp(streakLevel2, other.streakLevel2, t)!,
      streakLevel3: Color.lerp(streakLevel3, other.streakLevel3, t)!,
      streakLevel4: Color.lerp(streakLevel4, other.streakLevel4, t)!,
      streakMilestone: Color.lerp(streakMilestone, other.streakMilestone, t)!,
    );
  }

  Color fromStatus(String status) {
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

  Color heatColor(double ratio) {
    if (ratio <= 0) return heatEmpty;
    if (ratio < 0.25) return heatLow;
    if (ratio < 0.5) return heatMidLow;
    if (ratio < 0.75) return heatMid;
    return heatHigh;
  }

  Color heatFromCount(int count, int maxCount) {
    if (count == 0 || maxCount == 0) return heatEmpty;
    return heatColor(count / maxCount);
  }

  Color textForBackground(Color bg) {
    return bg.computeLuminance() > 0.5 ? textPrimaryStrong : Colors.white;
  }
}

extension AppColorsContextX on BuildContext {
  AppSemanticColors get colors =>
      Theme.of(this).extension<AppSemanticColors>()!;
}
