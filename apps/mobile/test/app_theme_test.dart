import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:widenote_mobile/app/app_theme.dart';

void main() {
  test('WideNoteAppTheme uses calm expressive Material tokens', () {
    final theme = WideNoteAppTheme.light();
    final colors = theme.colorScheme;

    expect(theme.useMaterial3, isTrue);
    expect(colors.primary, isNot(colors.secondary));
    expect(colors.primary, isNot(colors.tertiary));
    expect(colors.secondary, isNot(colors.tertiary));
    expect(colors.surface, const Color(0xFFF3F6FA));
    expect(theme.scaffoldBackgroundColor, colors.surface);
  });

  test('WideNoteAppTheme keeps fixed-format shapes stable', () {
    final theme = WideNoteAppTheme.light();

    final cardShape = theme.cardTheme.shape;
    expect(cardShape, isA<RoundedRectangleBorder>());
    final cardRadius =
        (cardShape! as RoundedRectangleBorder).borderRadius as BorderRadius;
    expect(cardRadius.topLeft.x, lessThanOrEqualTo(8));
    expect(cardRadius.topRight.x, lessThanOrEqualTo(8));
    expect(cardRadius.bottomLeft.x, lessThanOrEqualTo(8));
    expect(cardRadius.bottomRight.x, lessThanOrEqualTo(8));

    final inputBorder = theme.inputDecorationTheme.border;
    expect(inputBorder, isA<OutlineInputBorder>());
    final inputRadius = (inputBorder! as OutlineInputBorder).borderRadius;
    expect(inputRadius.topLeft.x, 8);
  });

  test('WideNoteAppTheme avoids negative letter spacing', () {
    final theme = WideNoteAppTheme.light();
    final styles = <TextStyle?>[
      theme.textTheme.displayLarge,
      theme.textTheme.displayMedium,
      theme.textTheme.displaySmall,
      theme.textTheme.headlineLarge,
      theme.textTheme.headlineMedium,
      theme.textTheme.headlineSmall,
      theme.textTheme.titleLarge,
      theme.textTheme.titleMedium,
      theme.textTheme.titleSmall,
      theme.textTheme.bodyLarge,
      theme.textTheme.bodyMedium,
      theme.textTheme.bodySmall,
      theme.textTheme.labelLarge,
      theme.textTheme.labelMedium,
      theme.textTheme.labelSmall,
    ];

    for (final style in styles) {
      expect(style?.letterSpacing, greaterThanOrEqualTo(0));
    }
  });

  test('WideNoteAppTheme distinguishes selected navigation state', () {
    final theme = WideNoteAppTheme.light();
    final labelResolver = theme.navigationBarTheme.labelTextStyle!;
    final iconResolver = theme.navigationBarTheme.iconTheme!;

    final selectedLabel = labelResolver.resolve({WidgetState.selected});
    final unselectedLabel = labelResolver.resolve({});
    expect(selectedLabel?.fontWeight, FontWeight.w700);
    expect(unselectedLabel?.fontWeight, FontWeight.w600);
    expect(selectedLabel?.color, theme.colorScheme.secondary);

    final selectedIcon = iconResolver.resolve({WidgetState.selected});
    final unselectedIcon = iconResolver.resolve({});
    expect(selectedIcon?.size, greaterThan(unselectedIcon?.size ?? 0));
    expect(selectedIcon?.color, theme.colorScheme.secondary);
  });
}
