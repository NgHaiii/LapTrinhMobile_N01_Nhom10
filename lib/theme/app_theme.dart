import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF087F8C);
  static const Color secondary = Color(0xFFE76F51);
  static const Color tertiary = Color(0xFFF4A261);

  static ThemeData get light {
    final colors = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      surface: const Color(0xFFF7FAF9),
    );

    return _build(colors);
  }

  static ThemeData get dark {
    final colors = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      primary: const Color(0xFF72D5DE),
      secondary: const Color(0xFFFFB4A2),
      tertiary: const Color(0xFFFFC77D),
      surface: const Color(0xFF101415),
    );

    return _build(colors);
  }

  static ThemeData _build(ColorScheme colors) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      brightness: colors.brightness,
      colorScheme: colors,
    );

    final textTheme = GoogleFonts.manropeTextTheme(
      baseTheme.textTheme,
    ).apply(
      bodyColor: colors.onSurface,
      displayColor: colors.onSurface,
    );

    const radius = BorderRadius.all(Radius.circular(8));

    return baseTheme.copyWith(
      scaffoldBackgroundColor: colors.surface,
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: colors.surface,
        foregroundColor: colors.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colors.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: colors.outlineVariant),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: _inputBorder(colors.outlineVariant),
        enabledBorder: _inputBorder(colors.outlineVariant),
        focusedBorder: _inputBorder(
          colors.primary,
          width: 2,
        ),
        errorBorder: _inputBorder(colors.error),
        focusedErrorBorder: _inputBorder(
          colors.error,
          width: 2,
        ),
        disabledBorder: _inputBorder(
          colors.outlineVariant.withValues(alpha: 0.5),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
        floatingLabelStyle: textTheme.bodyMedium?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w700,
        ),
        errorMaxLines: 2,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Không dùng Size.fromHeight vì nó tạo width Infinity.
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 13,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: radius,
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 13,
          ),
          side: BorderSide(color: colors.outline),
          shape: const RoundedRectangleBorder(
            borderRadius: radius,
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: radius,
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(44),
          shape: const RoundedRectangleBorder(
            borderRadius: radius,
          ),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colors.onInverseSurface,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: radius,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colors.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) {
            return textTheme.labelSmall?.copyWith(
              color: states.contains(WidgetState.selected)
                  ? colors.primary
                  : colors.onSurfaceVariant,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800
                  : FontWeight.w600,
            );
          },
        ),
      ),

      navigationRailTheme: NavigationRailThemeData(
        elevation: 0,
        backgroundColor: colors.surface,
        indicatorColor: colors.primaryContainer,
        selectedIconTheme: IconThemeData(
          color: colors.onPrimaryContainer,
        ),
        selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),

      chipTheme: baseTheme.chipTheme.copyWith(
        shape: const RoundedRectangleBorder(
          borderRadius: radius,
        ),
        side: BorderSide(color: colors.outlineVariant),
        labelStyle: textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),

      dialogTheme: DialogThemeData(
        elevation: 2,
        backgroundColor: colors.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: radius,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surfaceContainerLow,
        modalBackgroundColor: colors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(8),
          ),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: colors.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceContainerHighest,
        circularTrackColor: colors.surfaceContainerHighest,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(
    Color color, {
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: color,
        width: width,
      ),
    );
  }
}