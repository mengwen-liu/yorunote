import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/components/components.dart';
import 'package:venera/components/home_widgets.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/pages/home_page.dart';
import 'package:venera/utils/translations.dart';

Widget harness(Widget child, {double scale = 1, Brightness? brightness}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: brightness ?? Brightness.light,
      ),
    ),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: app!,
    ),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Only load the repository's translations. Never initialize App or a DB.
    await AppTranslation.init();
  });

  setUp(() => appdata.settings['language'] = 'en-US');
  tearDown(() => appdata.settings['language'] = 'system');

  testWidgets('empty history retains history and working search callbacks', (
    tester,
  ) async {
    var history = 0;
    var search = 0;
    await tester.pumpWidget(
      harness(
        HomeHistorySection(
          count: 0,
          onViewAll: () => history++,
          onSearch: () => search++,
        ),
      ),
    );
    expect(find.byType(HomeEmptyState), findsOneWidget);
    expect(find.text('History: 0'), findsOneWidget);
    expect(find.textContaining('Continue'), findsNothing);
    await tester.tap(find.text('Search'));
    await tester.tap(find.text('View more'));
    expect((search, history), (1, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('nonempty history keeps recent comic and history actions', (
    tester,
  ) async {
    var comic = 0;
    var history = 0;
    await tester.pumpWidget(
      harness(
        HomeHistorySection(
          count: 1,
          onViewAll: () => history++,
          onSearch: () => fail('Empty-state search must be hidden'),
          recentComics: TextButton(
            onPressed: () => comic++,
            child: const Text('Synthetic recent comic'),
          ),
        ),
      ),
    );
    expect(find.byType(HomeEmptyState), findsNothing);
    expect(find.text('Search'), findsNothing);
    await tester.tap(find.text('Synthetic recent comic'));
    await tester.tap(find.text('View more'));
    expect((comic, history), (1, 1));
  });

  testWidgets('empty local keeps browse, import and download actions', (
    tester,
  ) async {
    var browse = 0;
    var imports = 0;
    var downloads = 0;
    await tester.pumpWidget(
      harness(
        HomeLocalSection(
          count: 0,
          onOpen: () => browse++,
          onImport: () => imports++,
          downloadingAction: OutlinedButton(
            onPressed: () => downloads++,
            child: const Text('1 Tasks'),
          ),
        ),
      ),
    );
    expect(find.byType(ListView), findsNothing);
    expect(find.text('Local'), findsOneWidget);
    await tester.tap(find.text('View'));
    await tester.tap(find.text('Import Comics'));
    await tester.tap(find.text('1 Tasks'));
    expect((browse, imports, downloads), (1, 1, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('nonempty local still displays supplied recent comics', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        HomeLocalSection(
          count: 1,
          onOpen: () {},
          onImport: () {},
          recentComics: const Text('Synthetic local comic'),
        ),
      ),
    );
    expect(find.text('Synthetic local comic'), findsOneWidget);
    expect(find.text('Import Comics'), findsOneWidget);
  });

  testWidgets('home composition retains all original sections in UX02 order', (
    tester,
  ) async {
    // Inspect composition without mounting storage-backed stateful sections.
    // This avoids App.init(), personal databases, sources and network I/O.
    late List<Widget> sections;
    await tester.pumpWidget(
      harness(
        Builder(
          builder: (context) {
            final home = const HomePage().build(context);
            final scroll = home is SmoothCustomScrollView
                ? home
                : (home as Padding).child! as SmoothCustomScrollView;
            sections = scroll.slivers;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(
      sections.where((w) => w is! SliverPadding).map((w) => '${w.runtimeType}'),
      [
        '_SearchBar',
        '_History',
        'FollowUpdatesWidget',
        'ImageFavorites',
        '_Local',
        '_SyncDataWidget',
      ],
    );
    // R4 groups the original source Widget beside image favorites; its
    // stateful owner remains present rather than being replaced by a fake card.
    expect(
      sections
          .whereType<ImageFavorites>()
          .single
          .leadingTool
          .runtimeType
          .toString(),
      '_ComicSourceWidget',
    );
  });

  for (final language in ['en-US', 'zh-TW']) {
    for (final brightness in Brightness.values) {
      for (final width in [360.0, 393.0]) {
        for (final scale in [1.0, 1.5, 2.0]) {
          testWidgets(
            'empty sections $language $brightness ${width}dp ${scale}x',
            (tester) async {
              appdata.settings['language'] = language;
              tester.view.physicalSize = Size(width, 1200);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final semantics = tester.ensureSemantics();
              var searches = 0;
              var imports = 0;
              await tester.pumpWidget(
                harness(
                  Column(
                    children: [
                      HomeHistorySection(
                        count: 0,
                        onViewAll: () {},
                        onSearch: () => searches++,
                      ),
                      HomeLocalSection(
                        count: 0,
                        onOpen: () {},
                        onImport: () => imports++,
                      ),
                    ],
                  ),
                  scale: scale,
                  brightness: brightness,
                ),
              );
              expect(tester.takeException(), isNull);
              final search = find.widgetWithText(FilledButton, 'Search'.tl);
              final import = find.widgetWithText(
                FilledButton,
                'Import Comics'.tl,
              );
              await tester.ensureVisible(search);
              await tester.tap(search);
              await tester.ensureVisible(import);
              await tester.tap(import);
              expect((searches, imports), (1, 1));
              expect(tester.getSize(search).height, greaterThanOrEqualTo(48));
              expect(tester.getSize(import).height, greaterThanOrEqualTo(48));
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
            },
          );
        }
      }
    }
  }
}
