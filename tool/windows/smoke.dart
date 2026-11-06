// Runs the real app and native plugins in a disposable Windows CI profile.
// This entry point is never used for the distributed executable.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:venera/components/windows_title_brand.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/image_provider/cached_image.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/main.dart' as production;
import 'package:venera/network/app_dio.dart';
import 'package:venera/network/download.dart';
import 'package:venera/pages/reader/reader.dart';
import 'package:venera/utils/io.dart' as app_io;
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

Future<void> _stage(String name, {Offset? pointerTarget}) async {
  await WidgetsBinding.instance.endOfFrame;
  final state = File('${_evidence.path}/stage.json');
  final ratio = WidgetsBinding.instance.platformDispatcher.views.single.devicePixelRatio;
  await state.writeAsString(jsonEncode({
    'stage': '$_phase-$name',
    if (pointerTarget != null) 'pointer_px': {
      'x': (pointerTarget.dx * ratio).round(),
      'y': (pointerTarget.dy * ratio).round(),
    },
  }));
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

bool _readerHasFocus() => _widgets().whereType<KeyboardListener>().any(
  (w) => w.autofocus && w.focusNode.hasFocus,
);

RawImage? _brandFrame() {
  RawImage? result;
  void imageVisitor(Element element) {
    if (element.widget is RawImage) result = element.widget as RawImage;
    element.visitChildren(imageVisitor);
  }

  void visit(Element element) {
    if (element.widget is WindowsTitleBrand) {
      element.visitChildren(imageVisitor);
      return;
    }
    element.visitChildren(visit);
  }

  final root = WidgetsBinding.instance.rootElement;
  if (root != null) visit(root);
  return result;
}

bool _brandUsesGif() => _widgets().whereType<Image>().any((widget) {
  ImageProvider provider = widget.image;
  if (provider is ResizeImage) provider = provider.imageProvider;
  return provider is AssetImage &&
      provider.assetName == WindowsTitleBrand.animatedAsset;
});

Future<void> _checkAnimatedBrand() async {
  await windowManager.focus();
  await _until(
    () => _brandUsesGif() && _brandFrame()?.image != null,
    'Windows title GIF did not load in the active window',
  );
  final first = _brandFrame()!.image;
  await _until(
    () =>
        _brandFrame()?.image != null && !identical(first, _brandFrame()!.image),
    'Windows title GIF did not advance frames',
    timeout: const Duration(seconds: 5),
  );
  _record('windows_title_mascot_gif_decoded_and_animated');
}

RenderBox _brandBox() {
  RenderBox? result;
  void visit(Element element) {
    if (element.widget is WindowsTitleBrand) {
      result = element.findRenderObject()! as RenderBox;
      return;
    }
    element.visitChildren(visit);
  }
  final root = WidgetsBinding.instance.rootElement;
  if (root != null) visit(root);
  _require(result != null, 'Actual Windows caption is missing');
  return result!;
}

bool _titleTooltipVisible() => _widgets().whereType<RichText>().any(
  (widget) => widget.text.toPlainText() == 'Yorunote',
);

Future<void> _checkTitleHover() async {
  await windowManager.focus();
  await _until(
    () => _brandUsesGif() && _brandFrame()?.image != null,
    'Caption GIF is unavailable before native pointer input',
  );
  final box = _brandBox();
  final target = box.localToGlobal(box.size.center(Offset.zero));
  await _stage('title-hover-enter', pointerTarget: target);
  await _until(
    _titleTooltipVisible,
    'Native mouse hover did not display the caption tooltip',
    timeout: const Duration(seconds: 5),
  );
  await _stage('title-hover-visible');
  final view = WidgetsBinding.instance.platformDispatcher.views.single;
  final center = view.physicalSize / view.devicePixelRatio / 2;
  await _stage('title-hover-leave', pointerTarget: Offset(center.width, center.height));
  await _until(
    () => !_titleTooltipVisible(),
    'Caption tooltip did not close after native pointer exit',
    timeout: const Duration(seconds: 5),
  );
  final first = _brandFrame()?.image;
  _require(first != null, 'Caption image disappeared after hover');
  await _until(
    () => _brandFrame()?.image != null && !identical(first, _brandFrame()!.image),
    'Caption animation stopped after hover',
    timeout: const Duration(seconds: 5),
  );
  _require(_flutterErrors.isEmpty, 'Flutter error during actual caption hover');
  _require(_appErrors().isEmpty, 'App error during actual caption hover');
  _record('windows_title_native_hover_shows_tooltip_without_overlay_error', {
    'native_pointer': true,
    'tooltip_visible_then_dismissed': true,
    'gif_continues_after_hover': true,
  });
}

List<String> _appErrors() => Log.logs
    .where((item) => item.level == LogLevel.error)
    .map((item) => item.toString())
    .toList();

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
    _require(
      image.image.width == 240 && image.image.height == 320,
      'Decoded cover has wrong dimensions',
    );
  } finally {
    stream.removeListener(listener);
  }
}

Future<void> _openOnline(ComicSource source) async {
  unawaited(
    App.rootNavigatorKey.currentState!.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ReaderWithLoading(id: 'c03', sourceKey: source.key),
      ),
    ),
  );
  await _until(_hasPageImage, 'Reader did not render the synthetic page');
  _record('online_reader_decoded_600x900');
  await windowManager.focus();
  await _until(_readerHasFocus, 'Reader keyboard focus was not ready');
  await _stage('reader-before-key');
  final type = ComicType.fromKey(source.key);
  await _until(
    () => HistoryManager().getAll().any(
      (h) => h.id == 'c03' && h.type == type && h.page == 2,
    ),
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
  await _until(
    () => HistoryManager().getAll().any(
      (h) =>
          h.id == local.id &&
          h.type == local.comicType &&
          h.ep >= 1 &&
          h.page >= 1,
    ),
    'Offline reading history was not written to SQLite',
  );
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
  _require(
    _widgets().whereType<MaterialApp>().any(
      (w) => w.title == 'Yorunote' && w.locale?.countryCode == 'TW',
    ),
    'App title or Traditional Chinese locale was not applied',
  );
  _require(
    _widgets().whereType<Tooltip>().any((w) => w.message == 'Yorunote'),
    'Windows title logo lacks the Yorunote tooltip',
  );
  _record('traditional_chinese_home_and_title');
  await _checkAnimatedBrand();
  await _checkTitleHover();

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
      response.data!,
      'yorunote_windows_acceptance.js',
    );
    ComicSourceManager().add(source);
    final page = await source.explorePages.single.loadPage!(1);
    _require(
      !page.error && page.data.length == 20,
      'QuickJS synthetic source did not return 20 comics',
    );
    _record('native_http_and_quickjs_source', {
      'comic_count': page.data.length,
    });

    // The encoded c37 cover only decodes after the JS onResponse callback.
    final coverStream = CachedImageProvider(
      server.coverUrl(xorComicId),
      sourceKey: source.key,
      cid: xorComicId,
    ).resolve(ImageConfiguration.empty);
    final decoded = Completer<void>();
    final listener = ImageStreamListener(
      (image, synchronousCall) {
        if (!decoded.isCompleted) {
          if (image.image.width == 240 && image.image.height == 320) {
            decoded.complete();
          } else {
            decoded.completeError(StateError('Wrong decoded XOR cover size'));
          }
        }
      },
      onError: (Object e, StackTrace? s) {
        if (!decoded.isCompleted) decoded.completeError(e, s);
      },
    );
    coverStream.addListener(listener);
    try {
      await decoded.future.timeout(const Duration(seconds: 30));
    } finally {
      coverStream.removeListener(listener);
    }
    _require(
      server.count('/img/cover/c37.png') > 0,
      'XOR cover was not requested over real HTTP',
    );
    _record('quickjs_onResponse_and_native_image_decode');

    await _decodeCover(source, 'c03');
    await _openOnline(source);
    final task = ImagesDownloadTask(
      source: source,
      comicId: 'c09',
      chapters: const ['1'],
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
      _require(
        sha256.convert(data) == sha256.convert(pagePng(i + 1)),
        'Downloaded page bytes differ from synthetic fixture',
      );
      digests.add(sha256.convert(data).toString());
    }
    _record('real_download_and_page_bytes', {
      'pages': pages.length,
      'sha256': digests,
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
    _require(
      _widgets().whereType<MaterialApp>().any(
        (w) => w.locale?.languageCode == 'en' && w.themeMode == ThemeMode.dark,
      ),
      'English or dark mode was not applied',
    );
    _record('english_dark_home_and_settings_saved');
  } finally {
    if (!stopped) await server.stop();
  }
}

Future<void> _restart() async {
  _require(
    appdata.settings['language'] == 'en-US',
    'Locale did not survive restart',
  );
  _require(
    appdata.settings['theme_mode'] == 'dark',
    'Theme did not survive restart',
  );
  _require(
    appdata.searchHistory.contains('YORUNOTE_WINDOWS_ACCEPTANCE'),
    'Saved search history did not survive restart',
  );
  final source = ComicSource.find('yorunote_synthetic');
  _require(source != null, 'JS source was not restored from disk');
  final type = ComicType.fromKey(source!.key);
  final history = HistoryManager().find('c03', type);
  _require(history?.page == 2, 'SQLite reading page did not survive restart');
  final local = LocalManager().find('c09', type);
  _require(local != null, 'Downloaded comic database did not survive restart');
  final pages = await LocalManager().getImages('c09', type, 1);
  _require(pages.length == 5, 'Downloaded chapter did not survive restart');
  final digests = <String>[];
  for (var i = 0; i < pages.length; i++) {
    final bytes = await File(pages[i]).readAsBytes();
    _require(
      sha256.convert(bytes) == sha256.convert(pagePng(i + 1)),
      'Saved page bytes changed after restart',
    );
    digests.add(sha256.convert(bytes).toString());
  }
  _record('restart_restores_settings_source_history_and_download', {
    'history_page': history!.page,
    'downloaded_pages': pages.length,
    'page_sha256': digests,
    'offline_history': HistoryManager().find('c09', type)?.toString(),
  });
  // The first process's HTTP server is gone. This reads stored files only.
  await _openOffline(local!);
  await _stage('home-after-restart');
  await _checkTitleHover();
}

Future<void> _captureFailureState() async {
  try {
    final texts = <String>[];
    final images = <String>[];
    final readers = <String>[];
    for (final widget in _widgets()) {
      if (widget is Text && widget.data != null) {
        texts.add(widget.data!);
      }
      if (widget is RawImage && widget.image != null) {
        images.add('${widget.image!.width}x${widget.image!.height}');
      }
      if (widget is Reader) {
        readers.add(
          '${widget.cid}:${widget.initialChapter}:${widget.initialPage}',
        );
      }
    }
    final snapshot = {
      'phase': _phase,
      'io_override_active': IOOverrides.current != null,
      'readers': readers,
      'text': texts,
      'images': images,
      'app_errors': _appErrors(),
    };
    final file = File('${_evidence.path}/$_phase-failure-state.json');
    await file.writeAsString(jsonEncode(snapshot));
    await _stage('failure');
  } catch (error) {
    stderr.writeln('Failure-state capture unavailable: $error');
  }
}

Future<void> main(List<String> args) {
  return app_io.overrideIO(() => _run(args));
}

Future<void> _run(List<String> args) async {
  if (!Platform.isWindows || Platform.environment['GITHUB_ACTIONS'] != 'true') {
    stderr.writeln(
      'This acceptance entry point is restricted to disposable Windows CI.',
    );
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
    _require(IOOverrides.current != null, 'Application IO zone is required');
    production.main(const []);
    await _until(
      () =>
          App.isInitialized &&
          HistoryManager().isInitialized &&
          App.rootNavigatorKey.currentState != null,
      'Real Windows app initialization did not complete',
      timeout: const Duration(seconds: 90),
    );
    final previousHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      if (!details.silent) _flutterErrors.add(details.exceptionAsString());
      previousHandler?.call(details);
    };
    _require(
      App.dataPath
          .toLowerCase()
          .replaceAll(String.fromCharCode(92), '/')
          .contains('/mengwen-liu/yorunote'),
      'Windows application data is not isolated under the Yorunote identity',
    );
    await windowManager.setSize(const Size(1000, 700));
    await windowManager.center();
    _record('real_app_initialized_with_isolated_windows_identity');
    if (_phase == 'seed') {
      await _seed();
    } else {
      await _restart();
    }
    _require(
      _flutterErrors.isEmpty,
      'Unhandled Flutter errors: ${_flutterErrors.join('; ')}',
    );
    _require(
      _appErrors().isEmpty,
      'Native app errors: ${_appErrors().join('; ')}',
    );
    code = 0;
  } catch (error, stack) {
    failure = '$error\n$stack';
    await _captureFailureState();
  }
  final report = {
    'phase': _phase,
    'passed': code == 0,
    'source': Platform.environment['YORUNOTE_SMOKE_SOURCE'],
    'checks': _checks,
    'flutter_errors': _flutterErrors,
    'app_errors': _appErrors(),
    'failure': failure,
    'scope':
        'Instrumented Windows CI executable using the real app and native plugins; not the distributed entry point.',
  };
  final json = const JsonEncoder.withIndent('  ').convert(report);
  await File('${_evidence.path}/smoke-$_phase.json').writeAsString('$json\n');
  if (failure != null) stderr.writeln(failure);
  await Future<void>.delayed(const Duration(milliseconds: 500));
  exit(code);
}
