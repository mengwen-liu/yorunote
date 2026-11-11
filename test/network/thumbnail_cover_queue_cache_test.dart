// Cache consistency while a cover request waits for a network slot.
//
// All 8 slots are held by requests that wait for their headers, so the cover
// under test is queued. While it waits, the disk cache entry of its key is
// written by another real path; when it finally gets a slot it must:
// - use a valid image written in the meantime without any extra request;
// - not take empty or undecodable bytes for a valid hit;
// - not use an entry written for another source or cid.

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/image_provider/cached_image.dart';
import 'package:venera/network/images.dart';

import 'raw_image_server.dart';
import 'thumbnail_test_support.dart';

const _limit = 8;

void main() {
  final unused = CoverServer();
  final server = RawImageServer();
  final srcA = testSource('thumb_qc_a');
  final srcB = testSource('thumb_qc_b');

  setUpAll(() async {
    await initCoverTestEnvironment(unused, sources: [srcA, srcB]);
    if (hasNativeHttp) await server.start();
  });

  tearDownAll(() async {
    await unused.stop();
    if (hasNativeHttp) await server.stop();
  });

  setUp(() => PaintingBinding.instance.imageCache.clear());

  String path(String name, {RawMode mode = RawMode.immediate, int shade = 0}) {
    final p = '/qc/$name.png';
    server.images[p] = png(shade, width: 32, height: 32);
    server.modes[p] = mode;
    return p;
  }

  Future<void> eventually(bool Function() condition, String what) async {
    final sw = Stopwatch()..start();
    while (!condition()) {
      if (sw.elapsed > const Duration(seconds: 10)) {
        fail('timed out waiting for: $what');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  final limiter = ImageDownloader.coverRequestLimiter;

  /// Holds all slots; returns the held paths.
  Future<List<String>> fillSlots(String prefix) async {
    await server.releaseAll();
    await eventually(() => limiter.active == 0, 'idle limiter');
    final ps = [
      for (var i = 0; i < _limit; i++)
        path('$prefix-held-$i', mode: RawMode.holdHeaders, shade: i),
    ];
    for (final p in ps) {
      Resolution(CachedImageProvider(server.url(p), sourceKey: srcA.key));
    }
    await server.until(() => ps.every((p) => server.count(p) == 1));
    expect(limiter.active, _limit);
    return ps;
  }

  Future<void> releaseSlots(List<String> ps) async {
    for (final p in ps) {
      await server.heldFor(p).single.release();
    }
  }

  testWidgets(
    'a valid image written while queued is used, no extra request',
    (tester) async {
      await tester.runAsync(() async {
        final held = await fillSlots('e1');
        final p = path('e1-target', shade: 100);
        final url = server.url(p);
        final queued = Resolution(
          CachedImageProvider(url, sourceKey: srcA.key, cid: 'e1'),
        );
        await eventually(() => limiter.waiting >= 1, 'target queued');
        // Another real write path (the download task's cover loader) stores
        // the same key while the cover waits.
        await for (final _ in ImageDownloader.loadThumbnail(
          url,
          srcA.key,
          'e1',
        )) {}
        expect(server.count(p), 1);
        expect(
          await CacheManager().findCache(thumbDiskKey(url, srcA.key, 'e1')),
          isNotNull,
        );
        await releaseSlots(held);
        expect(await queued.result, isNull);
        expect(server.count(p), 1, reason: 'the cached image was used');
        queued.dispose();
      });
    },
    skip: !hasNativeHttp,
  );

  for (final (name, bytes) in [
    ('empty', Uint8List(0)),
    ('undecodable', corruptPng),
  ]) {
    testWidgets(
      'an $name entry written while queued is not a valid hit',
      (tester) async {
        await tester.runAsync(() async {
          final held = await fillSlots('e2-$name');
          final p = path('e2-$name-target', shade: 110);
          final url = server.url(p);
          final key = thumbDiskKey(url, srcA.key, 'e2');
          final queued = Resolution(
            CachedImageProvider(url, sourceKey: srcA.key, cid: 'e2'),
          );
          await eventually(() => limiter.waiting >= 1, 'target queued');
          await CacheManager().writeCache(key, bytes);
          await releaseSlots(held);
          expect(
            await queued.result,
            isNull,
            reason: 'loaded from the network',
          );
          expect(server.count(p), 1);
          final file = await CacheManager().findCache(key);
          expect(await file!.readAsBytes(), server.images[p]);
          queued.dispose();
        });
      },
      skip: !hasNativeHttp,
    );
  }

  testWidgets('an entry for another source or cid is not used', (tester) async {
    await tester.runAsync(() async {
      final held = await fillSlots('e3');
      final p = path('e3-target', shade: 120);
      final url = server.url(p);
      final queued = Resolution(
        CachedImageProvider(url, sourceKey: srcA.key, cid: 'e3'),
      );
      await eventually(() => limiter.waiting >= 1, 'target queued');
      final other = png(121, width: 32, height: 32);
      await CacheManager().writeCache(thumbDiskKey(url, srcB.key, 'e3'), other);
      await CacheManager().writeCache(thumbDiskKey(url, srcA.key, 'x'), other);
      await releaseSlots(held);
      expect(await queued.result, isNull);
      expect(server.count(p), 1, reason: 'other keys are not a hit');
      final own = await CacheManager().findCache(
        thumbDiskKey(url, srcA.key, 'e3'),
      );
      expect(await own!.readAsBytes(), server.images[p]);
      final b = await CacheManager().findCache(
        thumbDiskKey(url, srcB.key, 'e3'),
      );
      expect(await b!.readAsBytes(), other, reason: 'other entries kept');
      queued.dispose();
    });
  }, skip: !hasNativeHttp);
}
