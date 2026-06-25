import 'package:flutter/material.dart';

abstract final class WideNoteAppTheme {
  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: _primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: _primary,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFDDE8FF),
          onPrimaryContainer: const Color(0xFF071B3D),
          secondary: _secondary,
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFD4EFEB),
          onSecondaryContainer: const Color(0xFF063B34),
          tertiary: _tertiary,
          onTertiary: Colors.white,
          tertiaryContainer: const Color(0xFFFFE3BF),
          onTertiaryContainer: const Color(0xFF4A2600),
          error: _error,
          onError: Colors.white,
          surface: _surface,
          onSurface: _ink,
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFF8FAFD),
          surfaceContainer: const Color(0xFFF0F4F8),
          surfaceContainerHigh: const Color(0xFFE8EEF5),
          surfaceContainerHighest: const Color(0xFFDDE6F0),
          outline: _outline,
          outlineVariant: _outlineSubtle,
        );
    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    final textTheme = _textTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        elevation: 2,
        backgroundColor: colorScheme.surfaceContainerLowest.withValues(
          alpha: 0.96,
        ),
        indicatorColor: colorScheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelMedium?.copyWith(
            color: selected ? colorScheme.secondary : colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: 0,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colorScheme.secondary : colorScheme.onSurface,
            size: selected ? 27 : 25,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: _inputBorder(colorScheme.outlineVariant),
        enabledBorder: _inputBorder(colorScheme.outlineVariant),
        focusedBorder: _inputBorder(colorScheme.primary, width: 1.6),
        errorBorder: _inputBorder(colorScheme.error),
        focusedErrorBorder: _inputBorder(colorScheme.error, width: 1.6),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
          letterSpacing: 0,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: _cardRadius,
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(44, 42),
          shape: RoundedRectangleBorder(borderRadius: _controlRadius),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(44, 42),
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(borderRadius: _controlRadius),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge,
          minimumSize: const Size(44, 40),
          shape: RoundedRectangleBorder(borderRadius: _controlRadius),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: _controlRadius),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        selectedColor: colorScheme.secondaryContainer,
        disabledColor: colorScheme.surfaceContainerHigh,
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: colorScheme.onSecondaryContainer,
          letterSpacing: 0,
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: const StadiumBorder(),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.primary,
        textColor: colorScheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: _cardRadius),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          letterSpacing: 0,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: _cardRadius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: _cardRadius),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
    );
  }
}

const _primary = Color(0xFF255EA8);
const _secondary = Color(0xFF2F7D73);
const _tertiary = Color(0xFFB86618);
const _error = Color(0xFFB3261E);
const _ink = Color(0xFF1B2028);
const _surface = Color(0xFFF3F6FA);
const _outline = Color(0xFF8A96A8);
const _outlineSubtle = Color(0xFFD2DAE5);

final _cardRadius = BorderRadius.circular(8);
final _controlRadius = BorderRadius.circular(8);

OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: _controlRadius,
    borderSide: BorderSide(color: color, width: width),
  );
}

TextTheme _textTheme(TextTheme base) {
  return base.copyWith(
    displayLarge: _type(base.displayLarge, weight: FontWeight.w700),
    displayMedium: _type(base.displayMedium, weight: FontWeight.w700),
    displaySmall: _type(base.displaySmall, weight: FontWeight.w700),
    headlineLarge: _type(base.headlineLarge, weight: FontWeight.w700),
    headlineMedium: _type(base.headlineMedium, weight: FontWeight.w700),
    headlineSmall: _type(base.headlineSmall, weight: FontWeight.w700),
    titleLarge: _type(base.titleLarge, weight: FontWeight.w700),
    titleMedium: _type(base.titleMedium, weight: FontWeight.w700),
    titleSmall: _type(base.titleSmall, weight: FontWeight.w700),
    bodyLarge: _type(base.bodyLarge),
    bodyMedium: _type(base.bodyMedium),
    bodySmall: _type(base.bodySmall),
    labelLarge: _type(base.labelLarge, weight: FontWeight.w700),
    labelMedium: _type(base.labelMedium, weight: FontWeight.w700),
    labelSmall: _type(base.labelSmall, weight: FontWeight.w700),
  );
}

TextStyle? _type(TextStyle? style, {FontWeight? weight}) {
  return style?.copyWith(
    fontWeight: weight ?? style.fontWeight,
    letterSpacing: 0,
  );
}
