// Cover (thumbnail) loading queue: concurrency limit, cache hits and local
// files while the network queue is full, cancellation and failures.
//
// The server holds responses until the test releases them, so the order of
// events is set by the test. A short fixed wait is used only where the test
// checks that something does NOT happen (no extra request, no blocked load);
// timeouts only stop a broken run from hanging.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/image_provider/cached_image.dart';
import 'package:venera/foundation/image_provider/history_image_provider.dart';

import 'thumbnail_test_support.dart';

/// Concurrency limit of cover network requests.
const _limit = 8;

void main() {
  final server = CoverServer();
  const quiet = Duration(milliseconds: 400);
  final src = testSource('thumb_queue_src');
  late Directory root;

  setUpAll(() async {
    root = await initCoverTestEnvironment(server, sources: [src]);
  });

  tearDownAll(() => server.stop());

  setUp(() => PaintingBinding.instance.imageCache.clear());

  CachedImageProvider cover(String path, {String cid = 'q'}) =>
      CachedImageProvider(server.url(path), sourceKey: src.key, cid: cid);

  List<String> paths(String prefix, int n, {int shade = 0}) {
    return [
      for (var i = 0; i < n; i++)
        () {
          final p = '/q/$prefix-$i.png';
          server.images[p] = png(shade + i);
          return p;
        }(),
    ];
  }

  /// All [_limit] slots are busy with held requests once this completes.
  Future<List<Resolution>> fillQueue(String prefix, int n) async {
    server.holdResponses = true;
    final rs = [for (final p in paths(prefix, n)) Resolution(cover(p))];
    await server.inflightAtLeast(_limit).timeout(const Duration(seconds: 20));
    return rs;
  }

  testWidgets('at most $_limit cover requests run at the same time', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // A failed earlier test must not leave held requests behind.
      await server.drain();
      server.resetCounters();
      final rs = await fillQueue('peak', 20);
      await Future<void>.delayed(quiet);
      final peakWhileHeld = server.peakInflight;
      server.holdResponses = false;
      server.releaseAll();
      final results = await Future.wait(rs.map((r) => r.result));
      expect(results, everyElement(isNull));
      expect(peakWhileHeld, _limit);
      expect(server.peakInflight, lessThanOrEqualTo(_limit));
      expect(server.total, 20, reason: 'each cover is requested once');
      for (final r in rs) {
        r.dispose();
      }
    });
  }, skip: !hasNativeHttp);

  testWidgets('cache hits and local files do not wait for a full queue', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // A failed earlier test must not leave held requests behind.
      await server.drain();
      final held = await fillQueue('busy', _limit + 4);
      final hitPaths = paths('hit', 3, shade: 100);
      for (final p in hitPaths) {
        await CacheManager().writeCache(
          thumbDiskKey(server.url(p), src.key, 'q'),
          png(100),
        );
      }
      final file = File('${root.path}/queue_local.png');
      await file.writeAsBytes(png(7));
      await CacheManager().writeCache(
        thumbDiskKey(server.url('/q/hist.png'), src.key, 'qh'),
        png(8),
      );
      final fast = [
        for (final p in hitPaths) Resolution(cover(p)),
        Resolution(CachedImageProvider('file://${file.path}')),
        Resolution(
          HistoryImageProvider(testHistory('qh', src, server.url('/q/hist.png'))),
        ),
      ];
      final before = server.total;
      // Fails (times out) if these loads wait for a network slot.
      final fastResults = await Future.wait(
        fast.map((r) => r.result),
      ).timeout(const Duration(seconds: 10));
      expect(fastResults, everyElement(isNull));
      expect(server.total, before, reason: 'no request for cached covers');
      expect(server.heldCount, _limit, reason: 'network still blocked');

      server.holdResponses = false;
      server.releaseAll();
      expect(
        await Future.wait(held.map((r) => r.result)),
        everyElement(isNull),
      );
      for (final r in [...held, ...fast]) {
        r.dispose();
      }
    });
  }, skip: !hasNativeHttp);

  testWidgets('cancelled loads give their slots back', (tester) async {
    await tester.runAsync(() async {
      // A failed earlier test must not leave held requests behind.
      await server.drain();
      final rs = await fillQueue('cancel', 16);
      // Every load that will start without a free slot has reached the server.
      await Future<void>.delayed(quiet);
      final active = <Resolution>[];
      final waiting = <Resolution>[];
      for (final r in rs) {
        final path = Uri.parse((r.provider as CachedImageProvider).url).path;
        (server.count(path) > 0 ? active : waiting).add(r);
      }
      expect(active, isNotEmpty);
      // Cancel half of the running and half of the waiting loads.
      final cancelled = [...active.take(4), ...waiting.take(4)];
      for (final r in cancelled) {
        r.cancel();
      }
      server.holdResponses = false;
      server.releaseAll();
      final kept = rs.where((r) => !cancelled.contains(r)).toList();
      expect(
        await Future.wait(kept.map((r) => r.result)),
        everyElement(isNull),
      );
      for (final r in waiting.take(4)) {
        final path = Uri.parse((r.provider as CachedImageProvider).url).path;
        expect(server.count(path), 0, reason: 'cancelled before its turn');
      }
      for (final r in kept) {
        r.dispose();
      }

      // All slots are free again: a new batch fills the queue completely.
      final again = await fillQueue('after-cancel', _limit);
      server.holdResponses = false;
      server.releaseAll();
      expect(
        await Future.wait(again.map((r) => r.result)),
        everyElement(isNull),
      );
      for (final r in again) {
        r.dispose();
      }
    });
  }, skip: !hasNativeHttp);

  testWidgets('HTTP errors and broken responses release slots, cache nothing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // A failed earlier test must not leave held requests behind.
      await server.drain();
      final failing = <String>[];
      for (final code in [403, 404, 500]) {
        for (var i = 0; i < 3; i++) {
          final p = '/q/status-$code-$i.png';
          server.statusCodes[p] = code;
          failing.add(p);
        }
      }
      for (var i = 0; i < 3; i++) {
        final p = '/q/partial-$i.png';
        server.images[p] = png(200 + i, width: 64, height: 64);
        server.partial.add(p);
        failing.add(p);
      }
      final good = paths('after-errors', 6, shade: 50);
      final fails = [for (final p in failing) Resolution(cover(p))];
      final oks = [for (final p in good) Resolution(cover(p))];
      expect(await Future.wait(oks.map((r) => r.result)), everyElement(isNull));
      expect(
        await Future.wait(fails.map((r) => r.result)),
        everyElement(isNotNull),
      );
      for (final p in failing) {
        expect(
          await CacheManager().findCache(
            thumbDiskKey(server.url(p), src.key, 'q'),
          ),
          isNull,
        );
      }
      for (final r in [...fails, ...oks]) {
        r.dispose();
      }

      // No slot is lost: a new batch fills the queue completely.
      final again = await fillQueue('after-errors-2', _limit);
      server.holdResponses = false;
      server.releaseAll();
      expect(
        await Future.wait(again.map((r) => r.result)),
        everyElement(isNull),
      );
      for (final r in again) {
        r.dispose();
      }
    });
  }, skip: !hasNativeHttp, timeout: const Timeout(Duration(minutes: 3)));

  testWidgets('history and cover tiles of one comic share one request', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // A failed earlier test must not leave held requests behind.
      await server.drain();
      final p = paths('dup', 1).single;
      final url = server.url(p);
      server.holdResponses = true;
      final rs = [
        Resolution(CachedImageProvider(url, sourceKey: src.key, cid: 'd')),
        Resolution(HistoryImageProvider(testHistory('d', src, url))),
        Resolution(
          CachedImageProvider(
            url,
            sourceKey: src.key,
            cid: 'd',
            fallbackToLocalCover: true,
          ),
        ),
      ];
      await server.inflightAtLeast(1);
      await Future<void>.delayed(quiet);
      server.holdResponses = false;
      server.releaseAll();
      expect(await Future.wait(rs.map((r) => r.result)), everyElement(isNull));
      expect(server.count(p), 1);
      for (final r in rs) {
        r.dispose();
      }
    });
  }, skip: !hasNativeHttp);
}
