import 'package:material_ui/material_ui.dart';

enum BlackBoxStyle { aviation, terminal, terminalLight }

extension BlackBoxStyleInfo on BlackBoxStyle {
  String get label => switch (this) {
    BlackBoxStyle.aviation => 'Flight Deck',
    BlackBoxStyle.terminal => 'Dark',
    BlackBoxStyle.terminalLight => 'Light',
  };

  String get subtitle => switch (this) {
    BlackBoxStyle.aviation => 'Charcoal, clear type, safety orange',
    BlackBoxStyle.terminal => 'Pale green on deep forest',
    BlackBoxStyle.terminalLight => 'Forest green on warm white',
  };
}

/// Fonts are bundled with the app so these styles need no font downloads.
ThemeData buildBlackBoxTheme(BlackBoxStyle style) {
  final terminal = style != BlackBoxStyle.aviation;
  final light = style == BlackBoxStyle.terminalLight;
  final bodyFont = terminal ? 'IBM Plex Mono' : 'Barlow';
  final headingFont = terminal ? 'IBM Plex Mono' : 'Barlow Condensed';
  final emphasis = terminal ? FontWeight.w500 : FontWeight.w600;
  final radius = terminal ? 8.0 : 16.0;
  final canvas = light
      ? const Color(0xFFF5F6EF)
      : terminal
      ? const Color(0xFF07120D)
      : const Color(0xFF101416);
  final panel = light
      ? const Color(0xFFFFFFFF)
      : terminal
      ? const Color(0xFF0C1D13)
      : const Color(0xFF1B2225);
  final raised = light
      ? const Color(0xFFE5EDE2)
      : terminal
      ? const Color(0xFF13291C)
      : const Color(0xFF252F33);
  final accent = light
      ? const Color(0xFF245B35)
      : terminal
      ? const Color(0xFF9BE8B2)
      : const Color(0xFFFF9E54);
  final text = light
      ? const Color(0xFF163B26)
      : terminal
      ? const Color(0xFFD3F3DB)
      : const Color(0xFFF3F2EC);
  final muted = light
      ? const Color(0xFF42634D)
      : terminal
      ? const Color(0xFF98B7A0)
      : const Color(0xFFBAC6C5);
  final line = light
      ? const Color(0xFF657D67)
      : terminal
      ? const Color(0xFF587862)
      : const Color(0xFF738783);
  final softLine = light
      ? const Color(0xFFA8BCA7)
      : terminal
      ? const Color(0xFF294534)
      : const Color(0xFF38464A);
  final colors = light
      ? ColorScheme.light(
          primary: accent,
          onPrimary: const Color(0xFFFFFFFF),
          primaryContainer: const Color(0xFFD9EBCF),
          onPrimaryContainer: const Color(0xFF12351F),
          secondary: const Color(0xFF3C6343),
          onSecondary: const Color(0xFFFFFFFF),
          secondaryContainer: const Color(0xFFE0EBDC),
          onSecondaryContainer: const Color(0xFF25442D),
          tertiary: const Color(0xFF80551A),
          onTertiary: const Color(0xFFFFFFFF),
          tertiaryContainer: const Color(0xFFF7E7BF),
          onTertiaryContainer: const Color(0xFF553A0C),
          error: const Color(0xFFA52922),
          onError: const Color(0xFFFFFFFF),
          errorContainer: const Color(0xFFFBE4DE),
          onErrorContainer: const Color(0xFF6E1C18),
          surface: panel,
          onSurface: text,
          onSurfaceVariant: muted,
          outline: line,
          outlineVariant: softLine,
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: text,
          onInverseSurface: canvas,
          inversePrimary: const Color(0xFF9BE8B2),
          surfaceTint: accent,
          surfaceDim: const Color(0xFFDCE7D8),
          surfaceBright: panel,
          surfaceContainerLowest: canvas,
          surfaceContainerLow: panel,
          surfaceContainer: panel,
          surfaceContainerHigh: raised,
          surfaceContainerHighest: const Color(0xFFDCE7D8),
        )
      : ColorScheme.dark(
          primary: accent,
          onPrimary: terminal
              ? const Color(0xFF082211)
              : const Color(0xFF291400),
          primaryContainer: terminal
              ? const Color(0xFF173D24)
              : const Color(0xFF49301D),
          onPrimaryContainer: terminal
              ? const Color(0xFFB7F4C8)
              : const Color(0xFFFFD4B1),
          secondary: terminal
              ? const Color(0xFFB4D6B6)
              : const Color(0xFFA9C9B2),
          onSecondary: const Color(0xFF10271A),
          secondaryContainer: const Color(0xFF213A2C),
          onSecondaryContainer: const Color(0xFFD0EAD7),
          tertiary: const Color(0xFFECCB82),
          onTertiary: const Color(0xFF2E2307),
          tertiaryContainer: const Color(0xFF453719),
          onTertiaryContainer: const Color(0xFFFFE3A3),
          error: const Color(0xFFFFB4AB),
          onError: const Color(0xFF4B0906),
          errorContainer: const Color(0xFF522B29),
          onErrorContainer: const Color(0xFFFFDAD6),
          surface: panel,
          onSurface: text,
          onSurfaceVariant: muted,
          outline: line,
          outlineVariant: softLine,
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: text,
          onInverseSurface: canvas,
          inversePrimary: terminal
              ? const Color(0xFF245B35)
              : const Color(0xFF774015),
          surfaceTint: accent,
          surfaceDim: canvas,
          surfaceBright: raised,
          surfaceContainerLowest: canvas,
          surfaceContainerLow: panel,
          surfaceContainer: panel,
          surfaceContainerHigh: raised,
          surfaceContainerHighest: terminal
              ? const Color(0xFF1C3826)
              : const Color(0xFF303D42),
        );

  TextStyle heading(double size) => TextStyle(
    fontFamily: headingFont,
    fontSize: size,
    fontWeight: emphasis,
    height: 1.15,
    letterSpacing: terminal ? -0.4 : 0.1,
    color: text,
  );
  TextStyle body(double size) => TextStyle(
    fontFamily: bodyFont,
    fontSize: size,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: text,
  );
  TextStyle label(double size) => TextStyle(
    fontFamily: bodyFont,
    fontSize: size,
    fontWeight: emphasis,
    height: 1.25,
    letterSpacing: terminal ? 0 : 0.2,
    color: text,
  );

  final textTheme = TextTheme(
    displayLarge: heading(terminal ? 36 : 48),
    displayMedium: heading(terminal ? 32 : 40),
    displaySmall: heading(terminal ? 28 : 34),
    headlineLarge: heading(terminal ? 26 : 32),
    headlineMedium: heading(terminal ? 23 : 28),
    headlineSmall: heading(terminal ? 21 : 24),
    titleLarge: heading(terminal ? 19 : 22),
    titleMedium: label(terminal ? 16 : 18),
    titleSmall: label(terminal ? 15 : 16),
    bodyLarge: body(terminal ? 16 : 17),
    bodyMedium: body(terminal ? 15 : 16),
    bodySmall: body(terminal ? 13 : 14).copyWith(color: muted),
    labelLarge: label(terminal ? 14 : 15),
    labelMedium: label(13),
    labelSmall: label(12).copyWith(color: muted),
  );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(radius),
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(terminal ? 6 : 12),
    borderSide: BorderSide(color: line),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: light ? Brightness.light : Brightness.dark,
    colorScheme: colors,
    scaffoldBackgroundColor: canvas,
    canvasColor: panel,
    cardColor: panel,
    dividerColor: softLine,
    disabledColor: muted.withValues(alpha: light ? 0.65 : 0.45),
    hintColor: muted,
    focusColor: accent.withValues(alpha: 0.18),
    hoverColor: accent.withValues(alpha: 0.08),
    fontFamily: bodyFont,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    splashFactory: NoSplash.splashFactory,
    iconTheme: IconThemeData(color: muted, size: 22),
    primaryIconTheme: IconThemeData(color: accent, size: 22),
    appBarTheme: AppBarThemeData(
      backgroundColor: canvas,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      iconTheme: IconThemeData(color: text, size: 24),
    ),
    cardTheme: CardThemeData(
      color: panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: shape.copyWith(side: BorderSide(color: softLine)),
    ),
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: canvas,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: textTheme.bodyMedium!.copyWith(color: muted),
      floatingLabelStyle: textTheme.labelLarge!.copyWith(color: accent),
      hintStyle: textTheme.bodyMedium!.copyWith(color: muted),
      helperStyle: textTheme.bodySmall,
      errorStyle: textTheme.bodySmall!.copyWith(color: colors.error),
      errorMaxLines: 3,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: accent, width: 2),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: colors.error, width: 2),
      ),
      disabledBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: softLine),
      ),
      prefixIconColor: muted,
      suffixIconColor: muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: raised,
        disabledForegroundColor: muted,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: textTheme.labelLarge,
        shape: shape,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: light ? raised : null,
        disabledForegroundColor: light ? muted : null,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: textTheme.labelLarge,
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: text,
        disabledForegroundColor: light ? muted : null,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        side: BorderSide(color: line),
        textStyle: textTheme.labelLarge,
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        disabledForegroundColor: light ? muted : null,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        textStyle: textTheme.labelLarge,
        shape: shape,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: text,
        disabledForegroundColor: light ? muted.withValues(alpha: 0.65) : null,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.all(12),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
        shape: WidgetStatePropertyAll(shape),
        side: WidgetStatePropertyAll(BorderSide(color: line)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => light && states.contains(WidgetState.disabled)
              ? raised
              : states.contains(WidgetState.selected)
              ? colors.primaryContainer
              : panel,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => light && states.contains(WidgetState.disabled)
              ? muted
              : states.contains(WidgetState.selected)
              ? colors.onPrimaryContainer
              : muted,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 76,
      indicatorColor: colors.primaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(terminal ? 6 : 12),
        side: light ? BorderSide(color: line) : BorderSide.none,
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelSmall!.copyWith(
          color: states.contains(WidgetState.selected) ? accent : muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 23,
          color: states.contains(WidgetState.selected) ? accent : muted,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: canvas,
      indicatorColor: colors.primaryContainer,
      indicatorShape: light
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: line),
            )
          : null,
      selectedIconTheme: IconThemeData(color: accent, size: 24),
      unselectedIconTheme: IconThemeData(color: muted, size: 24),
      selectedLabelTextStyle: textTheme.labelMedium!.copyWith(color: accent),
      unselectedLabelTextStyle: textTheme.labelMedium!.copyWith(color: muted),
      useIndicator: true,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? accent : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(colors.onPrimary),
      side: BorderSide(color: line, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: panel,
      disabledColor: light ? raised : null,
      selectedColor: colors.primaryContainer,
      secondarySelectedColor: colors.primaryContainer,
      labelStyle: textTheme.labelMedium,
      secondaryLabelStyle: textTheme.labelMedium!.copyWith(
        color: colors.onPrimaryContainer,
      ),
      checkmarkColor: accent,
      side: BorderSide(color: line),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(terminal ? 6 : 10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: muted,
      textColor: text,
      selectedColor: accent,
      selectedTileColor: colors.primaryContainer,
      titleTextStyle: textTheme.titleSmall,
      subtitleTextStyle: textTheme.bodySmall,
      minVerticalPadding: 10,
      shape: shape,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(terminal ? 12 : 24),
        side: BorderSide(color: softLine),
      ),
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: panel,
      modalBackgroundColor: panel,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: line,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(terminal ? 12 : 24),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: raised,
      surfaceTintColor: Colors.transparent,
      textStyle: textTheme.bodyMedium,
      shape: shape,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: raised,
      contentTextStyle: textTheme.bodyMedium,
      actionTextColor: accent,
      behavior: SnackBarBehavior.floating,
      shape: shape,
    ),
    dividerTheme: DividerThemeData(color: softLine, thickness: 1, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: accent,
      linearTrackColor: raised,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: accent.withValues(alpha: light ? 0.20 : 0.28),
      selectionHandleColor: accent,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: raised,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: textTheme.bodySmall!.copyWith(color: text),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
  );
}

bool isTerminalContext(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium?.fontFamily == 'IBM Plex Mono';
