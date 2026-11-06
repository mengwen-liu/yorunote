import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/components/window_frame.dart';
import 'package:venera/components/windows_title_brand.dart';

const _channel = MethodChannel('window_manager');

Widget _app(
  GlobalKey<NavigatorState> navigator, {
  ValueNotifier<ThemeMode>? themeMode,
}) {
  Widget build(ThemeMode mode) => MaterialApp(
    navigatorKey: navigator,
    theme: ThemeData(
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 100),
      ),
    ),
    darkTheme: ThemeData.dark().copyWith(
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 100),
      ),
    ),
    themeMode: mode,
    // Match production: the caption is a sibling of Navigator, outside its Overlay.
    builder: (_, child) => WindowFrame(child!),
    home: const _CounterPage(),
  );
  return themeMode == null
      ? build(ThemeMode.light)
      : ValueListenableBuilder<ThemeMode>(
          valueListenable: themeMode,
          builder: (_, mode, child) => build(mode),
        );
}

Future<void> _hover(WidgetTester tester) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: const Offset(150, 150));
  await mouse.moveTo(tester.getCenter(find.byType(WindowsTitleBrand)));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
  expect(tester.takeException(), isNull);
  expect(find.text('Yorunote', findRichText: true), findsOneWidget);
  await mouse.moveTo(const Offset(200, 150));
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 300));
  expect(find.text('Yorunote', findRichText: true), findsNothing);
  await mouse.removePointer();
}

Future<void> _loaded(WidgetTester tester) async {
  final image = find.descendant(
    of: find.byType(WindowsTitleBrand),
    matching: find.byType(RawImage),
  );
  for (var i = 0; i < 100; i++) {
    if (image.evaluate().isNotEmpty &&
        tester.widget<RawImage>(image).image != null) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  fail('The actual title GIF did not decode');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          _channel,
          (call) async => call.method == 'isMaximized' ? false : null,
        );
    WidgetsBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  testWidgets(
    'real Windows caption decodes and displays its hover tooltip outside Navigator',
    (tester) async {
      await tester.pumpWidget(_app(GlobalKey<NavigatorState>()));
      expect(tester.takeException(), isNull);
      await _loaded(tester);
      expect(
        tester.getSize(find.byType(WindowsTitleBrand)),
        const Size(72, 36),
      );
      await _hover(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !Platform.isWindows,
  );

  testWidgets(
    'caption overlay preserves routes, dialogs and state through theme and size changes',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      final mode = ValueNotifier(ThemeMode.light);
      await tester.pumpWidget(_app(navigator, themeMode: mode));
      expect(tester.takeException(), isNull);
      navigator.currentState!.push<void>(
        MaterialPageRoute<void>(builder: (_) => const _CounterPage()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('increment')).hitTestable());
      await tester.pump();
      expect(find.text('Count 1'), findsOneWidget);
      mode.value = ThemeMode.dark;
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Count 1'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isTrue);
      await _hover(tester);
      showDialog<void>(
        context: navigator.currentContext!,
        builder: (_) => const AlertDialog(content: Text('Caption dialog')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Caption dialog'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Count 1'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Count 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.binding.setSurfaceSize(null);
      mode.dispose();
    },
    skip: !Platform.isWindows,
  );

  testWidgets(
    'hiding and restoring the Windows caption preserves Navigator state and tooltip',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(navigator));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('increment')).hitTestable());
      await tester.pump();
      WindowFrame.of(navigator.currentContext!).setWindowFrame(false);
      await tester.pump();
      expect(find.byType(WindowsTitleBrand), findsNothing);
      expect(find.text('Count 1'), findsOneWidget);
      WindowFrame.of(navigator.currentContext!).setWindowFrame(true);
      await tester.pump();
      expect(find.byType(WindowsTitleBrand), findsOneWidget);
      expect(find.text('Count 1'), findsOneWidget);
      await _hover(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
    skip: !Platform.isWindows,
  );
}

class _CounterPage extends StatefulWidget {
  const _CounterPage();
  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int count = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const ValueKey('increment'),
        onPressed: () => setState(() => count++),
        child: Text('Count $count'),
      ),
    ),
  );
}
