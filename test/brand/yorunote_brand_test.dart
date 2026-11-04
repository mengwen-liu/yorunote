import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// 解碼後的 RGBA 像素。
class _Px {
  _Px(this.w, this.h, this.d);
  final int w, h;
  final Uint8List d;
  int a(int x, int y) => d[(y * w + x) * 4 + 3];
  List<int> rgba(int x, int y) =>
      List.generate(4, (i) => d[(y * w + x) * 4 + i]);
}

Future<_Px> _load(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  final image = (await codec.getNextFrame()).image;
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return _Px(image.width, image.height, bytes!.buffer.asUint8List());
}

void main() {
  const res = 'android/app/src/main/res';
  const densities = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  };

  test('About 品牌文案在簡繁翻譯中都有對應', () {
    final data =
        jsonDecode(File('assets/translation.json').readAsStringSync())
            as Map<String, dynamic>;
    const keys = [
      'Yorunote is a personal fork of Venera, a free and open-source comic reader.',
      'Based on Venera (GPL-3.0). Personal changes are limited to appearance and bug fixes; all other features come from upstream.',
    ];
    for (final lang in ['zh_CN', 'zh_TW']) {
      for (final k in keys) {
        expect((data[lang] as Map)[k], isNotNull, reason: '$lang 缺少 $k');
      }
    }
  });

  testWidgets('自適應圖示各密度尺寸正確，背景為 #17283B 純色', (tester) async {
    await tester.runAsync(() async {
      for (final e in densities.entries) {
        final size = (108 * e.value).round();
        final bg = await _load(
          '$res/mipmap-${e.key}/ic_launcher_background.png',
        );
        expect([bg.w, bg.h], [size, size]);
        expect(bg.rgba(0, 0), [0x17, 0x28, 0x3B, 255]);
        expect(bg.rgba(size - 1, size ~/ 2), [0x17, 0x28, 0x3B, 255]);
        final fg = await _load(
          '$res/mipmap-${e.key}/ic_launcher_foreground.png',
        );
        expect([fg.w, fg.h], [size, size]);
      }
    });
  });

  testWidgets('前景透明、主體位於可見區；單色層不是整張不透明方塊', (tester) async {
    await tester.runAsync(() async {
      final fg = await _load('$res/mipmap-xxxhdpi/ic_launcher_foreground.png');
      final mono = await _load(
        '$res/mipmap-xxxhdpi/ic_launcher_monochrome.png',
      );
      expect(fg.a(0, 0), 0);
      expect(fg.a(431, 431), 0);
      var opaque = 0, monoOpaque = 0;
      for (var y = 0; y < 432; y++) {
        for (var x = 0; x < 432; x++) {
          if (fg.a(x, y) > 16) {
            opaque++;
            // 432px 中，72dp 可見區為 72..360
            expect(
              x >= 72 && x < 360 && y >= 72 && y < 360,
              isTrue,
              reason: '前景像素超出可見區 ($x,$y)',
            );
          }
          if (mono.a(x, y) > 200) monoOpaque++;
        }
      }
      expect(opaque, greaterThan(432 * 432 * 0.2));
      expect(monoOpaque, greaterThan(0));
      expect(monoOpaque / (432 * 432), lessThan(0.5));
    });
  });

  testWidgets('assets/app_icon.png 為 1024 方形且非空白', (tester) async {
    await tester.runAsync(() async {
      final icon = await _load('assets/app_icon.png');
      expect([icon.w, icon.h], [1024, 1024]);
      expect(icon.rgba(512, 512), isNot(equals(icon.rgba(2, 2))));
    });
  });
}
