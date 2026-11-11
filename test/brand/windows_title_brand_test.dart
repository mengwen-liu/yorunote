import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/components/windows_title_brand.dart';

String _asset(WidgetTester tester) {
  ImageProvider provider = tester.widget<Image>(find.byType(Image)).image;
  if (provider is ResizeImage) provider = provider.imageProvider;
  return (provider as AssetImage).assetName;
}

RawImage _raw(WidgetTester tester) =>
    tester.widget<RawImage>(find.byType(RawImage));

Future<void> _loaded(WidgetTester tester) async {
  for (var i = 0; i < 100 && _raw(tester).image == null; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(_raw(tester).image, isNotNull);
}

Widget _app({bool reducedMotion = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reducedMotion),
      child: const Center(child: WindowsTitleBrand()),
    ),
  );
}

void main() {
  setUp(() {
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  testWidgets('title logo really decodes multiple GIF frames', (tester) async {
    await tester.pumpWidget(_app());
    expect(_asset(tester), WindowsTitleBrand.animatedAsset);
    await _loaded(tester);
    final first = _raw(tester).image;
    var advanced = false;
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 240));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
      if (!identical(first, _raw(tester).image)) {
        advanced = true;
        break;
      }
    }
    expect(advanced, isTrue, reason: 'The GIF must deliver another frame');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion keeps a static, accessible, bounded logo', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(reducedMotion: true));
    expect(_asset(tester), WindowsTitleBrand.staticAsset);
    await _loaded(tester);
    expect(tester.getSize(find.byType(WindowsTitleBrand)), const Size(72, 36));
    expect(tester.getSize(find.byType(Image)), const Size(28, 28));
    expect(find.bySemanticsLabel('Yorunote'), findsOneWidget);
    final first = _raw(tester).image;
    await tester.pump(const Duration(seconds: 2));
    expect(identical(first, _raw(tester).image), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });

  testWidgets('inactive window stops the GIF and resumes on focus', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await _loaded(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(_asset(tester), WindowsTitleBrand.staticAsset);
    await _loaded(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(_asset(tester), WindowsTitleBrand.animatedAsset);
    await _loaded(tester);
    await tester.pumpWidget(const SizedBox());
  });
}
