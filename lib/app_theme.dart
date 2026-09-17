import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Shared typography tokens for the customer-facing app.
///
/// Keep the scale between 10px and 28px so screens can change their visual
/// hierarchy by consuming named roles instead of introducing new pixel values.
class GetPrioTypography {
  static const displayFontFamily = 'Georgia';
  static const uiFontFamily = 'Inter';

  static const displayLargeSize = 28.0;
  static const displaySize = 24.0;
  static const titleSize = 21.0;
  static const headingSize = 18.0;
  static const headingSmallSize = 16.0;
  static const bodyLargeSize = 14.0;
  static const bodySize = 12.0;
  static const labelSize = 11.0;
  static const captionSize = 10.0;
  static const ticketSize = 28.0;

  static const displayLargeLineHeight = 1.15;
  static const displayLineHeight = 1.20;
  static const titleLineHeight = 1.20;
  static const headingLineHeight = 1.30;
  static const headingSmallLineHeight = 1.35;
  static const bodyLargeLineHeight = 1.50;
  static const bodyLineHeight = 1.50;
  static const labelLineHeight = 1.30;
  static const captionLineHeight = 1.35;
  static const ticketLineHeight = 1.15;

  static const displayWeight = FontWeight.w700;
  static const bodyWeight = FontWeight.w400;
  static const labelWeight = FontWeight.w600;
  static const captionWeight = FontWeight.w500;

  const GetPrioTypography._();
}

/// GetPrio's shared customer-facing visual language, based on the web app.
class GetPrioTheme {
  // The drawer already reserves vertical space for its drag indicator.
  static const bottomSheetTopPadding = 0.0;

  static const paper = Color(0xFFFBF7F1);
  static const paperAccent = Color(0xFFF2DFC9);
  static const card = Color(0xFFFFFAF4);
  static const ink = Color(0xFF23180F);
  static const mutedInk = Color(0xFF735F50);
  static const primary = Color(0xFFFD7E14);
  // Keep the legacy name while callers migrate to the semantic token.
  static const orange = primary;
  static const onPrimary = Color(0xFFFFFFFF);
  static const teal = Color(0xFF0F766E);
  static const highlight = Color(0xFFFFD166);
  static const line = Color(0x265F422A);
  static const success = Color(0xFF40C057);
  static const info = Color(0xFF4C6EF5);
  static const warning = Color(0xFFD9480F);
  static const orangeStrong = warning;
  static const destructive = Color(0xFFFA5252);
  static const disabled = Color(0xFFA8A096);
  static const primaryActionShadow = BoxShadow(
    color: Color(0x33FD7E14),
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  static AlignmentGeometry? actionButtonAlignment(BuildContext context) {
    return MediaQuery.sizeOf(context).shortestSide < 600
        ? Alignment.center
        : null;
  }

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
        primary: () => primary,
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
        ring: () => primary,
      ),
      radius: 1.0,
    );
    final typography = base.typography;
    TextStyle heading(
      TextStyle style, {
      required double fontSize,
      required double lineHeight,
    }) {
      return style.copyWith(
        color: ink,
        fontFamily: GetPrioTypography.displayFontFamily,
        fontSize: fontSize,
        fontWeight: GetPrioTypography.displayWeight,
        height: lineHeight,
        letterSpacing: -0.4,
      );
    }

    TextStyle ui(
      TextStyle style, {
      required double fontSize,
      required double lineHeight,
      FontWeight? fontWeight,
      Color? color,
    }) {
      return style.copyWith(
        fontFamily: GetPrioTypography.uiFontFamily,
        fontSize: fontSize,
        color: color ?? ink,
        height: lineHeight,
        fontWeight: fontWeight,
      );
    }

    return base.copyWith(
      typography: () => typography.copyWith(
        sans: () => typography.sans.copyWith(
          fontFamily: GetPrioTypography.uiFontFamily,
        ),
        xSmall: () => ui(
          typography.xSmall,
          fontSize: GetPrioTypography.captionSize,
          lineHeight: GetPrioTypography.captionLineHeight,
          fontWeight: GetPrioTypography.captionWeight,
        ),
        small: () => ui(
          typography.small,
          fontSize: GetPrioTypography.labelSize,
          lineHeight: GetPrioTypography.labelLineHeight,
          fontWeight: GetPrioTypography.labelWeight,
        ),
        base: () => ui(
          typography.base,
          fontSize: GetPrioTypography.bodySize,
          lineHeight: GetPrioTypography.bodyLineHeight,
          fontWeight: GetPrioTypography.bodyWeight,
        ),
        large: () => ui(
          typography.large,
          fontSize: GetPrioTypography.bodyLargeSize,
          lineHeight: GetPrioTypography.bodyLargeLineHeight,
          fontWeight: GetPrioTypography.bodyWeight,
        ),
        xLarge: () => ui(
          typography.xLarge,
          fontSize: GetPrioTypography.headingSmallSize,
          lineHeight: GetPrioTypography.headingSmallLineHeight,
        ),
        x2Large: () => ui(
          typography.x2Large,
          fontSize: GetPrioTypography.headingSize,
          lineHeight: GetPrioTypography.headingLineHeight,
        ),
        x3Large: () => ui(
          typography.x3Large,
          fontSize: GetPrioTypography.titleSize,
          lineHeight: GetPrioTypography.titleLineHeight,
        ),
        x4Large: () => ui(
          typography.x4Large,
          fontSize: GetPrioTypography.displaySize,
          lineHeight: GetPrioTypography.displayLineHeight,
        ),
        x5Large: () => ui(
          typography.x5Large,
          fontSize: GetPrioTypography.displayLargeSize,
          lineHeight: GetPrioTypography.displayLargeLineHeight,
        ),
        x6Large: () => ui(
          typography.x6Large,
          fontSize: GetPrioTypography.displayLargeSize,
          lineHeight: GetPrioTypography.displayLargeLineHeight,
        ),
        x7Large: () => ui(
          typography.x7Large,
          fontSize: GetPrioTypography.displayLargeSize,
          lineHeight: GetPrioTypography.displayLargeLineHeight,
        ),
        x8Large: () => ui(
          typography.x8Large,
          fontSize: GetPrioTypography.displayLargeSize,
          lineHeight: GetPrioTypography.displayLargeLineHeight,
        ),
        x9Large: () => ui(
          typography.x9Large,
          fontSize: GetPrioTypography.displayLargeSize,
          lineHeight: GetPrioTypography.displayLargeLineHeight,
        ),
        h1: () => heading(
          typography.h1,
          fontSize: GetPrioTypography.displayLargeSize,
          lineHeight: GetPrioTypography.displayLargeLineHeight,
        ),
        h2: () => heading(
          typography.h2,
          fontSize: GetPrioTypography.displaySize,
          lineHeight: GetPrioTypography.displayLineHeight,
        ),
        h3: () => heading(
          typography.h3,
          fontSize: GetPrioTypography.headingSize,
          lineHeight: GetPrioTypography.headingLineHeight,
        ),
        h4: () => heading(
          typography.h4,
          fontSize: GetPrioTypography.headingSmallSize,
          lineHeight: GetPrioTypography.headingSmallLineHeight,
        ),
        p: () => ui(
          typography.p,
          fontSize: GetPrioTypography.bodyLargeSize,
          lineHeight: GetPrioTypography.bodyLargeLineHeight,
          fontWeight: GetPrioTypography.bodyWeight,
        ),
        blockQuote: () => ui(
          typography.blockQuote,
          fontSize: GetPrioTypography.bodyLargeSize,
          lineHeight: GetPrioTypography.bodyLargeLineHeight,
        ),
        inlineCode: () => ui(
          typography.inlineCode,
          fontSize: GetPrioTypography.labelSize,
          lineHeight: GetPrioTypography.labelLineHeight,
        ),
        lead: () => ui(
          typography.lead,
          fontSize: GetPrioTypography.headingSmallSize,
          lineHeight: GetPrioTypography.headingSmallLineHeight,
        ),
        textLarge: () => ui(
          typography.textLarge,
          fontSize: GetPrioTypography.headingSmallSize,
          lineHeight: GetPrioTypography.headingSmallLineHeight,
        ),
        textSmall: () => ui(
          typography.textSmall,
          fontSize: GetPrioTypography.labelSize,
          lineHeight: GetPrioTypography.labelLineHeight,
        ),
        textMuted: () => ui(
          typography.textMuted,
          fontSize: GetPrioTypography.bodySize,
          lineHeight: GetPrioTypography.bodyLineHeight,
          color: mutedInk,
          fontWeight: GetPrioTypography.bodyWeight,
        ),
      ),
    );
  }

  static TextStyle titleStyle(ThemeData theme) {
    return theme.typography.h2.copyWith(
      fontSize: GetPrioTypography.titleSize,
      height: GetPrioTypography.titleLineHeight,
    );
  }

  static TextStyle ticketStyle(ThemeData theme) {
    return theme.typography.h1.copyWith(
      fontSize: GetPrioTypography.ticketSize,
      height: GetPrioTypography.ticketLineHeight,
    );
  }
}

enum GetPrioActionButtonStyle { primary, outline, destructive }

class GetPrioActionButton extends StatelessWidget {
  const GetPrioActionButton.primary({
    super.key,
    required this.onPressed,
    required this.child,
    this.leading,
    this.trailing,
  }) : style = GetPrioActionButtonStyle.primary;

  const GetPrioActionButton.outline({
    super.key,
    required this.onPressed,
    required this.child,
    this.leading,
    this.trailing,
  }) : style = GetPrioActionButtonStyle.outline;

  const GetPrioActionButton.destructive({
    super.key,
    required this.onPressed,
    required this.child,
    this.leading,
    this.trailing,
  }) : style = GetPrioActionButtonStyle.destructive;

  final GetPrioActionButtonStyle style;
  final VoidCallback? onPressed;
  final Widget child;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final alignment = GetPrioTheme.actionButtonAlignment(context);
    final centersPhoneLabel = alignment != null;
    final buttonChild = centersPhoneLabel
        ? Stack(
            alignment: Alignment.center,
            children: [
              Align(alignment: Alignment.center, child: child),
              if (leading != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: leading,
                ),
              if (trailing != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: trailing,
                ),
            ],
          )
        : child;
    final buttonLeading = centersPhoneLabel ? null : leading;
    final buttonTrailing = centersPhoneLabel ? null : trailing;
    return switch (style) {
      GetPrioActionButtonStyle.primary => PrimaryButton(
        onPressed: onPressed,
        alignment: alignment,
        leading: buttonLeading,
        trailing: buttonTrailing,
        child: buttonChild,
      ),
      GetPrioActionButtonStyle.outline => OutlineButton(
        onPressed: onPressed,
        alignment: alignment,
        leading: buttonLeading,
        trailing: buttonTrailing,
        child: buttonChild,
      ),
      GetPrioActionButtonStyle.destructive => DestructiveButton(
        onPressed: onPressed,
        alignment: alignment,
        leading: buttonLeading,
        trailing: buttonTrailing,
        child: buttonChild,
      ),
    };
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
