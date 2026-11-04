// Cover (thumbnail) cache behaviour of CachedImageProvider and
// HistoryImageProvider, driven through ImageProvider.resolve with a local
// HTTP server, synthetic PNGs and a temporary data directory.
//
// A retry is simulated by resolving the provider again after the error, as
// the cover widgets do when they are rebuilt; no automatic retry is expected.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/image_provider/cached_image.dart';
import 'package:venera/foundation/image_provider/history_image_provider.dart';
import 'package:venera/network/images.dart';

import 'thumbnail_test_support.dart';

void main() {
  final server = CoverServer();
  // Lets work that continues after a provider finishes reach the server.
  const settle = Duration(milliseconds: 500);
  final srcA = testSource('thumb_test_a');
  final srcB = testSource('thumb_test_b');
  final srcCfg = testSource(
    'thumb_test_cfg',
    thumbnailConfig: (url) => {
      'url': url.replaceFirst('/original/', '/rewritten/'),
      'headers': {'x-thumb-test': 'cfg'},
    },
  );
  late Directory root;

  setUpAll(() async {
    root = await initCoverTestEnvironment(
      server,
      sources: [srcA, srcB, srcCfg],
    );
  });

  tearDownAll(() => server.stop());

  setUp(() => PaintingBinding.instance.imageCache.clear());

  CachedImageProvider cover(String url, {String? cid = 'c1', bool fb = false}) =>
      CachedImageProvider(
        url,
        sourceKey: srcA.key,
        cid: cid,
        fallbackToLocalCover: fb,
      );

  group('CachedImageProvider', () {
    testWidgets('a valid disk hit is shown without requests', (tester) async {
      await tester.runAsync(() async {
        const path = '/c/hit.png';
        final url = server.url(path);
        server.images[path] = png(10);
        await CacheManager().writeCache(thumbDiskKey(url, srcA.key, 'c1'), png(10));

        expect(await resolveOnce(cover(url)), isNull);
        await Future<void>.delayed(settle);
        expect(server.count(path), 0);
      });
    }, skip: !hasNativeHttp);

    testWidgets('a memory hit needs neither the disk nor the network', (
      tester,
    ) async {
      await tester.runAsync(() async {
        const path = '/c/memory.png';
        final url = server.url(path);
        server.images[path] = png(11);
        final key = thumbDiskKey(url, srcA.key, 'c1');
        await CacheManager().writeCache(key, png(11));
        final provider = cover(url);
        final first = Resolution(provider);
        expect(await first.result, isNull);
        // Keep the image alive in memory, then remove the disk copy.
        await CacheManager().delete(key);
        expect(await resolveOnce(cover(url)), isNull);
        first.dispose();
        await Future<void>.delayed(settle);
        expect(server.count(path), 0);
        expect(await CacheManager().findCache(key), isNull);
      });
    }, skip: !hasNativeHttp);

    testWidgets('a miss and an expired entry request once and are stored', (
      tester,
    ) async {
      await tester.runAsync(() async {
        const missPath = '/c/miss.png';
        final missUrl = server.url(missPath);
        server.images[missPath] = png(20);
        expect(await resolveOnce(cover(missUrl)), isNull);
        expect(server.count(missPath), 1);
        final stored = await CacheManager().findCache(
          thumbDiskKey(missUrl, srcA.key, 'c1'),
        );
        expect(await stored!.readAsBytes(), png(20));

        const expiredPath = '/c/expired.png';
        final expiredUrl = server.url(expiredPath);
        server.images[expiredPath] = png(30);
        await CacheManager().writeCache(
          thumbDiskKey(expiredUrl, srcA.key, 'c1'),
          png(31),
          -1000,
        );
        expect(await resolveOnce(cover(expiredUrl)), isNull);
        expect(server.count(expiredPath), 1);
        final refreshed = await CacheManager().findCache(
          thumbDiskKey(expiredUrl, srcA.key, 'c1'),
        );
        expect(await refreshed!.readAsBytes(), png(30));
      });
    }, skip: !hasNativeHttp);

    for (final (name, broken) in [
      ('undecodable', corruptPng),
      ('empty', Uint8List(0)),
    ]) {
      testWidgets('an $name entry is invalidated alone and a retry recovers', (
        tester,
      ) async {
        await tester.runAsync(() async {
          final path = '/c/$name-recover.png';
          final url = server.url(path);
          final otherUrl = server.url('/c/$name-other.png');
          server.images[path] = png(40);
          final key = thumbDiskKey(url, srcA.key, 'c1');
          final otherKey = thumbDiskKey(otherUrl, srcA.key, 'c1');
          await CacheManager().writeCache(key, broken);
          await CacheManager().writeCache(otherKey, png(41));

          expect(await resolveOnce(cover(url)), isNotNull);
          await Future<void>.delayed(settle);
          expect(server.count(path), 0, reason: 'no automatic refetch');
          expect(
            await CacheManager().findCache(key),
            isNull,
            reason: 'the broken entry is invalidated',
          );
          expect(await CacheManager().findCache(otherKey), isNotNull);

          expect(await resolveOnce(cover(url)), isNull, reason: 'retry');
          expect(server.count(path), 1);

          PaintingBinding.instance.imageCache.clear();
          expect(await resolveOnce(cover(url)), isNull, reason: 'read again');
          await Future<void>.delayed(settle);
          expect(server.count(path), 1);
        });
      }, skip: !hasNativeHttp);
    }

    testWidgets('a broken download is not kept in the cache', (tester) async {
      await tester.runAsync(() async {
        const path = '/c/broken-download.png';
        final url = server.url(path);
        server.images[path] = corruptPng;
        expect(await resolveOnce(cover(url)), isNotNull);
        expect(
          await CacheManager().findCache(thumbDiskKey(url, srcA.key, 'c1')),
          isNull,
        );
        server.images[path] = png(42);
        expect(await resolveOnce(cover(url)), isNull);
        expect(server.count(path), 2);
      });
    }, skip: !hasNativeHttp);

    testWidgets('invalidation keeps an entry repaired in the meantime', (
      tester,
    ) async {
      await tester.runAsync(() async {
        const path = '/c/repaired.png';
        final url = server.url(path);
        final key = thumbDiskKey(url, srcA.key, 'c1');
        await CacheManager().writeCache(key, corruptPng);
        // The bytes a failing load read from the broken entry ...
        Uint8List? stale;
        await for (final p in ImageDownloader.loadThumbnail(
          url,
          srcA.key,
          'c1',
        )) {
          if (p.imageBytes != null) {
            stale = p.imageBytes;
            break;
          }
        }
        // ... arrive after another request has stored a good image.
        await CacheManager().writeCache(key, png(50));
        // ignore: invalid_use_of_protected_member
        await cover(url).onInvalidImageData(stale!);
        final file = await CacheManager().findCache(key);
        expect(await file!.readAsBytes(), png(50));
      });
    }, skip: !hasNativeHttp);

    testWidgets('a broken local file is reported and never deleted', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final file = File('${root.path}/plain_local.png');
        await file.writeAsBytes(corruptPng);
        final url = 'file://${file.path}';
        await CacheManager().writeCache(thumbDiskKey(url, null), png(60));
        expect(await resolveOnce(CachedImageProvider(url)), isNotNull);
        expect(await file.exists(), isTrue);
        expect(await file.readAsBytes(), corruptPng);
        expect(
          await CacheManager().findCache(thumbDiskKey(url, null)),
          isNotNull,
        );

        await file.writeAsBytes(png(61));
        expect(await resolveOnce(CachedImageProvider(url)), isNull);
      });
    });

    testWidgets('the local cover fallback is used and never deleted', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final type = ComicType.fromKey(srcA.key);
        await addLocalComic(root, 'fb-ok', type, png(70));
        final okUrl = server.url('/c/fallback-missing.png');
        expect(await resolveOnce(cover(okUrl, cid: 'fb-ok', fb: true)), isNull);

        final badCover = await addLocalComic(root, 'fb-bad', type, corruptPng);
        final badUrl = server.url('/c/fallback-missing-2.png');
        expect(
          await resolveOnce(cover(badUrl, cid: 'fb-bad', fb: true)),
          isNotNull,
        );
        expect(await badCover.readAsBytes(), corruptPng);
      });
    }, skip: !hasNativeHttp);

    testWidgets('the same URL with another source or cid is kept apart', (
      tester,
    ) async {
      await tester.runAsync(() async {
        const path = '/c/shared-url.png';
        final url = server.url(path);
        server.images[path] = png(80);
        server.delay = const Duration(milliseconds: 200);
        final results = await Future.wait([
          resolveOnce(CachedImageProvider(url, sourceKey: srcA.key, cid: '1')),
          resolveOnce(CachedImageProvider(url, sourceKey: srcB.key, cid: '1')),
          resolveOnce(CachedImageProvider(url, sourceKey: srcA.key, cid: '2')),
        ]);
        server.delay = Duration.zero;
        expect(results, [null, null, null]);
        expect(server.count(path), 3);
        for (final (s, c) in [(srcA, '1'), (srcB, '1'), (srcA, '2')]) {
          expect(
            await CacheManager().findCache(thumbDiskKey(url, s.key, c)),
            isNotNull,
          );
        }
      });
    }, skip: !hasNativeHttp);

    testWidgets('the source thumbnail config still rewrites the request', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final url = server.url('/original/cfg.png');
        server.images['/rewritten/cfg.png'] = png(90);
        final provider = CachedImageProvider(
          url,
          sourceKey: srcCfg.key,
          cid: 'x',
        );
        expect(await resolveOnce(provider), isNull);
        expect(server.count('/rewritten/cfg.png'), 1);
        expect(server.count('/original/cfg.png'), 0);
        final headers = server.requestHeaders['/rewritten/cfg.png']!;
        expect(headers.value('x-thumb-test'), 'cfg');
        expect(headers.value('user-agent'), isNotEmpty);
        expect(
          await CacheManager().findCache(thumbDiskKey(url, srcCfg.key, 'x')),
          isNotNull,
        );
      });
    }, skip: !hasNativeHttp);
  });

  group('HistoryImageProvider', () {
    testWidgets('a valid disk hit is shown without requests', (tester) async {
      await tester.runAsync(() async {
        const path = '/h/hit.png';
        final url = server.url(path);
        server.images[path] = png(100);
        await CacheManager().writeCache(thumbDiskKey(url, srcA.key, 'h1'), png(100));
        final provider = HistoryImageProvider(testHistory('h1', srcA, url));
        expect(await resolveOnce(provider), isNull);
        await Future<void>.delayed(settle);
        expect(server.count(path), 0);
      });
    }, skip: !hasNativeHttp);

    for (final (name, broken) in [
      ('undecodable', corruptPng),
      ('empty', Uint8List(0)),
    ]) {
      testWidgets('an $name entry is invalidated alone and a retry recovers', (
        tester,
      ) async {
        await tester.runAsync(() async {
          final path = '/h/$name-recover.png';
          final url = server.url(path);
          server.images[path] = png(110);
          final key = thumbDiskKey(url, srcA.key, 'h-$name');
          final otherKey = thumbDiskKey(server.url('/h/$name-o.png'), srcA.key);
          await CacheManager().writeCache(key, broken);
          await CacheManager().writeCache(otherKey, png(111));
          final history = testHistory('h-$name', srcA, url);

          expect(await resolveOnce(HistoryImageProvider(history)), isNotNull);
          await Future<void>.delayed(settle);
          expect(server.count(path), 0, reason: 'no automatic refetch');
          expect(await CacheManager().findCache(key), isNull);
          expect(await CacheManager().findCache(otherKey), isNotNull);

          expect(await resolveOnce(HistoryImageProvider(history)), isNull);
          expect(server.count(path), 1);
        });
      }, skip: !hasNativeHttp);
    }

    testWidgets('a local history cover is shown and never deleted', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final before = server.total;
        final type = ComicType.fromKey(srcB.key);
        await addLocalComic(root, 'hl-ok', type, png(120));
        final ok = testHistory('hl-ok', srcB, 'cover.png');
        expect(await resolveOnce(HistoryImageProvider(ok)), isNull);

        final badCover = await addLocalComic(root, 'hl-bad', type, corruptPng);
        final bad = testHistory('hl-bad', srcB, 'cover.png');
        expect(await resolveOnce(HistoryImageProvider(bad)), isNotNull);
        expect(await badCover.readAsBytes(), corruptPng);
        expect(server.total, before);
      });
    });
  });
}
