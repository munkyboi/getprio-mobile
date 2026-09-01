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
  static const onPrimary = Color(0xFFFFFFFF);
  static const teal = Color(0xFF0F766E);
  static const highlight = Color(0xFFFFD166);
  static const line = Color(0x265F422A);
  static const success = Color(0xFF397A5A);
  static const warning = Color(0xFFB77932);
  static const destructive = Color(0xFFB42318);
  static const disabled = Color(0xFFA8A096);
  static const primaryActionShadow = BoxShadow(
    color: Color(0x33BB4D00),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  static Widget wrap(Widget child) {
    return ComponentTheme<CardTheme>(
      data: CardTheme(
        padding: const EdgeInsets.all(20),
        borderRadius: BorderRadius.circular(20),
        borderColor: line,
        borderWidth: 1,
        boxShadow: const [
          BoxShadow(
            color: Color(0x145B422A),
            blurRadius: 24,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ComponentTheme<TextFieldTheme>(
        data: TextFieldTheme(
          borderRadius: BorderRadius.circular(16),
          filled: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: ComponentTheme<PrimaryButtonTheme>(
          data: PrimaryButtonTheme(
            decoration: _buttonDecoration(
              radius: 16,
              shadow: const [primaryActionShadow],
            ),
          ),
          child: ComponentTheme<OutlineButtonTheme>(
            data: OutlineButtonTheme(decoration: _buttonDecoration(radius: 16)),
            child: child,
          ),
        ),
      ),
    );
  }

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
        primaryForeground: () => onPrimary,
        secondary: () => teal,
        secondaryForeground: () => onPrimary,
        muted: () => const Color(0xFFF6EDE3),
        mutedForeground: () => mutedInk,
        accent: () => highlight,
        accentForeground: () => ink,
        destructive: () => destructive,
        destructiveForeground: () => onPrimary,
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

    TextStyle body(TextStyle style) {
      return style.copyWith(fontFamily: 'Inter', color: ink, height: 1.5);
    }

    return base.copyWith(
      typography: () => typography.copyWith(
        sans: () => typography.sans.copyWith(fontFamily: 'Inter'),
        h1: () => heading(typography.h1.copyWith(fontSize: 36, height: 1.1)),
        h2: () => heading(typography.h2.copyWith(fontSize: 32, height: 1.15)),
        h3: () => heading(typography.h3.copyWith(fontSize: 22, height: 1.25)),
        h4: () => heading(typography.h4.copyWith(fontSize: 18, height: 1.3)),
        p: () => body(typography.p.copyWith(fontSize: 16)),
        textMuted: () =>
            body(typography.textMuted.copyWith(fontSize: 14, color: mutedInk)),
      ),
    );
  }
}

ButtonStatePropertyDelegate<Decoration> _buttonDecoration({
  required double radius,
  List<BoxShadow>? shadow,
}) {
  return (context, states, value) {
    if (value is! BoxDecoration) return value;
    return value.copyWith(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: shadow,
    );
  };
}
