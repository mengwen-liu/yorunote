import 'package:flutter/material.dart';

/// Design tokens for the Home refresh (UI Refresh v0.1, UX-01).
///
/// These tokens only name existing Material values. They do not create a
/// theme: colors come from the ambient [ColorScheme] and text styles from the
/// ambient [TextTheme], so Light / Dark / Dynamic Color keep working.

/// Spacing scale in logical pixels.
abstract final class UiSpace {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s6 = 24;
  static const double s8 = 32;
}

/// Corner radii in logical pixels.
abstract final class UiRadius {
  /// Comic cover thumbnails.
  static const double cover = 8;

  /// Cards and panels.
  static const double card = 16;
}

/// Sizes in logical pixels.
abstract final class UiSize {
  /// Minimum interactive size recommended by Android.
  static const double minTouchTarget = 48;

  /// Same cover size as the existing `SimpleComicTile`.
  static const double coverWidth = 98;
  static const double coverHeight = 136;
}

/// Semantic color roles resolved from a [ColorScheme].
extension UiColorRoles on ColorScheme {
  Color get uiCardFill => surfaceContainerHigh;

  Color get uiTextPrimary => onSurface;

  Color get uiTextSecondary => onSurfaceVariant;

  Color get uiCoverFill => secondaryContainer;

  Color get uiOnCoverFill => onSecondaryContainer;

  Color get uiBadgeFill => secondaryContainer;

  Color get uiOnBadge => onSecondaryContainer;

  Color get uiProgressIndicator => primary;

  Color get uiProgressTrack => outlineVariant;
}

/// Typography roles resolved from a [TextTheme].
extension UiTextRoles on TextTheme {
  TextStyle? get uiPageTitle => titleLarge;

  TextStyle? get uiSectionTitle =>
      titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.w600);

  TextStyle? get uiItemTitle =>
      bodyLarge?.copyWith(fontWeight: FontWeight.w600);

  TextStyle? get uiBody => bodyMedium;

  TextStyle? get uiCaption => bodySmall;
}
