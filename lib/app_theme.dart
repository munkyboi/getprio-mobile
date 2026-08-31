import 'package:shadcn_flutter/shadcn_flutter.dart';

/// GetPrio's shared customer-facing visual language, based on the web app.
class GetPrioTheme {
  static const paper = Color(0xFFFBF7F1);
  static const paperAccent = Color(0xFFF2DFC9);
  static const card = Color(0xFFFFFAF4);
  static const ink = Color(0xFF23180F);
  static const mutedInk = Color(0xFF735F50);
  static const orange = Color(0xFFBB4D00);
  static const orangeStrong = Color(0xFF912F00);
  static const teal = Color(0xFF0F766E);
  static const highlight = Color(0xFFFFD166);
  static const line = Color(0x265F422A);

  static ThemeData light() {
    final base = ThemeData(
      colorScheme: LegacyColorSchemes.lightZinc().copyWith(
        background: () => paper,
        foreground: () => ink,
        card: () => card,
        cardForeground: () => ink,
        popover: () => card,
        popoverForeground: () => ink,
        primary: () => orange,
        primaryForeground: () => const Color(0xFFFFFFFF),
        secondary: () => teal,
        secondaryForeground: () => const Color(0xFFFFFFFF),
        muted: () => const Color(0xFFF6EDE3),
        mutedForeground: () => mutedInk,
        accent: () => highlight,
        accentForeground: () => ink,
        destructive: () => const Color(0xFFB42318),
        destructiveForeground: () => const Color(0xFFFFFFFF),
        border: () => line,
        input: () => line,
        ring: () => orange,
      ),
      radius: 1.0,
    );
    final typography = base.typography;
    TextStyle heading(TextStyle style) {
      return style.copyWith(
        color: ink,
        fontFamily: 'Georgia',
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      );
    }

    return base.copyWith(
      typography: () => typography.copyWith(
        sans: () => typography.sans.copyWith(fontFamily: 'Inter'),
        h1: () => heading(typography.h1),
        h2: () => heading(typography.h2),
        h3: () => heading(typography.h3),
        h4: () => heading(typography.h4),
        p: () => typography.p.copyWith(color: ink),
        textMuted: () => typography.textMuted.copyWith(color: mutedInk),
      ),
    );
  }
}
