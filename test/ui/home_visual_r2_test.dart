import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/components/home_widgets.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/global_state.dart';
import 'package:venera/pages/follow_updates_page.dart';
import 'package:venera/pages/home_page.dart';
import 'package:venera/utils/translations.dart';

const _sources = [
  'Source Alpha',
  'Source Beta',
  'Source Gamma',
  'Source Delta',
  'Source Epsilon',
];

Widget _shelf(BuildContext context, {VoidCallback? onTap}) => SizedBox(
  height: HomeCoverCard.shelfHeight(context),
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    itemCount: 6,
    separatorBuilder: (_, _) => const SizedBox(width: 8),
    itemBuilder: (_, i) => HomeCoverCard(
      title: appdata.settings['language'] == 'zh-TW'
          ? '合成閱讀樣本 ${i + 1}'
          : 'Synthetic shelf ${i + 1}',
      cover: const CoverImage(),
      onTap: onTap ?? () {},
    ),
  ),
);

Widget _fixture({
  int history = 181,
  int local = 0,
  List<String> sources = _sources,
  Brightness brightness = Brightness.dark,
  double scale = 1,
  GlobalKey? captureKey,
  bool comparison = false,
  Color seed = Colors.teal,
  VoidCallback? onSearch,
  VoidCallback? onHistory,
  VoidCallback? onComic,
  VoidCallback? onManage,
  VoidCallback? onLocal,
  VoidCallback? onImport,
  VoidCallback? onDownloads,
}) {
  return MaterialApp(
    theme: ThemeData(
      fontFamily: Platform.environment['VENERA_VISUAL_FONT'] == null
          ? null
          : 'VisualFixture',
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      ),
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: RepaintBoundary(
      key: captureKey,
      child: Scaffold(
        body: Builder(
          builder: (context) => CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: HomeSearchEntry(
                  label: 'Search'.tl,
                  onTap: onSearch ?? () {},
                ),
              ),
              SliverToBoxAdapter(
                child: HomeHistorySection(
                  count: history,
                  onViewAll: onHistory ?? () {},
                  onSearch: onSearch ?? () {},
                  recentComics: history == 0
                      ? null
                      : _shelf(context, onTap: onComic),
                ),
              ),
              if (!comparison) ...[
                const FollowUpdatesWidget(),
                SliverToBoxAdapter(
                  child: HomeSourceSection(
                    names: sources,
                    onManage: onManage ?? () {},
                    availableUpdates: sources.isEmpty ? 0 : 2,
                  ),
                ),
              ],
              SliverToBoxAdapter(
                child: HomeLocalSection(
                  count: local,
                  onOpen: onLocal ?? () {},
                  onImport: onImport ?? () {},
                  recentComics: local == 0 ? null : _shelf(context),
                  downloadingAction: onDownloads == null
                      ? null
                      : OutlinedButton(
                          onPressed: onDownloads,
                          child: Text('@a Tasks'.tlParams({'a': 1})),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _viewport(WidgetTester tester, double width, {double height = 1000}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final directory = Platform.environment['VENERA_VISUAL_DIR'];
  if (directory == null) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$directory/$name.png');
      if (file.existsSync()) {
        throw StateError('Refuse to overwrite visual evidence: ${file.path}');
      }
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await AppTranslation.init();
    final fontPath = Platform.environment['VENERA_VISUAL_FONT'];
    if (fontPath != null) {
      final font = FontLoader('VisualFixture')
        ..addFont(File(fontPath).readAsBytes().then(ByteData.sublistView));
      await font.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });
  setUp(() {
    appdata.settings['language'] = 'en-US';
    // The original updates widget returns before reading a DB when unset.
    appdata.settings['followUpdatesFolder'] = null;
  });
  tearDown(() => appdata.settings['language'] = 'system');

  for (final language in ['en-US', 'zh-TW']) {
    for (final brightness in Brightness.values) {
      for (final width in [360.0, 393.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          for (final populated in [false, true]) {
            testWidgets(
              'R2 $language $brightness ${width}dp ${scale}x populated=$populated',
              (tester) async {
                _viewport(tester, width);
                appdata.settings['language'] = language;
                final semantics = tester.ensureSemantics();
                await tester.pumpWidget(
                  _fixture(
                    history: populated ? 181 : 0,
                    local: populated ? 3 : 0,
                    sources: populated ? _sources : const [],
                    brightness: brightness,
                    scale: scale,
                  ),
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                await expectLater(
                  tester,
                  meetsGuideline(androidTapTargetGuideline),
                );
                await expectLater(
                  tester,
                  meetsGuideline(labeledTapTargetGuideline),
                );
                await tester.drag(
                  find.byType(CustomScrollView),
                  const Offset(0, -1500),
                );
                await tester.pumpAndSettle();
                expect(tester.takeException(), isNull);
                final import = find.widgetWithText(
                  FilledButton,
                  'Import Comics'.tl,
                );
                await tester.ensureVisible(import);
                expect(tester.getSize(import).height, greaterThanOrEqualTo(48));
                await expectLater(
                  tester,
                  meetsGuideline(androidTapTargetGuideline),
                );
                await expectLater(
                  tester,
                  meetsGuideline(labeledTapTargetGuideline),
                );
                semantics.dispose();
              },
            );
          }
        }
      }
    }
  }

  testWidgets('every R2 entry dispatches its supplied callback', (
    tester,
  ) async {
    _viewport(tester, 393, height: 1800);
    var search = 0,
        history = 0,
        comic = 0,
        source = 0,
        local = 0,
        imports = 0,
        downloads = 0;
    await tester.pumpWidget(
      _fixture(
        onSearch: () => search++,
        onHistory: () => history++,
        onComic: () => comic++,
        onManage: () => source++,
        onLocal: () => local++,
        onImport: () => imports++,
        onDownloads: () => downloads++,
      ),
    );
    for (final finder in [
      find.byType(HomeSearchEntry),
      find.text('View more'),
      find.text('Synthetic shelf 1'),
      find.text('Manage'),
      find.descendant(
        of: find.byType(HomeLocalSection),
        matching: find.text('View'),
      ),
      find.text('Import Comics'),
      find.text('1 Tasks'),
    ]) {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
    }
    expect(
      [search, history, comic, source, local, imports, downloads],
      [1, 1, 1, 1, 1, 1, 1],
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'source labels have no button or tap semantics; management does',
    (tester) async {
      _viewport(tester, 393, height: 1800);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_fixture());
      expect(
        find.descendant(
          of: find.byType(HomeSourceSection),
          matching: find.text('5'),
        ),
        findsOneWidget,
      );
      // R4 uses the real count instead of concatenating source names. The
      // informational count remains noninteractive; Manage retains its action.
      final node = tester.getSemantics(
        find.descendant(
          of: find.byType(HomeSourceSection),
          matching: find.text('5'),
        ),
      );
      expect(node.getSemanticsData().flagsCollection.isButton, isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      for (final name in _sources) {
        expect(find.textContaining(name), findsNothing);
      }
      expect(node.getSemanticsData().label, contains('5'));
      expect(
        tester
            .getSemantics(find.text('Manage'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.textContaining('Continue'), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets('original follow-up State still receives its global refresh', (
    tester,
  ) async {
    _viewport(tester, 393);
    await tester.pumpWidget(_fixture(history: 0, sources: const []));
    final state = GlobalState.findOrNull<State>('FollowUpdatesWidget');
    expect(state, isNotNull);
    expect(state.runtimeType.toString(), '_FollowUpdatesWidgetState');
    updateFollowUpdatesUI();
    await tester.pump();
    expect(GlobalState.findOrNull<State>('FollowUpdatesWidget'), same(state));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(GlobalState.findOrNull<State>('FollowUpdatesWidget'), isNull);
  });

  testWidgets('long names and titles retain full semantics at 2x', (
    tester,
  ) async {
    _viewport(tester, 360, height: 1600);
    const longTitle =
        '合成測試 Synthetic title with a long descriptive name that should wrap';
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Builder(
              builder: (context) => Column(
                children: [
                  HomeSourceSection(names: const [longTitle], onManage: () {}),
                  SizedBox(
                    height: HomeCoverCard.shelfHeight(context),
                    child: HomeCoverCard(
                      title: longTitle,
                      cover: const CoverImage(),
                      onTap: () {},
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // Only the book displays the long title; sources now display real count.
    expect(find.bySemanticsLabel(longTitle), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(HomeSourceSection),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('presentation follows alternate Material seed colors', (
    tester,
  ) async {
    _viewport(tester, 393);
    for (final seed in [Colors.orange, Colors.green]) {
      await tester.pumpWidget(_fixture(seed: seed));
      final context = tester.element(find.byType(HomeHistorySection));
      final scheme = Theme.of(context).colorScheme;
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(HomeSearchEntry),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, scheme.surfaceContainerHigh);
      expect(tester.takeException(), isNull);
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('synthetic visual evidence ${brightness.name}', (tester) async {
      _viewport(tester, 393, height: 700);
      appdata.settings['language'] = 'zh-TW';
      var key = GlobalKey();
      await tester.pumpWidget(
        _fixture(brightness: brightness, captureKey: key, comparison: true),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _capture(tester, key, 'after-${brightness.name}-synthetic');
      tester.view.physicalSize = const Size(393, 1000);
      key = GlobalKey();
      await tester.pumpWidget(
        _fixture(brightness: brightness, captureKey: key),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _capture(
        tester,
        key,
        'after-${brightness.name}-all-sections-synthetic',
      );
    });
  }
}
