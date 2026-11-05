import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view.dart';
import 'package:venera/components/reader_image_loading.dart';

import '../../tool/synthetic_source/synthetic_server.dart';

bool _hasPage(WidgetTester tester) => tester
    .widgetList<RawImage>(find.byType(RawImage))
    .any((widget) => widget.image?.width == 600 && widget.image?.height == 900);

Future<void> _waitForPage(WidgetTester tester) async {
  for (var i = 0; i < 100 && !_hasPage(tester); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(_hasPage(tester), isTrue, reason: 'The fixture must really decode');
}

Widget _viewer(
  ImageProvider provider, {
  required bool legacy,
  required bool changed,
}) {
  return MaterialApp(
    theme: ThemeData(
      brightness: changed ? Brightness.dark : Brightness.light,
    ),
    home: MediaQuery(
      data: MediaQueryData(
        size: changed ? const Size(1000, 700) : const Size(900, 600),
      ),
      child: PhotoView(
        imageProvider: provider,
        loadingBuilder: (context, event) {
          if (!legacy) return ReaderImageLoading(event: event);
          // Reproduce the original inline reader callback with this exact
          // locked PhotoView dependency. Its caller owns these subscriptions.
          return PhotoView.customChild(
            childSize: MediaQuery.of(context).size,
            backgroundDecoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        },
      ),
    ),
  );
}

void main() {
  testWidgets('old inline callback reproduces a stuck loaded image', (
    tester,
  ) async {
    final provider = MemoryImage(pagePng(1));
    await tester.pumpWidget(
      _viewer(provider, legacy: true, changed: false),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await _waitForPage(tester);
    await tester.pumpWidget(
      _viewer(provider, legacy: true, changed: true),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(_hasPage(tester), isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reader loading widget preserves the displayed image', (
    tester,
  ) async {
    final provider = MemoryImage(pagePng(2));
    await tester.pumpWidget(
      _viewer(provider, legacy: false, changed: false),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await _waitForPage(tester);
    await tester.pumpWidget(
      _viewer(provider, legacy: false, changed: true),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(_hasPage(tester), isTrue);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
