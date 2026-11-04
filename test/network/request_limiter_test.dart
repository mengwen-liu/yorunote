// Unit tests of RequestLimiter, the event-driven limit of cover requests.
// No timers are used: a waiter must get a freed slot within microtasks.

import 'package:flutter_test/flutter_test.dart';
import 'package:venera/network/images.dart';
import 'package:venera/network/request_limiter.dart';

/// Runs pending microtasks only; a timer-based (polling) hand-off would not
/// complete here.
Future<void> _microtasks() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.value();
  }
}

void main() {
  test('cover requests are limited to 8', () {
    expect(ImageDownloader.maxCoverRequests, 8);
    expect(ImageDownloader.coverRequestLimiter.maxConcurrent, 8);
  });

  test('grants up to the limit, then hands slots over in FIFO order', () async {
    final limiter = RequestLimiter(2);
    final a = await limiter.acquire();
    final b = await limiter.acquire();
    expect(limiter.active, 2);

    final order = <String>[];
    final c = limiter.acquire().then((r) {
      order.add('c');
      return r;
    });
    final d = limiter.acquire().then((r) {
      order.add('d');
      return r;
    });
    await _microtasks();
    expect(order, isEmpty);
    expect(limiter.waiting, 2);

    a();
    await _microtasks();
    expect(order, ['c']);
    expect(limiter.active, 2);

    b();
    await _microtasks();
    expect(order, ['c', 'd']);
    (await c)();
    (await d)();
    expect(limiter.active, 0);
    expect(limiter.waiting, 0);
  });

  test('a cancelled waiter is skipped and takes no slot', () async {
    final limiter = RequestLimiter(1);
    final first = await limiter.acquire();
    var cancelled = false;
    final skipped = limiter.acquire(isCancelled: () => cancelled);
    final next = limiter.acquire();
    cancelled = true;

    first();
    await expectLater(skipped, throwsA(isA<RequestCancelledException>()));
    final release = await next;
    expect(limiter.active, 1);
    release();
    expect(limiter.active, 0);
  });

  test('releasing twice frees only one slot', () async {
    final limiter = RequestLimiter(1);
    final release = await limiter.acquire();
    final waiter = limiter.acquire();
    release();
    release();
    final second = await waiter;
    expect(limiter.active, 1);
    final third = limiter.acquire();
    await _microtasks();
    expect(limiter.waiting, 1, reason: 'the double release granted nothing');
    second();
    (await third)();
    expect(limiter.active, 0);
  });

  test('a failing isCancelled callback does not lose the slot', () async {
    final limiter = RequestLimiter(1);
    final first = await limiter.acquire();
    final waiter = limiter.acquire(isCancelled: () => throw StateError('x'));
    first();
    (await waiter)();
    expect(limiter.active, 0);
  });

  test('slots come back after work fails', () async {
    final limiter = RequestLimiter(3);
    Future<void> failingWork() async {
      final release = await limiter.acquire();
      try {
        await Future<void>.value();
        throw Exception('request failed');
      } finally {
        release();
      }
    }

    final results = await Future.wait([
      for (var i = 0; i < 10; i++)
        failingWork().then((_) => 0, onError: (_) => 1),
    ]);
    expect(results.reduce((a, b) => a + b), 10);
    expect(limiter.active, 0);
    expect(limiter.waiting, 0);
  });
}
