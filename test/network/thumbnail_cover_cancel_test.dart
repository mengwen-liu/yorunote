// Cancellation of cover loads through the real provider path:
// ImageProvider.resolve -> CachedImageProvider / HistoryImageProvider ->
// shared cover load -> RequestLimiter -> AppDio -> RHttpAdapter -> rhttp.
//
// The server hands every request to the test as a raw socket, so the test
// decides when headers and body bytes are sent, and sees whether the client
// closed the connection. A load is cancelled the way the app cancels it: the
// image is evicted from ImageCache and the next frame releases it.
// Timeouts only turn a hang into a failure; they never decide the order.

import 'dart:async';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/image_provider/cached_image.dart';
import 'package:venera/foundation/image_provider/history_image_provider.dart';
import 'package:venera/network/images.dart';

import 'raw_image_server.dart';
import 'thumbnail_test_support.dart';

const _limit = 8;
const _closeTimeout = Duration(seconds: 10);

void main() {
  final unused = CoverServer();
  final server = RawImageServer();
  final src = testSource('thumb_cancel_src');

  setUpAll(() async {
    await initCoverTestEnvironment(unused, sources: [src]);
    if (hasNativeHttp) await server.start();
  });

  tearDownAll(() async {
    await unused.stop();
    if (hasNativeHttp) await server.stop();
  });

  setUp(() => PaintingBinding.instance.imageCache.clear());

  String path(String name, {RawMode mode = RawMode.immediate, int shade = 0}) {
    final p = '/c/$name.png';
    server.images[p] = png(shade, width: 64, height: 64);
    server.modes[p] = mode;
    return p;
  }

  CachedImageProvider cover(String p, {String cid = 'k', bool fb = false}) =>
      CachedImageProvider(
        server.url(p),
        sourceKey: src.key,
        cid: cid,
        fallbackToLocalCover: fb,
      );

  /// Polls a plain counter until it holds (no server event to wait on).
  Future<void> eventually(bool Function() condition, String what) async {
    final sw = Stopwatch()..start();
    while (!condition()) {
      if (sw.elapsed > const Duration(seconds: 10)) {
        fail('timed out waiting for: $what');
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  int activeSlots() => ImageDownloader.coverRequestLimiter.active;

  /// Leaves no held request or busy slot behind from an earlier test.
  Future<void> reset() async {
    await server.releaseAll();
    await eventually(() => activeSlots() == 0, 'idle limiter');
    PaintingBinding.instance.imageCache.clear();
  }

  /// ImageCache gives up evicted images after the next frame, as in the app.
  Future<void> frame(WidgetTester tester) async {
    tester.binding.scheduleFrame();
    await tester.pump();
  }

  /// BaseImageProvider reports (silently in the app) a stop error for a
  /// cancelled load; only that error is ignored here.
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

  testWidgets('A: a request cancelled before its headers is torn down when '
      'they arrive, and only then frees its slot', (tester) async {
    // Tearing a request down while it waits for its headers is not safe
    // with rhttp 0.15.1 (see RHttpAdapter.fetch), so it stays open and keeps
    // its slot until the headers arrive; then it is closed at once.
    await ignoringStopErrors(() async {
      late List<Resolution> stuck;
      late List<String> stuckPaths;
      await tester.runAsync(() async {
        await reset();
        stuckPaths = [
          for (var i = 0; i < _limit; i++)
            path('a-stuck-$i', mode: RawMode.holdHeaders),
        ];
        stuck = [for (final p in stuckPaths) Resolution(cover(p))];
        await server.until(() => stuckPaths.every((p) => server.count(p) == 1));
        expect(activeSlots(), _limit);
        for (final r in stuck) {
          r.cancel();
        }
      });
      await frame(tester);
      await tester.runAsync(() async {
        // Still waiting for headers: open, and the slots stay accounted for.
        await Future<void>.delayed(const Duration(milliseconds: 300));
        for (final p in stuckPaths) {
          expect(server.heldFor(p).single.isClosedByClient, isFalse);
        }
        expect(activeSlots(), _limit);
        final healthyPath = path('a-healthy', shade: 9);
        final healthy = Resolution(cover(healthyPath));
        // Headers arrive (the body is held back): each request must be
        // closed by the client without reading the rest.
        for (final p in stuckPaths) {
          final h = server.heldFor(p).single;
          await h.sendHeadersAndStall();
          await h.closedByClient.timeout(
            _closeTimeout,
            onTimeout: () => fail('request $p still open after its headers'),
          );
          expect(h.isClosedByClient, isTrue);
        }
        expect(await healthy.result, isNull);
        healthy.dispose();
        expect(server.count(healthyPath), 1);
        await eventually(() => activeSlots() == 0, 'slots returned');
        expect(stuck.every((r) => !r.isDone), isTrue);
      });
    });
  }, skip: !hasNativeHttp);

  testWidgets(
    'B: a response stalled inside the body is torn down on cancel',
    (tester) async {
      await ignoringStopErrors(() async {
        late Resolution r;
        late String p;
        await tester.runAsync(() async {
          await reset();
          p = path('b-stall', mode: RawMode.stallBody, shade: 20);
          final firstChunk = Completer<void>();
          r = Resolution(cover(p));
          final chunks = ImageStreamListener(
            (_, _) {},
            onChunk: (_) {
              if (!firstChunk.isCompleted) firstChunk.complete();
            },
          );
          r.stream.addListener(chunks);
          // Headers and the first half of the body have reached the provider.
          await firstChunk.future.timeout(const Duration(seconds: 20));
          expect(activeSlots(), 1);
          r.stream.removeListener(chunks);
          r.cancel();
        });
        await frame(tester);
        await tester.runAsync(() async {
          final h = server.heldFor(p).single;
          await h.closedByClient.timeout(
            _closeTimeout,
            onTimeout: () => fail('stalled body still open after cancel'),
          );
          expect(h.isClosedByClient, isTrue);
          await eventually(() => activeSlots() == 0, 'slot returned');
          expect(r.isDone, isFalse);
        });
      });
    },
    skip: !hasNativeHttp,
  );

  testWidgets(
    'C: queued cancel, error and success return each slot once',
    (tester) async {
      await ignoringStopErrors(() async {
        late List<String> heldPaths;
        late List<Resolution> held;
        late Resolution q0, q1, qErr, qOk;
        late String p0, p1, pErr, pOk;
        await tester.runAsync(() async {
          await reset();
          heldPaths = [
            for (var i = 0; i < _limit; i++)
              path('c-held-$i', mode: RawMode.holdHeaders, shade: 30 + i),
          ];
          held = [for (final p in heldPaths) Resolution(cover(p))];
          await server.until(
            () => heldPaths.every((p) => server.count(p) == 1),
          );
          p0 = path('c-q0');
          p1 = path('c-q1');
          pErr = path('c-qerr', mode: RawMode.status);
          server.statusCodes[pErr] = 500;
          pOk = path('c-qok', shade: 40);
          q0 = Resolution(cover(p0));
          q1 = Resolution(cover(p1));
          qErr = Resolution(cover(pErr));
          qOk = Resolution(cover(pOk));
          await eventually(
            () => ImageDownloader.coverRequestLimiter.waiting >= 4,
            'four queued loads',
          );
          q0.cancel();
          q1.cancel();
        });
        await frame(tester);
        await tester.runAsync(() async {
          for (final p in heldPaths) {
            await server.heldFor(p).single.release();
          }
          expect(
            await Future.wait(held.map((r) => r.result)),
            everyElement(isNull),
          );
          expect(await qOk.result, isNull);
          expect(await qErr.result, isNotNull);
          expect(server.count(p0), 0, reason: 'cancelled while queued');
          expect(server.count(p1), 0, reason: 'cancelled while queued');
          await eventually(() => activeSlots() == 0, 'all slots back');
          expect(ImageDownloader.coverRequestLimiter.waiting, 0);
          for (final r in [...held, qOk, qErr]) {
            r.dispose();
          }
        });
      });
    },
    skip: !hasNativeHttp,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'D1: one cancelled consumer does not stop a shared request',
    (tester) async {
      await ignoringStopErrors(() async {
        late Resolution tile;
        late Resolution history;
        late String p;
        await tester.runAsync(() async {
          await reset();
          p = path('d1-shared', mode: RawMode.holdHeaders, shade: 50);
          final url = server.url(p);
          tile = Resolution(
            CachedImageProvider(url, sourceKey: src.key, cid: 'd1'),
          );
          history = Resolution(
            HistoryImageProvider(testHistory('d1', src, url)),
          );
          await server.until(() => server.count(p) == 1);
          tile.cancel();
        });
        await frame(tester);
        await tester.runAsync(() async {
          final h = server.heldFor(p).single;
          expect(h.isClosedByClient, isFalse);
          await h.release();
          expect(await history.result, isNull);
          expect(tile.isDone, isFalse);
          expect(server.count(p), 1);
          history.dispose();
        });
      });
    },
    skip: !hasNativeHttp,
  );

  testWidgets(
    'D2: a shared request ends when all its consumers cancel',
    (tester) async {
      await ignoringStopErrors(() async {
        late String p;
        await tester.runAsync(() async {
          await reset();
          p = path('d2-shared', mode: RawMode.holdHeaders, shade: 60);
          final url = server.url(p);
          final a = Resolution(
            CachedImageProvider(url, sourceKey: src.key, cid: 'd2'),
          );
          final b = Resolution(
            HistoryImageProvider(testHistory('d2', src, url)),
          );
          await server.until(() => server.count(p) == 1);
          a.cancel();
          b.cancel();
        });
        await frame(tester);
        await tester.runAsync(() async {
          final h = server.heldFor(p).single;
          await h.sendHeadersAndStall();
          await h.closedByClient.timeout(
            _closeTimeout,
            onTimeout: () => fail('shared request still open'),
          );
          expect(h.isClosedByClient, isTrue);
          await eventually(() => activeSlots() == 0, 'slot returned');
        });
      });
    },
    skip: !hasNativeHttp,
  );

  testWidgets(
    'D3: a consumer arriving after all others cancelled starts anew',
    (tester) async {
      await ignoringStopErrors(() async {
        late String p;
        late Resolution late_;
        await tester.runAsync(() async {
          await reset();
          p = path('d3-shared', mode: RawMode.holdHeaders, shade: 70);
          final url = server.url(p);
          final a = Resolution(
            CachedImageProvider(url, sourceKey: src.key, cid: 'd3'),
          );
          final b = Resolution(
            HistoryImageProvider(testHistory('d3', src, url)),
          );
          await server.until(() => server.count(p) == 1);
          a.cancel();
          b.cancel();
        });
        await frame(tester);
        await tester.runAsync(() async {
          // Joins right after the cancellation, before anything is released.
          late_ = Resolution(
            CachedImageProvider(
              server.url(p),
              sourceKey: src.key,
              cid: 'd3',
              fallbackToLocalCover: true,
            ),
          );
          // It must not join the abandoned request: a new one goes out.
          await server.until(() => server.count(p) == 2);
          final old = server.heldFor(p).first;
          final fresh = server.heldFor(p).last;
          await old.sendHeadersAndStall();
          await old.closedByClient.timeout(
            _closeTimeout,
            onTimeout: () => fail('abandoned request still open'),
          );
          expect(old.isClosedByClient, isTrue);
          expect(fresh.isClosedByClient, isFalse, reason: 'not cancelled');
          await fresh.release();
          expect(await late_.result, isNull);
          late_.dispose();
          await eventually(() => activeSlots() == 0, 'slots returned');
        });
      });
    },
    skip: !hasNativeHttp,
  );

  testWidgets(
    'E: cancelling while headers arrive never aborts the process',
    (tester) async {
      // rhttp 0.15.1 aborts the process when a request is dropped while its
      // header callback is in flight; loads cancelled just as their headers
      // arrive must be handled without such a drop.
      await ignoringStopErrors(() async {
        for (var round = 0; round < 20; round++) {
          late List<String> ps;
          late List<Resolution> rs;
          await tester.runAsync(() async {
            await reset();
            ps = [
              for (var i = 0; i < 4; i++)
                path('e-race-$round-$i', mode: RawMode.holdHeaders),
            ];
            rs = [for (final p in ps) Resolution(cover(p))];
            await server.until(() => ps.every((p) => server.count(p) == 1));
            for (final r in rs) {
              r.cancel();
            }
          });
          await frame(tester);
          await tester.runAsync(() async {
            // Headers and the cancellation meet: release everything at once.
            await Future.wait([
              for (final p in ps) server.heldFor(p).single.release(),
            ]);
            await eventually(() => activeSlots() == 0, 'slots returned');
          });
        }
        await tester.runAsync(() async {
          final p = path('e-after', shade: 80);
          final r = Resolution(cover(p));
          expect(await r.result, isNull, reason: 'process still healthy');
          r.dispose();
        });
      });
    },
    skip: !hasNativeHttp,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
