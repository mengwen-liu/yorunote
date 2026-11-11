import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/ui_tokens.dart';

void main() {
  test('spacing scale', () {
    expect(
      [UiSpace.s1, UiSpace.s2, UiSpace.s3, UiSpace.s4, UiSpace.s6, UiSpace.s8],
      [4, 8, 12, 16, 24, 32],
    );
  });

  test('radius and size tokens', () {
    expect(UiRadius.card, 16);
    expect(UiRadius.cover, inInclusiveRange(8, 12));
    expect(UiSize.minTouchTarget, greaterThanOrEqualTo(48));
    expect(UiSize.coverWidth, 98);
    expect(UiSize.coverHeight, 136);
  });

  // Roles must follow whichever ColorScheme is active. Different seeds stand
  // in for Dynamic Color, which also produces an arbitrary ColorScheme.
  for (final brightness in Brightness.values) {
    for (final seed in [Colors.teal, Colors.pink]) {
      test('color roles follow ColorScheme ($brightness, $seed)', () {
        final scheme = ColorScheme.fromSeed(
          seedColor: seed,
          brightness: brightness,
        );
        expect(scheme.uiCardFill, scheme.surfaceContainerHigh);
        expect(scheme.uiTextPrimary, scheme.onSurface);
        expect(scheme.uiTextSecondary, scheme.onSurfaceVariant);
        expect(scheme.uiCoverFill, scheme.secondaryContainer);
        expect(scheme.uiOnCoverFill, scheme.onSecondaryContainer);
        expect(scheme.uiBadgeFill, scheme.secondaryContainer);
        expect(scheme.uiOnBadge, scheme.onSecondaryContainer);
        expect(scheme.uiProgressIndicator, scheme.primary);
        expect(scheme.uiProgressTrack, scheme.outlineVariant);
      });
    }
  }

  test('text roles follow TextTheme', () {
    final textTheme = ThemeData().textTheme;
    expect(textTheme.uiPageTitle, textTheme.titleLarge);
    expect(textTheme.uiBody, textTheme.bodyMedium);
    expect(textTheme.uiCaption, textTheme.bodySmall);
    expect(textTheme.uiSectionTitle?.fontSize, 18);
    expect(textTheme.uiSectionTitle?.fontWeight, FontWeight.w600);
    expect(textTheme.uiItemTitle?.fontSize, textTheme.bodyLarge?.fontSize);
    expect(textTheme.uiItemTitle?.fontWeight, FontWeight.w600);
  });
}
