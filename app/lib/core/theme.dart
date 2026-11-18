import 'package:material_ui/material_ui.dart';

/// code it design tokens (from code-it-assets/css/tokens.css). Dark is the default.
@immutable
class Ci extends ThemeExtension<Ci> {
  const Ci({
    required this.bg,
    required this.surface,
    required this.sunken,
    required this.raised,
    required this.line,
    required this.control,
    required this.ink,
    required this.muted,
    required this.subtle,
    required this.brand,
    required this.brandSoft,
    required this.onBrand,
    required this.teal,
    required this.success,
    required this.successSoft,
    required this.attn,
    required this.attnSoft,
    required this.info,
    required this.infoSoft,
    required this.danger,
    required this.dangerSoft,
    required this.warning,
    required this.warningSoft,
    required this.dark,
  });

  final Color bg, surface, sunken, raised, line, control, ink, muted, subtle;
  final Color brand, brandSoft, onBrand, teal;
  final Color success, successSoft, attn, attnSoft, info, infoSoft, danger, dangerSoft, warning, warningSoft;
  final bool dark;

  static const darkTokens = Ci(
    bg: Color(0xFF07090A),
    surface: Color(0xFF0F1412),
    sunken: Color(0xFF0A0D0C),
    raised: Color(0xFF141B18),
    line: Color(0xFF1D2723),
    control: Color(0xFF5E7468),
    ink: Color(0xFFEAF3EE),
    muted: Color(0xFFA6B8AE),
    subtle: Color(0xFF8A9C92),
    brand: Color(0xFF2BFF88),
    brandSoft: Color(0xFF0E2A1B),
    onBrand: Color(0xFF03140A),
    teal: Color(0xFF3DDCFF),
    success: Color(0xFF4ADE80),
    successSoft: Color(0xFF0E2A1B),
    attn: Color(0xFFFF9F45),
    attnSoft: Color(0xFF3A230C),
    info: Color(0xFF6CB8FF),
    infoSoft: Color(0xFF10263D),
    danger: Color(0xFFFF5C6C),
    dangerSoft: Color(0xFF3A1218),
    warning: Color(0xFFFFC857),
    warningSoft: Color(0xFF33290A),
    dark: true,
  );

  static const lightTokens = Ci(
    bg: Color(0xFFF3F6F4),
    surface: Color(0xFFFFFFFF),
    sunken: Color(0xFFE9EEEB),
    raised: Color(0xFFFFFFFF),
    line: Color(0xFFD5DED9),
    control: Color(0xFF74857B),
    ink: Color(0xFF0A100D),
    muted: Color(0xFF46534C),
    subtle: Color(0xFF5A6860),
    brand: Color(0xFF007A3D),
    brandSoft: Color(0xFFDDF7E8),
    onBrand: Color(0xFFFFFFFF),
    teal: Color(0xFF0E7490),
    success: Color(0xFF15803D),
    successSoft: Color(0xFFDCFCE7),
    attn: Color(0xFFB04A00),
    attnSoft: Color(0xFFFDEEDF),
    info: Color(0xFF1E63B8),
    infoSoft: Color(0xFFE3EEFB),
    danger: Color(0xFFC0262D),
    dangerSoft: Color(0xFFFDE8EA),
    warning: Color(0xFF8A5A00),
    warningSoft: Color(0xFFFFF3D6),
    dark: false,
  );

  @override
  Ci copyWith() => this;

  @override
  Ci lerp(ThemeExtension<Ci>? other, double t) => (other is Ci && t > .5) ? other : this;
}

extension CiX on BuildContext {
  Ci get ci => Theme.of(this).extension<Ci>()!;
  TextTheme get tt => Theme.of(this).textTheme;
}

const kFont = 'Readex';
const kMono = 'FiraCode';
const kDisplay = 'Poppins';

ThemeData buildTheme(Ci c) {
  final base = c.dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  TextStyle s(double size, FontWeight w, Color col, {double h = 1.45}) =>
      TextStyle(fontFamily: kFont, fontSize: size, fontWeight: w, color: col, height: h);
  final text = TextTheme(
    displaySmall: s(30, FontWeight.w700, c.ink, h: 1.25),
    headlineSmall: s(22, FontWeight.w700, c.ink, h: 1.3),
    titleLarge: s(18, FontWeight.w600, c.ink),
    titleMedium: s(15.5, FontWeight.w600, c.ink),
    titleSmall: s(13.5, FontWeight.w600, c.ink),
    bodyLarge: s(15, FontWeight.w400, c.ink),
    bodyMedium: s(14, FontWeight.w400, c.ink),
    bodySmall: s(12.5, FontWeight.w400, c.muted),
    labelLarge: s(14, FontWeight.w600, c.ink),
    labelMedium: s(12, FontWeight.w500, c.muted),
    labelSmall: s(11, FontWeight.w500, c.subtle),
  );
  final scheme = ColorScheme(
    brightness: c.dark ? Brightness.dark : Brightness.light,
    primary: c.brand,
    onPrimary: c.onBrand,
    secondary: c.teal,
    onSecondary: c.onBrand,
    error: c.danger,
    onError: Colors.white,
    surface: c.surface,
    onSurface: c.ink,
    surfaceContainerLowest: c.sunken,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.raised,
    surfaceContainerHighest: c.raised,
    outline: c.line,
    outlineVariant: c.line,
  );
  final r8 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    textTheme: text,
    extensions: [c],
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      iconTheme: IconThemeData(color: c.ink),
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.line)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.sunken,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: text.bodyMedium!.copyWith(color: c.subtle),
      labelStyle: text.bodyMedium!.copyWith(color: c.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.brand, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: c.danger)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.brand,
        foregroundColor: c.onBrand,
        minimumSize: const Size(64, 50),
        shape: r8,
        textStyle: text.labelLarge!.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.ink,
        side: BorderSide(color: c.line),
        minimumSize: const Size(64, 46),
        shape: r8,
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.brand, textStyle: text.labelLarge, shape: r8),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.sunken,
      side: BorderSide(color: c.line),
      labelStyle: text.labelMedium,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: c.line,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.raised,
      contentTextStyle: text.bodyMedium,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: c.line)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.brand,
      foregroundColor: c.onBrand,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: c.ink,
      unselectedLabelColor: c.subtle,
      labelStyle: text.titleSmall,
      unselectedLabelStyle: text.titleSmall!.copyWith(fontWeight: FontWeight.w500),
      indicatorColor: c.brand,
      dividerColor: c.line,
      indicatorSize: TabBarIndicatorSize.label,
    ),
    listTileTheme: ListTileThemeData(iconColor: c.muted, textColor: c.ink, titleTextStyle: text.titleSmall, subtitleTextStyle: text.bodySmall),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onBrand : c.control),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.brand : c.sunken),
      trackOutlineColor: WidgetStateProperty.all(c.line),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.brand, linearTrackColor: c.line),
  );
}
