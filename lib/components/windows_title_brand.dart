import 'package:flutter/material.dart';
import 'package:venera/components/yorunote_mascot.dart';

/// Windows title-bar branding; the native window name remains Yorunote.
class WindowsTitleBrand extends StatelessWidget {
  const WindowsTitleBrand({super.key});

  static const animatedAsset = YorunoteMascot.animatedAsset;
  static const staticAsset = YorunoteMascot.staticAsset;

  @override
  Widget build(BuildContext context) =>
      const YorunoteMascot(width: 72, height: 36);
}
