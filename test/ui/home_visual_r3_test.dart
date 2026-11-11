import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/components/home_widgets.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/pages/follow_updates_page.dart';
import 'package:venera/pages/home_page.dart';
import 'package:venera/utils/translations.dart';

const sources = [
  'Source Alpha',
  'Source Beta',
  'Source Gamma',
  'Source Delta',
  'Source Epsilon',
];

// Entirely synthetic geometric artwork. Never load the App, a DB or a network.
class SyntheticCover extends StatelessWidget {
  const SyntheticCover(this.index, {super.key});
  final int index;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: [
      const Color(0xff35546f),
      const Color(0xff6c586f),
      const Color(0xff47685f),
    ][index % 3],
    child: Stack(
      children: [
        Positioned(
          top: 16,
          right: -16,
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .16),
            ),
          ),
        ),
        Positioned(
          left: 12,
          bottom: 16,
          right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NIGHT / STUDIES',
                style: TextStyle(fontSize: 9, color: Colors.white),
              ),
              Text(
                '0${index + 1}',
                style: const TextStyle(fontSize: 28, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget shelf(BuildContext context) => SizedBox(
  height: HomeCoverCard.shelfHeight(context),
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    itemCount: 6,
    separatorBuilder: (_, _) => const SizedBox(width: 12),
    itemBuilder: (_, i) => HomeCoverCard(
      title: appdata.settings['language'] == 'zh-TW'
          ? '合成閱讀樣本 ${i + 1}'
          : 'Synthetic shelf ${i + 1}',
      cover: SyntheticCover(i),
      onTap: () {},
    ),
  ),
);

// This identical composition is also compiled against byte-backed-up R2 source
// in the evidence folder. The chrome is fixture chrome, not a device capture.
Widget comparisonFixture({
  required Brightness brightness,
  required GlobalKey boundary,
}) => MaterialApp(
  theme: ThemeData(
    fontFamily: 'VisualFixture',
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xff789bb9),
      brightness: brightness,
    ),
  ),
  home: RepaintBoundary(
    key: boundary,
    child: Scaffold(
      appBar: AppBar(
        title: Text('Home'.tl),
        actions: [
          IconButton(
            tooltip: 'Settings'.tl,
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            label: 'Home'.tl,
          ),
          NavigationDestination(
            icon: const Icon(Icons.bookmark_outline),
            label: 'Favorites'.tl,
          ),
          NavigationDestination(
            icon: const Icon(Icons.explore_outlined),
            label: 'Explore'.tl,
          ),
          NavigationDestination(
            icon: const Icon(Icons.category_outlined),
            label: 'Categories'.tl,
          ),
        ],
      ),
      body: Builder(
        builder: (context) => CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: HomeSearchEntry(label: 'Search'.tl, onTap: () {}),
            ),
            SliverToBoxAdapter(
              child: HomeHistorySection(
                count: 181,
                onViewAll: () {},
                onSearch: () {},
                recentComics: shelf(context),
              ),
            ),
            const FollowUpdatesWidget(),
            SliverToBoxAdapter(
              child: HomeSourceSection(names: sources, onManage: () {}),
            ),
            SliverToBoxAdapter(
              child: HomeLocalSection(count: 0, onOpen: () {}, onImport: () {}),
            ),
          ],
        ),
      ),
    ),
  ),
);

void viewport(WidgetTester tester, double width, {double height = 800}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final dir = Platform.environment['VENERA_VISUAL_DIR'];
  if (dir == null) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$dir/$name.png');
      if (file.existsSync()) throw StateError('No evidence overwrite');
      await file.writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await AppTranslation.init();
    final path = Platform.environment['VENERA_VISUAL_FONT'];
    if (path != null) {
      await (FontLoader(
        'VisualFixture',
      )..addFont(File(path).readAsBytes().then(ByteData.sublistView))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  setUp(() {
    appdata.settings['language'] = 'zh-TW';
    appdata.settings['followUpdatesFolder'] = null;
  });
  tearDown(() {
    appdata.settings['language'] = 'system';
  });

  // CAPTURE_TESTS_BEGIN
  for (final brightness in Brightness.values) {
    for (final width in [360.0, 393.0]) {
      testWidgets(
        'R3 identical synthetic render ${brightness.name} ${width}dp',
        (tester) async {
          // Fully detach prior scene layers before capture at another width.
          await tester.pumpWidget(const SizedBox.shrink());
          viewport(tester, width, height: 800);
          final key = GlobalKey();
          await tester.pumpWidget(
            comparisonFixture(brightness: brightness, boundary: key),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await capture(
            tester,
            key,
            'home-${brightness.name}-${width.toInt()}dp',
          );
        },
      );
    }
  }
  // CAPTURE_TESTS_END

  testWidgets('R3 first screen reading and follow-up hierarchy', (
    tester,
  ) async {
    for (final width in [360.0, 393.0]) {
      viewport(tester, width);
      await tester.pumpWidget(
        comparisonFixture(brightness: Brightness.dark, boundary: GlobalKey()),
      );
      await tester.pumpAndSettle();
      final history = tester.getRect(find.byType(HomeHistorySection));
      final follow = tester.getRect(find.byType(HomeFollowUpdatesRow));
      final source = tester.getRect(find.byType(HomeSourceSection));
      // R4 intentionally grows the old 128dp cover into a 2:3, 168dp cover.
      // Preserve a bounded first-screen reading section, and check its actual
      // portrait geometry instead of enforcing the superseded short R3 shelf.
      expect(history.height, greaterThan(280));
      expect(history.height, lessThan(360));
      expect(HomeCoverCard.width / HomeCoverCard.coverHeight, 2 / 3);
      expect(follow.top, greaterThan(history.top));
      expect(follow.bottom, lessThan(600));
      expect(source.top, lessThan(620));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('Continue'), findsNothing);
      expect(find.byType(HomeSurface), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  for (final language in ['en-US', 'zh-TW']) {
    for (final brightness in Brightness.values) {
      for (final width in [360.0, 393.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          testWidgets('R3 tool paths $language $brightness $width $scale', (
            tester,
          ) async {
            viewport(tester, width, height: 1800);
            appdata.settings['language'] = language;
            final semantics = tester.ensureSemantics();
            var follows = 0,
                errors = 0,
                uploads = 0,
                downloads = 0,
                favorites = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(
                    seedColor: Colors.blueGrey,
                    brightness: brightness,
                  ),
                ),
                home: Scaffold(
                  body: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          HomeFollowUpdatesRow(
                            configured: true,
                            count: 12,
                            title: 'Follow Updates'.tl,
                            status: '@c updates'.tlParams({'c': 12}),
                            actionLabel: 'View'.tl,
                            onView: () => follows++,
                          ),
                          HomeToolRow(
                            title: 'Image Favorites'.tl,
                            icon: Icons.collections_outlined,
                            count: 3,
                            actionLabel: 'View'.tl,
                            onAction: () => favorites++,
                          ),
                          HomeSyncSection(
                            title: 'Sync Data'.tl,
                            uploadLabel: 'Upload'.tl,
                            downloadLabel: 'Download'.tl,
                            errorLabel: 'Error'.tl,
                            onError: () => errors++,
                            onUpload: () => uploads++,
                            onDownload: () => downloads++,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
            expect(tester.takeException(), isNull);
            for (final finder in [
              find.text('View'.tl).at(0),
              find.text('View'.tl).at(1),
              find.text('Error'.tl),
              find.byTooltip('Upload'.tl),
              find.byTooltip('Download'.tl),
            ]) {
              await tester.ensureVisible(finder);
              await tester.tap(finder);
            }
            expect(
              [follows, favorites, errors, uploads, downloads],
              [1, 1, 1, 1, 1],
            );
            await expectLater(
              tester,
              meetsGuideline(androidTapTargetGuideline),
            );
            await expectLater(
              tester,
              meetsGuideline(labeledTapTargetGuideline),
            );
            expect(tester.takeException(), isNull);
            semantics.dispose();
          });
        }
      }
    }
  }

  testWidgets(
    'R3 busy sync shows real status without duplicate retry controls',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeSyncSection(
              title: 'Syncing Data',
              busy: true,
              uploadLabel: 'Upload',
              downloadLabel: 'Download',
              onUpload: () {},
              onDownload: () {},
            ),
          ),
        ),
      );
      expect(find.text('Syncing Data'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byTooltip('Upload'), findsNothing);
    },
  );
}
