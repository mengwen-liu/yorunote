// The synthetic comic source and server (tool/synthetic_source) driven
// through the app's own code: the script is downloaded with AppDio and
// imported with ComicSourceParser.createAndParse, exactly as the comic source
// page does; it runs in QuickJS (flutter_qjs); covers and pages are loaded by
// the real image providers over rhttp.
//
// Needs a host librhttp.so (FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR)
// and a host build of flutter_qjs (libflutter_qjs_plugin.so on
// LD_LIBRARY_PATH); otherwise the tests are skipped and say so.

import 'dart:ffi';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/image_provider/cached_image.dart';
import 'package:venera/foundation/image_provider/history_image_provider.dart';
import 'package:venera/foundation/image_provider/reader_image.dart';
import 'package:venera/foundation/js_engine.dart';
import 'package:venera/network/app_dio.dart';

import '../../tool/synthetic_source/synthetic_server.dart';
import 'thumbnail_test_support.dart';

final bool _hasQjs = () {
  try {
    DynamicLibrary.open('libflutter_qjs_plugin.so');
    return true;
  } catch (_) {
    return false;
  }
}();

final String? _skipReason = !hasNativeHttp
    ? 'needs a host librhttp.so'
    : !_hasQjs
    ? 'needs a host libflutter_qjs_plugin.so on LD_LIBRARY_PATH'
    : null;

final bool _skip = _skipReason != null;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (_skip) {
    // ignore: avoid_print
    print('synthetic_source_test skipped: $_skipReason');
  }
  final unused = CoverServer();
  late SyntheticServer server;
  late ComicSource source;

  setUpAll(() async {
    if (_skip) return;
    await initCoverTestEnvironment(unused);
    final template = await File(
      'tool/synthetic_source/yorunote_synthetic_source.js',
    ).readAsString();
    server = SyntheticServer(sourceTemplate: template);
    await server.start();
    // App start-up (lib/init.dart): JS engine with assets/init.js in
    // QuickJS, then the comic source manager (creates the source folder).
    await JsEngine().init();
    await ComicSourceManager().init();
    await Directory('${App.dataPath}/comic_source').create(recursive: true);
    // Same steps as ComicSourcePage.handleAddSource / addSource.
    final res = await AppDio().get<String>(
      '${server.baseUrl}/source.js',
      options: Options(responseType: ResponseType.plain),
    );
    source = await ComicSourceParser().createAndParse(res.data!, 'source.js');
    ComicSourceManager().add(source);
  });

  tearDownAll(() async {
    if (_skip) return;
    await unused.stop();
    await server.stop();
  });

  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    if (!_skip) {
      server.delay = Duration.zero;
      server.resetCounters();
    }
  });

  Future<List<Comic>> explore(int page) async {
    final load = source.explorePages.single.loadPage!;
    final res = await load(page);
    expect(res.error, isFalse, reason: res.errorMessage);
    return res.data;
  }

  testWidgets('the source is imported and runs in QuickJS', (tester) async {
    await tester.runAsync(() async {
      expect(source.key, 'yorunote_synthetic');
      final page1 = await explore(1);
      final page2 = await explore(2);
      expect(page1.length, 20);
      expect(page2.length, 20);
      expect(page1.first.cover, '${server.baseUrl}/img/cover/c01.png');
      final info = await source.loadComicInfo!('c05');
      expect(info.error, isFalse);
      expect(info.data.cover, '${server.baseUrl}/img/cover/c05.png');
      expect(info.data.chapters!.length, 2);
      final pages = await source.loadComicPages!('c05', '1');
      expect(pages.data.length, 5);
    });
  }, skip: _skip);

  testWidgets('a page of covers loads with at most 8 image requests at once', (
    tester,
  ) async {
    await tester.runAsync(() async {
      server.delay = const Duration(milliseconds: 60);
      final comics = await explore(1);
      final rs = [
        for (final c in comics)
          Resolution(
            CachedImageProvider(c.cover, sourceKey: source.key, cid: c.id),
          ),
      ];
      expect(await Future.wait(rs.map((r) => r.result)), everyElement(isNull));
      expect(server.imageRequests, 20);
      expect(server.peakImages, lessThanOrEqualTo(8));
      // Second time: all from the cache.
      PaintingBinding.instance.imageCache.clear();
      final again = [
        for (final c in comics)
          Resolution(
            CachedImageProvider(c.cover, sourceKey: source.key, cid: c.id),
          ),
      ];
      expect(
        await Future.wait(again.map((r) => r.result)),
        everyElement(isNull),
      );
      expect(server.imageRequests, 20, reason: 'cache hits, no requests');
      for (final r in [...rs, ...again]) {
        r.dispose();
      }
    });
  }, skip: _skip);

  testWidgets('onThumbnailLoad onResponse decodes an encoded cover', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final url = server.coverUrl(xorComicId);
      final r = Resolution(
        CachedImageProvider(url, sourceKey: source.key, cid: xorComicId),
      );
      expect(await r.result, isNull);
      r.dispose();
      final file = await CacheManager().findCache(
        thumbDiskKey(url, source.key, xorComicId),
      );
      expect(await file!.readAsBytes(), coverPng(37), reason: 'decoded copy');
    });
  }, skip: _skip);

  testWidgets('a cover. placeholder is resolved through loadInfo', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final comic = (await explore(
        2,
      )).firstWhere((c) => c.id == placeholderComicId);
      expect(comic.cover, 'cover.$placeholderComicId');
      final r = Resolution(
        CachedImageProvider(
          comic.cover,
          sourceKey: source.key,
          cid: placeholderComicId,
        ),
      );
      expect(await r.result, isNull);
      r.dispose();
      expect(server.count('/api/comic/$placeholderComicId'), 1);
      expect(server.count('/img/cover/$placeholderComicId.png'), 1);
      expect(
        await CacheManager().findCache(
          thumbDiskKey(server.coverUrl(placeholderComicId), source.key),
        ),
        isNotNull,
      );
    });
  }, skip: _skip);

  testWidgets('history and cover tiles of one comic share one request', (
    tester,
  ) async {
    await tester.runAsync(() async {
      server.delay = const Duration(milliseconds: 200);
      final url = server.coverUrl('c25');
      final a = Resolution(
        CachedImageProvider(url, sourceKey: source.key, cid: 'c25'),
      );
      final b = Resolution(
        HistoryImageProvider(testHistory('c25', source, url)),
      );
      expect(await a.result, isNull);
      expect(await b.result, isNull);
      expect(server.count('/img/cover/c25.png'), 1);
      a.dispose();
      b.dispose();
    });
  }, skip: _skip);

  testWidgets('a broken cover is shown as an error and recovers on retry', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final url = server.coverUrl('c26');
      await _get('${server.baseUrl}/__control/broken?match=/img/cover/c26');
      expect(
        await resolveOnce(
          CachedImageProvider(url, sourceKey: source.key, cid: 'c26'),
        ),
        isNotNull,
      );
      await _get('${server.baseUrl}/__control/recover');
      expect(
        await resolveOnce(
          CachedImageProvider(url, sourceKey: source.key, cid: 'c26'),
        ),
        isNull,
      );
      expect(server.count('/img/cover/c26.png'), 2);
    });
  }, skip: _skip);

  testWidgets('paused covers do not block cached covers', (tester) async {
    await tester.runAsync(() async {
      final comics = await explore(1);
      // c01 is cached from an earlier test in this file only if run in order;
      // make sure it is.
      final hit = comics.first;
      await resolveOnce(
        CachedImageProvider(hit.cover, sourceKey: source.key, cid: hit.id),
      );
      PaintingBinding.instance.imageCache.clear();
      await _get('${server.baseUrl}/__control/pause');
      final paused = [
        for (final id in [
          'c41',
          'c42',
          'c43',
          'c44',
          'c45',
          'c46',
          'c47',
          'c48',
          'c49',
        ])
          Resolution(
            CachedImageProvider(
              server.coverUrl(id),
              sourceKey: source.key,
              cid: id,
            ),
          ),
      ];
      await server.untilActive(8).catchError((Object e) {
        fail('not 8 active: ${server.stats()}');
      });
      final cached = Resolution(
        CachedImageProvider(hit.cover, sourceKey: source.key, cid: hit.id),
      );
      expect(await cached.result, isNull, reason: 'shown while paused');
      expect(server.activeImages, 8);
      await _get('${server.baseUrl}/__control/release');
      expect(
        await Future.wait(paused.map((r) => r.result)),
        everyElement(isNull),
      );
      for (final r in [...paused, cached]) {
        r.dispose();
      }
    });
  }, skip: _skip);

  testWidgets('chapter pages load through ReaderImageProvider', (tester) async {
    await tester.runAsync(() async {
      final pages = (await source.loadComicPages!('c03', '1')).data;
      final r = Resolution(
        ReaderImageProvider(pages.first, source.key, 'c03', '1', 1),
      );
      expect(await r.result, isNull);
      r.dispose();
      expect(server.count('/img/page/c03/1/1.png'), 1);
    });
  }, skip: _skip);
}

/// Calls a control endpoint over real HTTP (rhttp). dart:io's HttpClient is
/// replaced by a fake in flutter tests, so it is not used here.
Future<void> _get(String url) async {
  final res = await AppDio().get<String>(
    url,
    options: Options(responseType: ResponseType.plain),
  );
  expect(res.statusCode, 200);
}
