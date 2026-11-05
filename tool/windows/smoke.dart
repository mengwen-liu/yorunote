// Runs the real app and native plugins in a disposable Windows CI profile.
// This entry point is never used for the distributed executable.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/image_provider/cached_image.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/main.dart' as production;
import 'package:venera/network/app_dio.dart';
import 'package:venera/network/download.dart';
import 'package:venera/pages/reader/reader.dart';
import 'package:window_manager/window_manager.dart';

import '../synthetic_source/synthetic_server.dart';

final _checks = <Map<String, Object?>>[];
final _flutterErrors = <String>[];
late Directory _evidence;
late String _phase;

void _require(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> _until(
  bool Function() predicate,
  String message, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final end = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(end)) throw TimeoutException(message, timeout);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

void _record(String name, [Map<String, Object?> detail = const {}]) {
  _checks.add({'check': name, 'passed': true, ...detail});
}

Future<void> _stage(String name) async {
  await WidgetsBinding.instance.endOfFrame;
  final state = File('${_evidence.path}/stage.json');
  await state.writeAsString(jsonEncode({'stage': '$_phase-$name'}));
  final ack = File('${_evidence.path}/ack-$_phase-$name.json');
  await _until(
    ack.existsSync,
    'Windows runner did not acknowledge screenshot checkpoint: $name',
    timeout: const Duration(seconds: 30),
  );
}

List<Widget> _widgets() {
  final result = <Widget>[];
  void visit(Element element) {
    result.add(element.widget);
    element.visitChildren(visit);
  }
  final root = WidgetsBinding.instance.rootElement;
  if (root != null) visit(root);
  return result;
}

bool _hasPageImage() => _widgets().whereType<RawImage>().any(
  (w) => w.image?.width == 600 && w.image?.height == 900,
);

Future<void> _decodeCover(ComicSource source, String id) async {
  final result = await source.loadComicInfo!(id);
  _require(!result.error, 'Cannot load synthetic cover information');
  final stream = CachedImageProvider(
    result.data.cover,
    sourceKey: source.key,
    cid: id,
  ).resolve(ImageConfiguration.empty);
  final done = Completer<ImageInfo>();
  final listener = ImageStreamListener(
    (image, synchronousCall) {
      if (!done.isCompleted) done.complete(image);
    },
    onError: (Object error, StackTrace? stack) {
      if (!done.isCompleted) done.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  try {
    final image = await done.future.timeout(const Duration(seconds: 30));
    _require(image.image.width == 240 && image.image.height == 320,
        'Decoded cover has wrong dimensions');
  } finally {
    stream.removeListener(listener);
  }
}

Future<void> _openOnline(ComicSource source) async {
  unawaited(App.rootNavigatorKey.currentState!.push<void>(
    MaterialPageRoute<void>(
      builder: (_) => ReaderWithLoading(id: 'c03', sourceKey: source.key),
    ),
  ));
  await _until(_hasPageImage, 'Reader did not render the synthetic page');
  _record('online_reader_decoded_600x900');
  HardwareKeyboard.instance.handleKeyEvent(const KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.arrowRight,
    logicalKey: LogicalKeyboardKey.arrowRight,
    timeStamp: Duration(milliseconds: 1),
  ));
  HardwareKeyboard.instance.handleKeyEvent(const KeyUpEvent(
    physicalKey: PhysicalKeyboardKey.arrowRight,
    logicalKey: LogicalKeyboardKey.arrowRight,
    timeStamp: Duration(milliseconds: 2),
  ));
  final type = ComicType.fromKey(source.key);
  await _until(
    () => HistoryManager().find('c03', type)?.page == 2,
    'Right-arrow key did not persist reading page 2',
  );
  _record('keyboard_turn_and_sqlite_history_page_2');
  await _stage('reader-page2');
  App.rootNavigatorKey.currentState!.pop();
  await _until(
    () => !_widgets().any((w) => w is Reader),
    'Reader route did not close',
  );
}

Future<void> _openOffline(LocalComic local) async {
  local.read();
  await _until(_hasPageImage, 'Downloaded comic did not render offline');
  _record('offline_reader_decoded_600x900');
  await _stage('offline-reader');
  App.rootNavigatorKey.currentState!.pop();
  await _until(
    () => !_widgets().any((w) => w is Reader),
    'Offline reader did not close',
  );
}

Future<void> _seed() async {
  appdata.settings['language'] = 'zh-TW';
  appdata.settings['theme_mode'] = 'light';
  appdata.settings['readerMode'] = 'galleryLeftToRight';
  appdata.settings['enableClockAndBatteryInfoInReader'] = false;
  App.forceRebuild();
  await _stage('home-zh-TW');
  _require(_widgets().whereType<MaterialApp>().any(
    (w) => w.title == 'Yorunote' && w.locale?.countryCode == 'TW',
  ), 'App title or Traditional Chinese locale was not applied');
  _require(_widgets().whereType<Text>().any((w) => w.data == 'Yorunote'),
      'Custom Windows title bar still lacks the Yorunote name');
  _record('traditional_chinese_home_and_title');

  final template = await File(
    'tool/synthetic_source/yorunote_synthetic_source.js',
  ).readAsString();
  final server = SyntheticServer(sourceTemplate: template);
  await server.start();
  var stopped = false;
  try {
    final response = await AppDio().get<String>(
      '${server.baseUrl}/source.js',
      options: Options(responseType: ResponseType.plain),
    );
    _require(response.statusCode == 200, 'Source download failed');
    final source = await ComicSourceParser().createAndParse(
      response.data!, 'yorunote_windows_acceptance.js',
    );
    ComicSourceManager().add(source);
    final page = await source.explorePages.single.loadPage!(1);
    _require(!page.error && page.data.length == 20,
        'QuickJS synthetic source did not return 20 comics');
    _record('native_http_and_quickjs_source', {'comic_count': page.data.length});

    // The encoded c37 cover only decodes after the JS onResponse callback.
    final coverStream = CachedImageProvider(
      server.coverUrl(xorComicId),
      sourceKey: source.key,
      cid: xorComicId,
    ).resolve(ImageConfiguration.empty);
    final decoded = Completer<void>();
    final listener = ImageStreamListener((image, synchronousCall) {
      if (!decoded.isCompleted) {
        if (image.image.width == 240 && image.image.height == 320) {
          decoded.complete();
        } else {
          decoded.completeError(StateError('Wrong decoded XOR cover size'));
        }
      }
    }, onError: (Object e, StackTrace? s) {
      if (!decoded.isCompleted) decoded.completeError(e, s);
    });
    coverStream.addListener(listener);
    try {
      await decoded.future.timeout(const Duration(seconds: 30));
    } finally {
      coverStream.removeListener(listener);
    }
    _require(server.count('/img/cover/c37.png') > 0,
        'XOR cover was not requested over real HTTP');
    _record('quickjs_onResponse_and_native_image_decode');

    await _decodeCover(source, 'c03');
    await _openOnline(source);
    final task = ImagesDownloadTask(
      source: source, comicId: 'c09', chapters: const ['1'],
    );
    LocalManager().addTask(task);
    final type = ComicType.fromKey(source.key);
    await _until(
      () {
        if (task.isError) throw StateError('Download failed: ${task.message}');
        return LocalManager().find('c09', type) != null &&
            !LocalManager().isDownloading('c09', type);
      },
      'Synthetic download did not complete',
      timeout: const Duration(seconds: 90),
    );
    final local = LocalManager().find('c09', type)!;
    final pages = await LocalManager().getImages('c09', type, 1);
    _require(pages.length == 5, 'Downloaded chapter must contain five pages');
    final digests = <String>[];
    for (var i = 0; i < pages.length; i++) {
      final path = pages[i].substring('file://'.length);
      final data = await File(path).readAsBytes();
      _require(sha256.convert(data) == sha256.convert(pagePng(i + 1)),
          'Downloaded page bytes differ from synthetic fixture');
      digests.add(sha256.convert(data).toString());
    }
    _record('real_download_and_page_bytes', {
      'pages': pages.length, 'sha256': digests,
    });
    await server.stop();
    stopped = true;
    await _openOffline(local);
    appdata.settings['language'] = 'en-US';
    appdata.settings['theme_mode'] = 'dark';
    if (!appdata.searchHistory.contains('YORUNOTE_WINDOWS_ACCEPTANCE')) {
      appdata.searchHistory.add('YORUNOTE_WINDOWS_ACCEPTANCE');
    }
    await appdata.saveData(false);
    App.forceRebuild();
    await _stage('home-en-US-dark');
    _require(_widgets().whereType<MaterialApp>().any(
      (w) => w.locale?.languageCode == 'en' && w.themeMode == ThemeMode.dark,
    ), 'English or dark mode was not applied');
    _record('english_dark_home_and_settings_saved');
  } finally {
    if (!stopped) await server.stop();
  }
}

Future<void> _restart() async {
  _require(appdata.settings['language'] == 'en-US', 'Locale did not survive restart');
  _require(appdata.settings['theme_mode'] == 'dark', 'Theme did not survive restart');
  _require(appdata.searchHistory.contains('YORUNOTE_WINDOWS_ACCEPTANCE'),
      'Saved search history did not survive restart');
  final source = ComicSource.find('yorunote_synthetic');
  _require(source != null, 'JS source was not restored from disk');
  final type = ComicType.fromKey(source!.key);
  final history = HistoryManager().find('c03', type);
  _require(history?.page == 2, 'SQLite reading page did not survive restart');
  final local = LocalManager().find('c09', type);
  _require(local != null, 'Downloaded comic database did not survive restart');
  final pages = await LocalManager().getImages('c09', type, 1);
  _require(pages.length == 5, 'Downloaded chapter did not survive restart');
  _record('restart_restores_settings_source_history_and_download', {
    'history_page': history!.page, 'downloaded_pages': pages.length,
  });
  // The first process's HTTP server is gone. This reads stored files only.
  await _openOffline(local!);
  await _stage('home-after-restart');
}

Future<void> main(List<String> args) async {
  if (!Platform.isWindows || Platform.environment['GITHUB_ACTIONS'] != 'true') {
    stderr.writeln('This acceptance entry point is restricted to disposable Windows CI.');
    exit(64);
  }
  final root = Platform.environment['YORUNOTE_SMOKE_EVIDENCE'];
  _phase = Platform.environment['YORUNOTE_SMOKE_PHASE'] ?? '';
  if (root == null || !const ['seed', 'restart'].contains(_phase)) exit(64);
  _evidence = Directory(root);
  await _evidence.create(recursive: true);
  var code = 1;
  String? failure;
  try {
    production.main(const []);
    await _until(
      () => App.isInitialized && HistoryManager().isInitialized &&
          App.rootNavigatorKey.currentState != null,
      'Real Windows app initialization did not complete',
      timeout: const Duration(seconds: 90),
    );
    final previousHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (!details.silent) _flutterErrors.add(details.exceptionAsString());
      previousHandler?.call(details);
    };
    _require(App.dataPath.toLowerCase().replaceAll(String.fromCharCode(92), '/').contains('/mengwen-liu/yorunote'),
        'Windows application data is not isolated under the Yorunote identity');
    await windowManager.setSize(const Size(1000, 700));
    await windowManager.center();
    _record('real_app_initialized_with_isolated_windows_identity');
    if (_phase == 'seed') {
      await _seed();
    } else {
      await _restart();
    }
    _require(_flutterErrors.isEmpty, 'Unhandled Flutter errors: ${_flutterErrors.join('; ')}');
    code = 0;
  } catch (error, stack) {
    failure = '$error\n$stack';
  }
  final report = {
    'phase': _phase,
    'passed': code == 0,
    'source': Platform.environment['YORUNOTE_SMOKE_SOURCE'],
    'checks': _checks,
    'flutter_errors': _flutterErrors,
    'failure': failure,
    'scope': 'Instrumented Windows CI executable using the real app and native plugins; not the distributed entry point.',
  };
  final json = const JsonEncoder.withIndent('  ').convert(report);
  await File('${_evidence.path}/smoke-$_phase.json').writeAsString('$json\n');
  if (failure != null) stderr.writeln(failure);
  await Future<void>.delayed(const Duration(milliseconds: 500));
  exit(code);
}
