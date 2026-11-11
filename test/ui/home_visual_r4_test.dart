import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/components/components.dart';
import 'package:venera/components/home_widgets.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/pages/home_page.dart';
import 'package:venera/utils/translations.dart';

const syntheticSources = ['Alpha', 'Beta', 'Gamma', 'Delta', 'Epsilon'];
const syntheticTitles = [
  '夜航',
  '走進沒有盡頭的藍色圖書館',
  'The Quiet Geometry of an Endless Afternoon',
  '合成閱讀樣本 4',
  'Synthetic shelf 5',
  'Synthetic shelf 6',
];
const syntheticStatistics = ImageFavoritesComputed(
  [TextWithCount('fixture:geometry', 7), TextWithCount('fixture:night', 3)],
  [TextWithCount('Synthetic Author', 5)],
  [TextWithCount('Synthetic Comic', 4)],
  9,
);

// Original design artwork is geometric. This Flutter painter reproduces its
// geometry for both R3 and R4 fixtures, never an image of the proposed UI.
class EditorialCover extends StatelessWidget {
  const EditorialCover(this.index, {super.key});
  final int index;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: CustomPaint(painter: _CoverPainter(index)),
  );
}

class _CoverPainter extends CustomPainter {
  const _CoverPainter(this.index);
  final int index;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 112, size.height / 168);
    const backgrounds = [
      Color(0xff283e55),
      Color(0xffc3c9bd),
      Color(0xffb4abbc),
    ];
    const foregrounds = [
      Color(0xffe2ddd0),
      Color(0xfff3ead8),
      Color(0xffe9dcca),
    ];
    final i = index % 3;
    final bg = backgrounds[i], fg = foregrounds[i];
    canvas.drawRect(const Rect.fromLTWH(0, 0, 112, 168), Paint()..color = bg);
    if (i == 0) {
      canvas.drawCircle(
        const Offset(80, 57),
        33,
        Paint()..color = const Color(0xffa8c8dd),
      );
      canvas.drawPath(
        Path()
          ..moveTo(-10, 150)
          ..lineTo(68, 72)
          ..lineTo(122, 152)
          ..lineTo(122, 168)
          ..lineTo(0, 168)
          ..close(),
        Paint()..color = fg,
      );
      canvas.drawPath(
        Path()
          ..moveTo(-5, 154)
          ..lineTo(68, 99)
          ..lineTo(128, 159),
        Paint()
          ..color = bg
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    } else if (i == 1) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          const Rect.fromLTWH(18, 26, 76, 109),
          topLeft: const Radius.circular(38),
          topRight: const Radius.circular(38),
        ),
        Paint()..color = const Color(0xff37594d),
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          const Rect.fromLTWH(35, 48, 42, 86),
          topLeft: const Radius.circular(21),
          topRight: const Radius.circular(21),
        ),
        Paint()..color = bg,
      );
      canvas.drawCircle(const Offset(56, 91), 15, Paint()..color = fg);
    } else {
      canvas.drawCircle(const Offset(84, 46), 34, Paint()..color = fg);
      canvas.drawPath(
        Path()
          ..moveTo(0, 113)
          ..lineTo(112, 43)
          ..lineTo(112, 118)
          ..lineTo(0, 168)
          ..close(),
        Paint()..color = const Color(0xff5a4863),
      );
      canvas.drawPath(
        Path()
          ..moveTo(0, 125)
          ..lineTo(112, 55)
          ..moveTo(0, 142)
          ..lineTo(112, 72),
        Paint()
          ..color = bg
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.drawRect(const Rect.fromLTWH(10, 145, 92, 13), Paint()..color = bg);
    void label(String text, Offset offset, double fontSize, double spacing) {
      final p = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'VisualFixture',
            fontSize: fontSize,
            letterSpacing: spacing,
            color: fg,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(canvas, offset);
      p.dispose();
    }

    label('NIGHT / STUDIES', const Offset(11, 9), 6, 1.3);
    label('VOLUME / 0${index + 1}', const Offset(12, 145), 7, 2);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CoverPainter oldDelegate) => oldDelegate.index != index;
}

class EditorialFixture extends StatefulWidget {
  const EditorialFixture({
    super.key,
    this.populated = true,
    this.sync = 'disabled',
    this.onAction,
    this.missingCover = false,
    this.designFixture = false,
  });
  final bool populated, missingCover;
  final bool designFixture;
  final String sync;
  final ValueChanged<String>? onAction;
  @override
  State<EditorialFixture> createState() => _EditorialFixtureState();
}

class _EditorialFixtureState extends State<EditorialFixture> {
  int displayType = 0;
  void action(String name) => widget.onAction?.call(name);
  Widget shelf(BuildContext context) => SizedBox(
    height: HomeCoverCard.shelfHeight(context),
    child: ListView.separated(
      key: const PageStorageKey('fixture-history-shelf'),
      scrollDirection: Axis.horizontal,
      itemCount: syntheticTitles.length,
      separatorBuilder: (_, _) => const SizedBox(width: 16),
      itemBuilder: (_, i) => HomeCoverCard(
        key: ValueKey('fixture-book-$i'),
        title: syntheticTitles[i],
        cover: widget.missingCover ? const CoverImage() : EditorialCover(i),
        onTap: () => action('comic-$i'),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => CustomScrollView(
    key: const ValueKey('editorial-scroll'),
    slivers: [
      SliverToBoxAdapter(
        child: HomeSearchEntry(
          label: 'Search'.tl,
          onTap: () => action('search'),
        ),
      ),
      SliverToBoxAdapter(
        child: HomeHistorySection(
          count: widget.populated ? 24 : 0,
          onViewAll: () => action('history'),
          onSearch: () => action('search'),
          recentComics: widget.populated ? shelf(context) : null,
        ),
      ),
      SliverToBoxAdapter(
        child: HomeFollowUpdatesRow(
          configured: widget.populated && !widget.designFixture,
          count: widget.populated && !widget.designFixture ? 7 : 0,
          title: 'Follow Updates'.tl,
          status: widget.populated && !widget.designFixture
              ? '@c updates'.tlParams({'c': 7})
              : 'Choose a folder to follow updates.'.tl,
          actionLabel: 'View'.tl,
          onView: () => action('follow'),
        ),
      ),
      SliverToBoxAdapter(
        child: HomeLibraryTools(
          source: HomeSourceSection(
            names: widget.populated ? syntheticSources : const [],
            onManage: () => action('source'),
          ),
          favorites: HomeLibraryTool(
            title: 'Image Favorites'.tl,
            icon: Icons.collections_outlined,
            count: widget.populated && !widget.designFixture ? 9 : null,
            actionLabel: 'View'.tl,
            onAction: () => action('favorites'),
          ),
          statistics: widget.populated && !widget.designFixture
              ? HomeImageFavoritesStatistics(
                  computed: syntheticStatistics,
                  displayType: displayType,
                  onSelect: (type) {
                    setState(() => displayType = type);
                    action('type-$type');
                  },
                  onKeyword: (keyword) => action('keyword-$keyword'),
                )
              : null,
        ),
      ),
      SliverToBoxAdapter(
        child: HomeLocalSection(
          count: widget.populated && !widget.designFixture ? 3 : 0,
          onOpen: () => action('local'),
          onImport: () => action('import'),
          recentComics: widget.populated && !widget.designFixture
              ? shelf(context)
              : null,
          downloadingAction: widget.populated && !widget.designFixture
              ? OutlinedButton(
                  onPressed: () => action('downloads'),
                  child: const Text('1 Tasks'),
                )
              : null,
        ),
      ),
      if (widget.sync != 'disabled')
        SliverToBoxAdapter(
          child: HomeSyncSection(
            title: (widget.sync == 'busy' ? 'Syncing Data' : 'Sync Data').tl,
            busy: widget.sync == 'busy',
            uploadLabel: 'Upload'.tl,
            downloadLabel: 'Download'.tl,
            onUpload: () => action('upload'),
            onDownload: () => action('download'),
            errorLabel: widget.sync == 'error' ? 'Error'.tl : null,
            onError: () => action('error'),
          ),
        ),
      const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
    ],
  );
}

Widget fixtureApp({
  required Widget child,
  Brightness brightness = Brightness.dark,
  double scale = 1,
  String language = 'zh-TW',
  GlobalKey? boundary,
  bool shell = false,
  bool designPalette = false,
}) {
  final seeded = ColorScheme.fromSeed(
    seedColor: const Color(0xff789bb9),
    brightness: brightness,
  );
  // Only synthetic comparison fixtures map the design colors. Production uses
  // the unchanged app Theme/Dynamic Color. Both seeded and design-mapped views
  // are captured and explicitly distinguished in the evidence report.
  final scheme = !designPalette
      ? seeded
      : seeded.copyWith(
          surface: brightness == Brightness.dark
              ? const Color(0xff101820)
              : const Color(0xfff4f6f8),
          surfaceContainerHigh: brightness == Brightness.dark
              ? const Color(0xff1c2733)
              : Colors.white,
          primary: brightness == Brightness.dark
              ? const Color(0xffb0d4ff)
              : const Color(0xff315b7d),
        );
  return MaterialApp(
    theme: ThemeData(
      fontFamily: Platform.environment['VENERA_VISUAL_FONT'] == null
          ? null
          : 'VisualFixture',
      colorScheme: scheme,
    ),
    locale: language == 'zh-TW'
        ? const Locale('zh', 'TW')
        : const Locale('en', 'US'),
    supportedLocales: const [Locale('zh', 'TW'), Locale('en', 'US')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        padding: const EdgeInsets.only(top: 24, bottom: 20),
        viewPadding: const EdgeInsets.only(top: 24, bottom: 20),
      ),
      child: child!,
    ),
    home: RepaintBoundary(
      key: boundary,
      child: Scaffold(
        body: shell
            ? NaviPane(
                observer: NaviObserver(),
                navigatorKey: GlobalKey<NavigatorState>(),
                paneItems: [
                  PaneItemEntry(
                    label: 'Home'.tl,
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                  ),
                  PaneItemEntry(
                    label: 'Favorites'.tl,
                    icon: Icons.local_activity_outlined,
                    activeIcon: Icons.local_activity,
                  ),
                  PaneItemEntry(
                    label: 'Explore'.tl,
                    icon: Icons.explore_outlined,
                    activeIcon: Icons.explore,
                  ),
                  PaneItemEntry(
                    label: 'Categories'.tl,
                    icon: Icons.category_outlined,
                    activeIcon: Icons.category,
                  ),
                ],
                paneActions: [
                  PaneActionEntry(
                    label: 'Settings'.tl,
                    icon: Icons.settings,
                    onTap: () {},
                  ),
                ],
                pageBuilder: (_) => child,
              )
            : SafeArea(child: child),
      ),
    ),
  );
}

void viewport(WidgetTester tester, double width, {double height = 1000}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['VENERA_VISUAL_DIR'];
  if (directory == null) return;
  await tester.pump(const Duration(milliseconds: 32));
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$directory/$name.png');
      if (file.existsSync()) throw StateError('No capture overwrite');
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
    final font = Platform.environment['VENERA_VISUAL_FONT'];
    if (font != null) {
      await (FontLoader(
        'VisualFixture',
      )..addFont(File(font).readAsBytes().then(ByteData.sublistView))).load();
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

  for (final language in ['zh-TW', 'en-US']) {
    for (final brightness in Brightness.values) {
      for (final width in [360.0, 393.0, 600.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          for (final populated in [false, true]) {
            testWidgets(
              'R4 matrix $language ${brightness.name} $width $scale populated=$populated',
              (tester) async {
                viewport(tester, width);
                appdata.settings['language'] = language;
                final semantics = tester.ensureSemantics();
                await tester.pumpWidget(
                  fixtureApp(
                    language: language,
                    brightness: brightness,
                    scale: scale,
                    child: EditorialFixture(
                      populated: populated,
                      missingCover: populated,
                      sync: populated ? 'error' : 'disabled',
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                if (populated) {
                  final rect = tester.getRect(
                    find.byKey(const ValueKey('home-portrait-cover')).first,
                  );
                  expect(rect.width / rect.height, closeTo(2 / 3, .001));
                  expect(
                    find.bySemanticsLabel(syntheticTitles[0]),
                    findsWidgets,
                  );
                }
                for (var scroll = 0; scroll < 7; scroll++) {
                  await expectLater(
                    tester,
                    meetsGuideline(androidTapTargetGuideline),
                  );
                  await expectLater(
                    tester,
                    meetsGuideline(labeledTapTargetGuideline),
                  );
                  await tester.drag(
                    find.byKey(const ValueKey('editorial-scroll')),
                    const Offset(0, -600),
                  );
                  await tester.pumpAndSettle();
                  expect(tester.takeException(), isNull);
                }
                final imports = find.widgetWithText(
                  FilledButton,
                  'Import Comics'.tl,
                );
                await tester.ensureVisible(imports);
                expect(
                  tester.getSize(imports).height,
                  greaterThanOrEqualTo(48),
                );
                semantics.dispose();
              },
            );
          }
        }
      }
    }
  }

  testWidgets('R4 actual statistics selectors and exact keyword callbacks', (
    tester,
  ) async {
    viewport(tester, 360, height: 1400);
    final actions = <String>[];
    await tester.pumpWidget(
      fixtureApp(
        scale: 2,
        child: EditorialFixture(sync: 'error', onAction: actions.add),
      ),
    );
    await tester.pumpAndSettle();
    for (final (label, keyword) in [
      ('Tags', 'geometry'),
      ('Authors', 'Synthetic Author'),
      ('Comics', 'Synthetic Comic'),
    ]) {
      final tab = find.widgetWithText(HomeFavoriteTypeButton, label.tl);
      await tester.scrollUntilVisible(
        tab,
        350,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('editorial-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(tab);
      await tester.pumpAndSettle();
      final entry = find.text(keyword);
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();
    }
    expect(actions, [
      'type-0',
      'keyword-fixture:geometry',
      'type-1',
      'keyword-Synthetic Author',
      'type-2',
      'keyword-Synthetic Comic',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('R4 all entry callbacks reachable by scrolling', (tester) async {
    viewport(tester, 393);
    final actions = <String>[];
    await tester.pumpWidget(
      fixtureApp(
        child: EditorialFixture(sync: 'error', onAction: actions.add),
      ),
    );
    await tester.pumpAndSettle();
    final entries = [
      find.byType(HomeSearchEntry),
      find.text('View more'.tl),
      find.byKey(const ValueKey('fixture-book-0')).first,
      find.descendant(
        of: find.byType(HomeFollowUpdatesRow),
        matching: find.text('View'.tl),
      ),
      find.text('Manage'.tl),
      find.descendant(
        of: find.byType(HomeLibraryTool),
        matching: find.text('View'.tl),
      ),
      find.descendant(
        of: find.byType(HomeLocalSection),
        matching: find.text('View'.tl),
      ),
      find.text('Import Comics'.tl),
      find.text('1 Tasks'),
      find.byTooltip('Upload'.tl),
      find.byTooltip('Download'.tl),
      find.text('Error'.tl),
    ];
    for (final finder in entries) {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
    }
    expect(actions, [
      'search',
      'history',
      'comic-0',
      'follow',
      'source',
      'favorites',
      'local',
      'import',
      'downloads',
      'upload',
      'download',
      'error',
    ]);
    expect(tester.takeException(), isNull);
  });

  for (final state in ['disabled', 'idle', 'busy', 'error']) {
    testWidgets('R4 sync $state', (tester) async {
      viewport(tester, 393, height: 1800);
      await tester.pumpWidget(
        fixtureApp(child: EditorialFixture(populated: false, sync: state)),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        find.byType(HomeSyncSection),
        state == 'disabled' ? findsNothing : findsOneWidget,
      );
      expect(
        find.byType(CircularProgressIndicator),
        state == 'busy' ? findsOneWidget : findsNothing,
      );
      expect(
        find.byTooltip('Upload'.tl),
        ['idle', 'error'].contains(state) ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Error'.tl),
        state == 'error' ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('R4 two-column tools fall back and long titles remain semantic', (
    tester,
  ) async {
    viewport(tester, 393, height: 1600);
    final semantics = tester.ensureSemantics();
    for (final scale in [1.0, 1.5, 2.0]) {
      await tester.pumpWidget(
        fixtureApp(scale: scale, child: const EditorialFixture()),
      );
      await tester.pumpAndSettle();
      final tools = find.byType(HomeLibraryTool);
      final source = tester.getRect(tools.at(0));
      final favorites = tester.getRect(tools.at(1));
      if (scale == 1) {
        expect(source.top, favorites.top);
        expect(source.right, lessThan(favorites.left));
      } else {
        expect(favorites.top, greaterThan(source.bottom));
      }
      expect(find.bySemanticsLabel(syntheticTitles[1]), findsWidgets);
      final title = tester.widget<Text>(find.text(syntheticTitles[1]).first);
      expect(title.maxLines, 2);
      expect(title.style!.fontSize, greaterThanOrEqualTo(13));
      expect(tester.takeException(), isNull);
    }
    semantics.dispose();
  });

  for (final brightness in Brightness.values) {
    for (final width in [360.0, 393.0]) {
      testWidgets('R4 capture ${brightness.name} ${width.toInt()}', (
        tester,
      ) async {
        viewport(tester, width, height: 850);
        final key = GlobalKey();
        await tester.pumpWidget(
          fixtureApp(
            brightness: brightness,
            boundary: key,
            shell: true,
            child: const EditorialFixture(designFixture: true, sync: 'idle'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(NaviPane), findsOneWidget);
        expect(find.byTooltip('Settings'.tl), findsOneWidget);
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          key,
          'R4_A_FLUTTER_${brightness.name.toUpperCase()}_${width.toInt()}',
        );
        final out = Platform.environment['VENERA_VISUAL_DIR'];
        if (out != null) {
          final history = tester.getRect(find.byType(HomeHistorySection));
          final follow = tester.getRect(find.byType(HomeFollowUpdatesRow));
          final tool = tester.getRect(find.byType(HomeLibraryTools));
          final data = {
            'viewport': [width, 850],
            'topInset': 24,
            'bottomInset': 20,
            'history': [history.top, history.bottom],
            'follow': [follow.top, follow.bottom],
            'tools': [tool.top, tool.bottom],
            'source':
                'actual Flutter widgets with unchanged NaviPane + synthetic data; seeded ColorScheme',
          };
          File(
            '$out/MEASUREMENTS_${brightness.name}_${width.toInt()}.json',
          ).writeAsStringSync(jsonEncode(data));
        }
      });
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('R4 capture full content ${brightness.name}', (tester) async {
      viewport(tester, 393, height: 850);
      final key = GlobalKey();
      await tester.pumpWidget(
        fixtureApp(
          boundary: key,
          shell: true,
          brightness: brightness,
          child: const EditorialFixture(designFixture: true, sync: 'idle'),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byKey(const ValueKey('editorial-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      tester.view.physicalSize = Size(
        393,
        850 + scroll.position.maxScrollExtent.ceilToDouble(),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(
        tester,
        key,
        'R4_A_FLUTTER_${brightness.name.toUpperCase()}_393_FULL_CONTENT',
      );
    });
  }
}
