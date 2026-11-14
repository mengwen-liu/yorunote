import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/pages/yorunote_video_page.dart';

const channel = MethodChannel('yorunote/embedded_video');

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> showEntry(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: const Scaffold(body: YorunoteVideoEntry()),
    ),
  );

  testWidgets('requests the native Activity once while the reply is pending', (
    tester,
  ) async {
    var opens = 0;
    final reply = Completer<String>();
    messenger.setMockMethodCallHandler(channel, (call) {
      expect(call.method, 'open');
      expect(call.arguments, isNull);
      opens++;
      return reply.future;
    });
    await showEntry(tester);
    await tester.tap(find.text('Videos'));
    await tester.pump();
    await tester.tap(find.text('Videos'));
    expect(opens, 1);
    reply.complete('launch_accepted');
    await tester.pumpAndSettle();
    expect(find.text('Videos'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('reports native initialization failure without routing', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'initialization_failed');
    });
    await showEntry(tester);
    await tester.tap(find.text('Videos'));
    await tester.pumpAndSettle();
    expect(find.text('Could not open native videos.'), findsOneWidget);
    expect(find.text('Videos'), findsOneWidget);
  });

  testWidgets('handles a missing Android plugin', (tester) async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw MissingPluginException();
    });
    await showEntry(tester);
    await tester.tap(find.text('Videos'));
    await tester.pumpAndSettle();
    expect(find.text('Could not open native videos.'), findsOneWidget);
  });

  testWidgets('a native duplicate response keeps the Flutter route', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'already_open');
    });
    await showEntry(tester);
    await tester.tap(find.text('Videos'));
    await tester.pumpAndSettle();
    expect(find.text('Videos'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}
