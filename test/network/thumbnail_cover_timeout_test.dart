// Per-attempt total timeout of cover requests (ImageDownloader.loadCoverThumbnail)
// through the real path: shared cover load -> RequestLimiter -> AppDio ->
// RHttpAdapter -> rhttp (native), against a raw local server.
//
// The server decides when headers and body bytes are sent and observes when
// the client closes the connection, which is the evidence that the native
// request ended. Orders are decided by events; the timeout only turns a hang
// into a failure, except in the tests whose subject is the timeout itself.
// The "race" tests probe orderings with jitter around the deadline; passing
// them is not a proof that no race exists.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/image_provider/cached_image.dart';
import 'package:venera/network/app_dio.dart';
import 'package:venera/network/images.dart';

import 'raw_image_server.dart';
import 'thumbnail_test_support.dart';

const _limit = 8;

/// Short cover timeout used by most tests.
const _short = Duration(milliseconds: 400);

/// Failure bound for waiting on something that must happen.
const _bound = Duration(seconds: 15);

/// Sets the cover request timeout for a test; null restores the default.
void setCoverRequestTimeout(Duration? timeout) {}

void main() {
  final unused = CoverServer();
  final server = RawImageServer();
  final src = testSource('thumb_timeout_src');

  setUpAll(() async {
    await initCoverTestEnvironment(unused, sources: [src]);
    if (hasNativeHttp) await server.start();
  });

  tearDownAll(() async {
    setCoverRequestTimeout(null);
    await unused.stop();
    if (hasNativeHttp) await server.stop();
  });

  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    setCoverRequestTimeout(_short);
  });

  tearDown(() => setCoverRequestTimeout(null));

  var counter = 0;
  String path(String name, {RawMode mode = RawMode.immediate, int shade = 0}) {
    final p = '/t/${counter++}-$name.png';
    server.images[p] = png(shade, width: 64, height: 64);
    server.modes[p] = mode;
    return p;
  }

  int activeSlots() => ImageDownloader.coverRequestLimiter.active;
  int waiting() => ImageDownloader.coverRequestLimiter.waiting;

  Future<void> eventually(bool Function() condition, String what) async {
    final sw = Stopwatch()..start();
    while (!condition()) {
      if (sw.elapsed > _bound) fail('timed out waiting for: $what');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  /// A direct cover load; completes with the error (or null on success).
  Future<Object?> load(String p, {String cid = 'k'}) =>
      ImageDownloader.loadCoverThumbnail(
        server.url(p),
        src.key,
        cid,
        checkStop: () {},
      ).then<Object?>((_) => null, onError: (Object e) => e);

  Future<Uint8List> loadBytes(String p, {String cid = 'k'}) =>
      ImageDownloader.loadCoverThumbnail(
        server.url(p),
        src.key,
        cid,
        checkStop: () {},
      );

  Future<void> closedByClient(HeldRequest h, String what) => h.closedByClient
      .timeout(_bound, onTimeout: () => fail('still open: $what'));

  /// No held request or busy slot is left over from an earlier test.
  Future<void> reset() async {
    await server.releaseAll();
    await eventually(() => activeSlots() == 0, 'idle limiter');
    expect(waiting(), 0);
  }

  Future<void> ignoringStopErrors(Future<void> Function() body) async {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('ImageLoadingStopException')) {
        return;
      }
      previous?.call(details);
    };
    try {
      await body();
    } finally {
      FlutterError.onError = previous;
    }
  }

  testWidgets(
    'A: 8 requests that never get headers are ended by the timeout, give '
    'their slots back, and a healthy request completes',
    (tester) async {
      await tester.runAsync(() async {
        await reset();
        final stuckPaths = [
          for (var i = 0; i < _limit; i++)
            path('a-stuck-$i', mode: RawMode.holdHeaders),
        ];
        final healthy = path('a-healthy', shade: 7);
        final stuck = [for (final p in stuckPaths) load(p, cid: p)];
        await server.until(() => stuckPaths.every((p) => server.count(p) == 1));
        expect(activeSlots(), _limit);
        // The ninth load queues behind them; nobody releases the server side.
        final healthyLoad = loadBytes(healthy);
        await eventually(() => waiting() == 1, 'healthy load queued');
        for (final p in stuckPaths) {
          final h = server.heldFor(p).single;
          expect(h.finished, isFalse);
          await closedByClient(h, p);
        }
        for (final f in stuck) {
          expect(await f, isNotNull, reason: 'stuck load must fail');
        }
        final bytes = await healthyLoad.timeout(_bound);
        expect(bytes, isNotEmpty);
        expect(server.count(healthy), 1);
        await eventually(() => activeSlots() == 0, 'slots returned');
        expect(waiting(), 0);
      });
    },
    skip: !hasNativeHttp,
  );

  testWidgets(
    'B: headers arrived but the body stalls: ended by the timeout, slot '
    'returned, nothing cached, and a retry succeeds',
    (tester) async {
      await tester.runAsync(() async {
        await reset();
        final p = path('b-stall', mode: RawMode.stallBody, shade: 20);
        final key = ImageDownloader.thumbnailCacheKey(
          server.url(p),
          src.key,
          'k',
        );
        final first = load(p);
        await server.until(() => server.count(p) == 1);
        await closedByClient(server.heldFor(p).single, p);
        expect(await first, isNotNull);
        await eventually(() => activeSlots() == 0, 'slot returned');
        expect(
          await CacheManager().findCache(key),
          isNull,
          reason: 'a timed-out partial body must not become a valid cache',
        );
        // The source recovers: same URL, same key, now a complete response.
        server.modes[p] = RawMode.immediate;
        final bytes = await loadBytes(p);
        expect(bytes, server.images[p]);
        final cached = await CacheManager().findCache(key);
        expect(cached, isNotNull);
        expect(await cached!.readAsBytes(), server.images[p]);
        expect(server.count(p), 2);
        expect(activeSlots(), 0);
      });
    },
    skip: !hasNativeHttp,
  );

  testWidgets(
    'C: headers arriving around the deadline: every request ends, no crash, '
    'each slot returned exactly once (probabilistic ordering probe)',
    (tester) async {
      await tester.runAsync(() async {
        await reset();
        const offsetsMs = [-60, -30, -10, 0, 10, 30, 60, 120];
        for (final offset in offsetsMs) {
          final p = path('c-race-$offset', mode: RawMode.holdHeaders);
          final f = load(p);
          await server.until(() => server.count(p) == 1);
          final h = server.heldFor(p).single;
          await Future<void>.delayed(
            Duration(milliseconds: _short.inMilliseconds + offset),
          );
          await h.sendHeadersAndStall();
          // Whichever came first, the request must end by itself.
          await closedByClient(h, 'race offset $offset');
          expect(await f, isNotNull, reason: 'offset $offset');
          await eventually(() => activeSlots() == 0, 'slot returned');
          expect(waiting(), 0);
        }
      });
    },
    skip: !hasNativeHttp,
  );

  testWidgets(
    'D: cancel racing with the timeout: no panic, connection ended, slots '
    'back (probabilistic ordering probe)',
    (tester) async {
      await ignoringStopErrors(() async {
        for (final mode in [RawMode.holdHeaders, RawMode.stallBody]) {
          for (final offset in [-80, -20, 0, 20, 80]) {
            late String p;
            late Resolution r;
            await tester.runAsync(() async {
              await reset();
              p = path('d-$mode-$offset', mode: mode, shade: 3);
              r = Resolution(
                CachedImageProvider(
                  server.url(p),
                  sourceKey: src.key,
                  cid: 'd$offset',
                  fallbackToLocalCover: false,
                ),
              );
              await server.until(() => server.count(p) == 1);
              await Future<void>.delayed(
                Duration(milliseconds: _short.inMilliseconds + offset),
              );
              r.cancel();
            });
            tester.binding.scheduleFrame();
            await tester.pump();
            await tester.runAsync(() async {
              // A cancel before the headers keeps the request open until they
              // arrive or the timeout ends it; either way it must end.
              await closedByClient(server.heldFor(p).first, '$mode $offset');
              await eventually(() => activeSlots() == 0, 'slot returned');
              expect(waiting(), 0);
              expect(r.isDone, isFalse);
            });
          }
        }
      });
    },
    skip: !hasNativeHttp,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'E: normal, shared and cached covers and non-cover requests behave as '
    'before',
    (tester) async {
      await tester.runAsync(() async {
        await reset();
        // Normal request, two consumers share one request.
        final p = path('e-normal', shade: 40);
        final results = await Future.wait([loadBytes(p), loadBytes(p)]);
        expect(results[0], server.images[p]);
        expect(results[1], server.images[p]);
        expect(server.count(p), 1);
        // Cache hit: no request, no slot.
        expect(await loadBytes(p), server.images[p]);
        expect(server.count(p), 1);
        await eventually(() => activeSlots() == 0, 'slots returned');

        // A non-cover request (no timeout option) is not ended by the short
        // cover timeout: it stays open well past it and can still finish.
        final slow = path('e-noncover', mode: RawMode.holdHeaders, shade: 50);
        final dio = AppDio(BaseOptions(responseType: ResponseType.stream));
        final response = dio.request<ResponseBody>(server.url(slow));
        await server.until(() => server.count(slow) == 1);
        final h = server.heldFor(slow).single;
        await Future<void>.delayed(_short * 4);
        expect(h.isClosedByClient, isFalse);
        await h.release();
        final body = await response.timeout(_bound);
        final bytes = BytesBuilder();
        await for (final c in body.data!.stream) {
          bytes.add(c);
        }
        expect(bytes.takeBytes(), server.images[slow]);
      });
    },
    skip: !hasNativeHttp,
  );

  testWidgets(
    'F: the image provider keeps its retries; each attempt gets its own '
    'timeout (4 attempts, 2 s + 4 s + 8 s waits)',
    (tester) async {
      await tester.runAsync(() async {
        await reset();
        setCoverRequestTimeout(const Duration(milliseconds: 300));
        final p = path('f-retry', mode: RawMode.holdHeaders);
        final sw = Stopwatch()..start();
        final r = Resolution(
          CachedImageProvider(
            server.url(p),
            sourceKey: src.key,
            cid: 'f',
            fallbackToLocalCover: false,
          ),
        );
        final error = await r.result;
        r.dispose();
        sw.stop();
        expect(error, isNotNull);
        expect(server.count(p), 4, reason: 'first attempt + 3 retries');
        expect(sw.elapsed, greaterThan(const Duration(seconds: 14)));
        expect(sw.elapsed, lessThan(const Duration(seconds: 30)));
        for (final h in server.heldFor(p)) {
          expect(h.isClosedByClient, isTrue);
        }
        await eventually(() => activeSlots() == 0, 'slot returned');
      });
    },
    skip: !hasNativeHttp,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'G: with the production setting a silent request ends after about 30 s',
    (tester) async {
      await tester.runAsync(() async {
        await reset();
        setCoverRequestTimeout(null);
        final p = path('g-prod', mode: RawMode.holdHeaders);
        final sw = Stopwatch()..start();
        final f = load(p);
        await server.until(() => server.count(p) == 1);
        final started = sw.elapsed;
        await server
            .heldFor(p)
            .single
            .closedByClient
            .timeout(
              const Duration(seconds: 50),
              onTimeout: () => fail('not ended within 50 s'),
            );
        final ended = sw.elapsed - started;
        expect(await f, isNotNull);
        expect(ended, greaterThan(const Duration(seconds: 29)));
        expect(ended, lessThan(const Duration(seconds: 40)));
        await eventually(() => activeSlots() == 0, 'slot returned');
      });
    },
    skip: !hasNativeHttp,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
