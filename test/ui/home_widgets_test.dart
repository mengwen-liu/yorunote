import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/components/home_widgets.dart';

/// Fails to load, like a cover whose source was removed.
class _BrokenImageProvider extends ImageProvider<_BrokenImageProvider> {
  @override
  Future<_BrokenImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_BrokenImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _BrokenImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      Future<ImageInfo>.error(StateError('broken cover')),
    );
  }
}

/// Never finishes loading.
class _PendingImageProvider extends ImageProvider<_PendingImageProvider> {
  @override
  Future<_PendingImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_PendingImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _PendingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
  }
}

/// Minimal harness: a plain MaterialApp with a seeded ColorScheme.
Widget harness(
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  double width = 360,
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: brightness,
      ),
    ),
    builder: (context, app) {
      return MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      );
    },
    home: Scaffold(
      body: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

const _fakeData = RecentComicCardData(
  title: 'Demo Comic',
  detailLine: 'Chapter 3 - Page 8',
  sourceLabel: 'Demo Source',
);

void main() {
  group('ReadingProgress.tryCreate', () {
    test('rejects missing or invalid totals', () {
      expect(ReadingProgress.tryCreate(page: 3, maxPage: null), isNull);
      expect(ReadingProgress.tryCreate(page: 3, maxPage: 0), isNull);
      expect(ReadingProgress.tryCreate(page: 3, maxPage: -1), isNull);
    });

    test('rejects missing or invalid page', () {
      expect(ReadingProgress.tryCreate(page: null, maxPage: 10), isNull);
      expect(ReadingProgress.tryCreate(page: 0, maxPage: 10), isNull);
      expect(ReadingProgress.tryCreate(page: -2, maxPage: 10), isNull);
    });

    test('rejects a page beyond the chapter total', () {
      expect(ReadingProgress.tryCreate(page: 11, maxPage: 10), isNull);
      expect(ReadingProgress.tryCreate(page: 25, maxPage: 10), isNull);
    });

    test('computes a fraction for valid pages', () {
      expect(ReadingProgress.tryCreate(page: 1, maxPage: 10)?.fraction, 0.1);
      expect(ReadingProgress.tryCreate(page: 4, maxPage: 10)?.fraction, 0.4);
      expect(ReadingProgress.tryCreate(page: 10, maxPage: 10)?.fraction, 1.0);
      expect(ReadingProgress.tryCreate(page: 1, maxPage: 1)?.fraction, 1.0);
    });
  });

  group('RecentComicCardData.semanticsLabel', () {
    test('joins non-empty parts', () {
      expect(
        _fakeData.semanticsLabel(prefix: 'Continue'),
        'Continue, Demo Comic, Chapter 3 - Page 8, Demo Source',
      );
    });

    test('skips missing and empty parts', () {
      const data = RecentComicCardData(title: 'Demo Comic', detailLine: '');
      expect(data.semanticsLabel(), 'Demo Comic');
    });

    test('includes the progress label only with valid progress', () {
      final withProgress = RecentComicCardData(
        title: 'Demo Comic',
        progress: ReadingProgress.tryCreate(page: 4, maxPage: 10),
        progressLabel: '4 / 10',
      );
      const withoutProgress = RecentComicCardData(
        title: 'Demo Comic',
        progressLabel: '4 / 0',
      );
      expect(withProgress.semanticsLabel(), 'Demo Comic, 4 / 10');
      expect(withoutProgress.semanticsLabel(), 'Demo Comic');
    });
  });

  group('RecentComicCard', () {
    testWidgets('renders supplied data', (tester) async {
      await tester.pumpWidget(harness(const RecentComicCard(data: _fakeData)));
      expect(find.text('Demo Comic'), findsOneWidget);
      expect(find.text('Chapter 3 - Page 8'), findsOneWidget);
      expect(find.text('Demo Source'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('optional lines and progress are hidden when absent', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(const RecentComicCard(data: RecentComicCardData(title: 'T'))),
      );
      expect(find.text('T'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows progress only when valid', (tester) async {
      await tester.pumpWidget(
        harness(
          RecentComicCard(
            data: RecentComicCardData(
              title: 'Demo Comic',
              progress: ReadingProgress.tryCreate(page: 4, maxPage: 10),
              progressLabel: '4 / 10',
            ),
          ),
        ),
      );
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 0.4);
      expect(find.text('4 / 10'), findsOneWidget);

      // Invalid totals: no bar and no label, even if a label is supplied.
      await tester.pumpWidget(
        harness(
          RecentComicCard(
            data: RecentComicCardData(
              title: 'Demo Comic',
              progress: ReadingProgress.tryCreate(page: 4, maxPage: 0),
              progressLabel: '4 / 0',
            ),
          ),
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('4 / 0'), findsNothing);

      // Page beyond the chapter total: also no bar and no label.
      await tester.pumpWidget(
        harness(
          RecentComicCard(
            data: RecentComicCardData(
              title: 'Demo Comic',
              progress: ReadingProgress.tryCreate(page: 25, maxPage: 10),
              progressLabel: '25 / 10',
            ),
          ),
        ),
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('25 / 10'), findsNothing);
    });

    testWidgets('missing cover shows the placeholder', (tester) async {
      await tester.pumpWidget(harness(const RecentComicCard(data: _fakeData)));
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('broken cover falls back to the placeholder', (tester) async {
      await tester.pumpWidget(
        harness(
          RecentComicCard(
            data: RecentComicCardData(
              title: 'Demo Comic',
              cover: _BrokenImageProvider(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading cover shows the placeholder', (tester) async {
      await tester.pumpWidget(
        harness(
          RecentComicCard(
            data: RecentComicCardData(
              title: 'Demo Comic',
              cover: _PendingImageProvider(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);
    });

    testWidgets('onTap and onAction are independent', (tester) async {
      var taps = 0;
      var actions = 0;
      await tester.pumpWidget(
        harness(
          RecentComicCard(
            data: _fakeData,
            onTap: () => taps++,
            actionLabel: 'Resume',
            onAction: () => actions++,
          ),
        ),
      );
      await tester.tap(find.text('Demo Comic'));
      expect((taps, actions), (1, 0));
      await tester.tap(find.text('Resume'));
      expect((taps, actions), (1, 1));
    });

    testWidgets('long action label: no overflow at 2x text', (tester) async {
      await tester.pumpWidget(
        harness(
          RecentComicCard(
            data: _fakeData,
            actionLabel: '接續上次閱讀的章節與頁面位置',
            onAction: () {},
          ),
          textScale: 2.0,
          width: 240,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('action needs both label and callback', (tester) async {
      await tester.pumpWidget(
        harness(const RecentComicCard(data: _fakeData, actionLabel: 'Resume')),
      );
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('card without onTap does not crash on tap', (tester) async {
      await tester.pumpWidget(harness(const RecentComicCard(data: _fakeData)));
      await tester.tap(find.text('Demo Comic'));
      expect(tester.takeException(), isNull);
    });

    for (final brightness in Brightness.values) {
      testWidgets('uses ColorScheme roles ($brightness)', (tester) async {
        await tester.pumpWidget(
          harness(
            const RecentComicCard(data: _fakeData),
            brightness: brightness,
          ),
        );
        final scheme = Theme.of(
          tester.element(find.byType(RecentComicCard)),
        ).colorScheme;
        final material = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(RecentComicCard),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(material.color, scheme.surfaceContainerHigh);
      });
    }

    for (final scale in [1.0, 1.5, 2.0]) {
      for (final width in [320.0, 360.0, 600.0]) {
        testWidgets('no overflow at ${scale}x text, ${width}dp wide', (
          tester,
        ) async {
          await tester.pumpWidget(
            harness(
              RecentComicCard(
                data: RecentComicCardData(
                  title: 'A very long comic title ' * 6,
                  detailLine: 'Group 2 - Chapter 12 - Page 8 ' * 3,
                  sourceLabel: 'A long comic source name ' * 3,
                  progress: ReadingProgress.tryCreate(page: 8, maxPage: 20),
                  progressLabel: 'Page 8 / 20 in this chapter',
                ),
                onTap: () {},
                actionLabel: 'Resume',
                onAction: () {},
              ),
              textScale: scale,
              width: width,
            ),
          );
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('exposes one labeled button with a tap action', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          RecentComicCard(
            data: _fakeData,
            onTap: () {},
            semanticsPrefix: 'Continue',
          ),
        ),
      );
      final finder = find.bySemanticsLabel(
        'Continue, Demo Comic, Chapter 3 - Page 8, Demo Source',
      );
      expect(finder, findsOneWidget);
      final data = tester.getSemantics(finder).getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(
        tester.getSemantics(finder),
        isSemantics(
          label: 'Continue, Demo Comic, Chapter 3 - Page 8, Demo Source',
          isButton: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('is not exposed as tappable without onTap', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(harness(const RecentComicCard(data: _fakeData)));
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Demo Comic')),
      );
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      expect(node, isSemantics(isButton: false, hasTapAction: false));
      handle.dispose();
    });

    for (final brightness in Brightness.values) {
      testWidgets('meets tap target and label guidelines ($brightness)', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          harness(
            RecentComicCard(
              data: _fakeData,
              onTap: () {},
              actionLabel: 'Resume',
              onAction: () {},
            ),
            brightness: brightness,
          ),
        );
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });

      testWidgets('meets text contrast guideline ($brightness)', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          harness(
            RecentComicCard(
              data: RecentComicCardData(
                title: 'Demo Comic',
                detailLine: 'Chapter 3 - Page 8',
                sourceLabel: 'Demo Source',
                progress: ReadingProgress.tryCreate(page: 8, maxPage: 20),
                progressLabel: 'Page 8 / 20',
              ),
              onTap: () {},
              actionLabel: 'Resume',
              onAction: () {},
            ),
            brightness: brightness,
          ),
        );
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });

  group('CoverImage', () {
    testWidgets('uses the supplied size', (tester) async {
      await tester.pumpWidget(
        harness(
          const Align(
            alignment: Alignment.topLeft,
            child: CoverImage(width: 50, height: 70),
          ),
        ),
      );
      expect(tester.getSize(find.byType(CoverImage)), const Size(50, 70));
    });
  });

  group('HomeSectionHeading', () {
    testWidgets('renders title, count and action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        harness(
          HomeSectionHeading(
            title: 'History',
            count: 12,
            actionLabel: 'View all',
            onAction: () => taps++,
          ),
        ),
      );
      expect(find.text('History'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      await tester.tap(find.text('View all'));
      expect(taps, 1);
    });

    testWidgets('title is a semantics header', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(const HomeSectionHeading(title: 'History')),
      );
      expect(find.bySemanticsLabel('History'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('hides optional parts', (tester) async {
      await tester.pumpWidget(
        harness(
          const HomeSectionHeading(title: 'History', actionLabel: 'View all'),
        ),
      );
      expect(find.text('View all'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('action meets the tap target guideline', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          HomeSectionHeading(
            title: 'History',
            actionLabel: 'View all',
            onAction: () {},
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('no overflow at 2x text on a narrow width', (tester) async {
      await tester.pumpWidget(
        harness(
          HomeSectionHeading(
            title: 'A rather long section title',
            count: 123,
            actionLabel: 'View all',
            onAction: () {},
          ),
          textScale: 2.0,
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    for (final scale in [1.0, 2.0]) {
      for (final width in [240.0, 320.0]) {
        testWidgets('long action label: no overflow at ${scale}x, ${width}dp', (
          tester,
        ) async {
          var taps = 0;
          await tester.pumpWidget(
            harness(
              HomeSectionHeading(
                title: '最近閱讀的漫畫與繼續閱讀',
                count: 123,
                actionLabel: '查看全部歷史閱讀紀錄與更多內容',
                onAction: () => taps++,
              ),
              textScale: scale,
              width: width,
            ),
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byType(TextButton));
          expect(taps, 1);
        });
      }
    }
  });

  group('HomeEmptyState', () {
    testWidgets('renders message and action', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        harness(
          HomeEmptyState(
            icon: Icons.explore_outlined,
            message: 'Nothing read yet',
            actionLabel: 'Explore',
            onAction: () => taps++,
          ),
        ),
      );
      expect(find.text('Nothing read yet'), findsOneWidget);
      await tester.tap(find.text('Explore'));
      expect(taps, 1);
    });

    testWidgets('message only has no button', (tester) async {
      await tester.pumpWidget(
        harness(
          const HomeEmptyState(
            icon: Icons.explore_outlined,
            message: 'Nothing read yet',
          ),
        ),
      );
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('no overflow at 2x text', (tester) async {
      await tester.pumpWidget(
        harness(
          HomeEmptyState(
            icon: Icons.explore_outlined,
            message: 'Nothing read yet. Pick a comic to start. ' * 3,
            actionLabel: 'Explore',
            onAction: () {},
          ),
          textScale: 2.0,
          width: 320,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('long CTA label: no overflow at 2x text', (tester) async {
      await tester.pumpWidget(
        harness(
          HomeEmptyState(
            icon: Icons.explore_outlined,
            message: '尚無閱讀紀錄',
            actionLabel: '前往探索頁面開始尋找想看的漫畫',
            onAction: () {},
          ),
          textScale: 2.0,
          width: 240,
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('action meets the tap target guideline', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          HomeEmptyState(
            icon: Icons.explore_outlined,
            message: 'Nothing read yet',
            actionLabel: 'Explore',
            onAction: () {},
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('HomeCardPlaceholder', () {
    testWidgets('has the default footprint', (tester) async {
      await tester.pumpWidget(harness(const HomeCardPlaceholder()));
      expect(tester.getSize(find.byType(HomeCardPlaceholder)).height, 168);
    });

    testWidgets('exposes a loading label when supplied', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(const HomeCardPlaceholder(semanticsLabel: 'Loading')),
      );
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('is silent without a label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(harness(const HomeCardPlaceholder()));
      expect(find.bySemanticsLabel('Loading'), findsNothing);
      handle.dispose();
    });
  });
}
