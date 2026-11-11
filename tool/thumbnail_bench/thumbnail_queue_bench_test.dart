// Host benchmark of cover (thumbnail) loading through ImageProvider.resolve.
//
// Run explicitly (it is not part of `flutter test` under test/):
//   FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR=<dir of librhttp.so> \
//   THUMB_BENCH_OUT=<file.json> THUMB_BENCH_LABEL=<label> \
//   flutter test --no-pub tool/thumbnail_bench/thumbnail_queue_bench_test.dart
//
// Only public provider APIs and ImageDownloader.loadThumbnail are used, so the
// same file runs unchanged against the baseline and the candidate. Results are
// host (x86_64 Linux, loopback HTTP) timings; they say nothing about frame
// rate or power use on a phone or tablet.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/image_provider/cached_image.dart';
import 'package:venera/foundation/image_provider/history_image_provider.dart';
import 'package:venera/network/images.dart';

import '../../test/network/thumbnail_test_support.dart';

const _warmup = 1;
const _samples = 7;
const _latency = Duration(milliseconds: 40);

double _ms(int us) => us / 1000.0;

Map<String, dynamic> _stats(List<double> xs) {
  if (xs.isEmpty) return {'n': 0};
  final s = [...xs]..sort();
  double pct(double p) {
    final i = (p * (s.length - 1)).round();
    return s[i];
  }

  return {
    'n': s.length,
    'median': pct(0.5),
    'p95': pct(0.95),
    'min': s.first,
    'max': s.last,
  };
}

void main() {
  final server = CoverServer();
  final src = testSource('thumb_bench_src');
  final out = Platform.environment['THUMB_BENCH_OUT'];
  final label = Platform.environment['THUMB_BENCH_LABEL'] ?? 'unlabelled';
  final cover = png(1, width: 160, height: 240);
  final results = <String, dynamic>{
    'label': label,
    'samples': _samples,
    'warmup': _warmup,
    'server_latency_ms': _latency.inMilliseconds,
    'fixture': 'synthetic grayscale PNG 160x240, ${cover.length} bytes',
    'platform': '${Platform.operatingSystem} ${Platform.version}',
    'scenarios': <String, dynamic>{},
  };
  var run = 0;

  setUpAll(() async {
    await initCoverTestEnvironment(server, sources: [src]);
  });

  tearDownAll(() async {
    await server.stop();
    if (out != null) {
      await File(
        out,
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(results));
    }
  });

  String path(String scenario, int i) => '/b/${run++}/$scenario/$i.png';

  CachedImageProvider cp(String p) =>
      CachedImageProvider(server.url(p), sourceKey: src.key, cid: 'b');

  /// Runs [body] _warmup + _samples times; returns the measured samples.
  Future<List<Map<String, dynamic>>> repeat(
    Future<Map<String, dynamic>> Function() body,
  ) async {
    final samples = <Map<String, dynamic>>[];
    for (var i = 0; i < _warmup + _samples; i++) {
      PaintingBinding.instance.imageCache.clear();
      await server.drain();
      final r = await body();
      if (i >= _warmup) samples.add(r);
    }
    return samples;
  }

  testWidgets('cold grid: 32 misses at once', (tester) async {
    await tester.runAsync(() async {
      final raw = await repeat(() async {
        server.delay = _latency;
        server.resetCounters();
        final ps = [for (var i = 0; i < 32; i++) path('cold', i)];
        for (final p in ps) {
          server.images[p] = cover;
        }
        final t0 = server.clock.elapsedMicroseconds;
        final rs = [for (final p in ps) Resolution(cp(p), clock: server.clock)];
        final errors = await Future.wait(rs.map((r) => r.result));
        final waits = <double>[];
        final done = <double>[];
        for (var i = 0; i < rs.length; i++) {
          final arrival = server.arrivals[Uri.parse(server.url(ps[i])).path]!;
          waits.add(_ms(arrival.first - rs[i].startUs!));
          done.add(_ms(rs[i].doneUs! - rs[i].startUs!));
        }
        for (final r in rs) {
          r.dispose();
        }
        return {
          'errors': errors.where((e) => e != null).length,
          'http_requests': server.total,
          'peak_inflight': server.peakInflight,
          'first_display_ms': done.reduce((a, b) => a < b ? a : b),
          'all_done_ms': _ms(server.clock.elapsedMicroseconds - t0),
          'queue_wait_ms': waits,
          'completion_ms': done,
        };
      });
      results['scenarios']['cold_grid_32'] = {
        'raw': raw,
        'http_requests': raw.map((r) => r['http_requests']).toList(),
        'peak_inflight': raw.map((r) => r['peak_inflight']).toList(),
        'errors': raw.map((r) => r['errors']).toList(),
        'first_display_ms': _stats([
          for (final r in raw) r['first_display_ms'] as double,
        ]),
        'all_done_ms': _stats([
          for (final r in raw) r['all_done_ms'] as double,
        ]),
        'queue_wait_ms': _stats([
          for (final r in raw) ...(r['queue_wait_ms'] as List<double>),
        ]),
        'completion_ms': _stats([
          for (final r in raw) ...(r['completion_ms'] as List<double>),
        ]),
      };
    });
  }, skip: !hasNativeHttp);

  testWidgets('cache hits while the network queue is full', (tester) async {
    await tester.runAsync(() async {
      const holdFor = Duration(milliseconds: 1500);
      final raw = await repeat(() async {
        server.resetCounters();
        server.holdResponses = true;
        final busy = [for (var i = 0; i < 12; i++) path('busy', i)];
        for (final p in busy) {
          server.images[p] = cover;
        }
        final hits = [for (var i = 0; i < 16; i++) path('hit', i)];
        for (final p in hits) {
          await CacheManager().writeCache(
            thumbDiskKey(server.url(p), src.key, 'b'),
            cover,
          );
        }
        final held = [for (final p in busy) Resolution(cp(p))];
        await server.inflightAtLeast(8).timeout(const Duration(seconds: 20));
        final rs = [
          for (final p in hits) Resolution(cp(p), clock: server.clock),
        ];
        final t0 = server.clock.elapsedMicroseconds;
        await Future<void>.delayed(holdFor);
        final doneWhileHeld = rs.where((r) => r.isDone).length;
        server.holdResponses = false;
        server.releaseAll();
        final errors = await Future.wait(rs.map((r) => r.result));
        await Future.wait(held.map((r) => r.result));
        final lat = [for (final r in rs) _ms(r.doneUs! - r.startUs!)];
        for (final r in [...held, ...rs]) {
          r.dispose();
        }
        return {
          'errors': errors.where((e) => e != null).length,
          'hits_done_while_network_held': doneWhileHeld,
          'hit_requests': [
            for (final p in hits) server.count(p),
          ].fold<int>(0, (a, b) => a + b),
          'network_held_ms': _ms(server.clock.elapsedMicroseconds - t0),
          'hit_completion_ms': lat,
        };
      });
      results['scenarios']['cache_hits_with_full_queue'] = {
        'raw': raw,
        'hits_total_per_sample': 16,
        'hits_done_while_network_held': [
          for (final r in raw) r['hits_done_while_network_held'],
        ],
        'hit_http_requests': [for (final r in raw) r['hit_requests']],
        'hit_completion_ms': _stats([
          for (final r in raw) ...(r['hit_completion_ms'] as List<double>),
        ]),
      };
    });
  }, skip: !hasNativeHttp);

  testWidgets('slot hand-off after one response', (tester) async {
    await tester.runAsync(() async {
      final raw = await repeat(() async {
        server.resetCounters();
        server.holdResponses = true;
        final ps = [for (var i = 0; i < 16; i++) path('handoff', i)];
        for (final p in ps) {
          server.images[p] = cover;
        }
        final rs = [for (final p in ps) Resolution(cp(p))];
        await server.inflightAtLeast(8).timeout(const Duration(seconds: 20));
        await Future<void>.delayed(const Duration(milliseconds: 300));
        final handoff = <double>[];
        for (var k = 0; k < 6; k++) {
          final next = server.nextArrival();
          final t = server.clock.elapsedMicroseconds;
          server.release();
          // Event driven: completes when the next queued request arrives.
          final arrival = await next.timeout(const Duration(seconds: 10));
          handoff.add(_ms(arrival - t));
        }
        server.holdResponses = false;
        server.releaseAll();
        final errors = await Future.wait(rs.map((r) => r.result));
        for (final r in rs) {
          r.dispose();
        }
        return {
          'errors': errors.where((e) => e != null).length,
          'handoff_ms': handoff,
        };
      });
      results['scenarios']['slot_handoff'] = {
        'raw': raw,
        'handoff_ms': _stats([
          for (final r in raw) ...(r['handoff_ms'] as List<double>),
        ]),
      };
    });
  }, skip: !hasNativeHttp);

  testWidgets('history and cover tiles of the same comics', (tester) async {
    await tester.runAsync(() async {
      final raw = await repeat(() async {
        server.delay = _latency;
        server.resetCounters();
        final ps = [for (var i = 0; i < 10; i++) path('dup', i)];
        final rs = <Resolution>[];
        for (var i = 0; i < ps.length; i++) {
          server.images[ps[i]] = cover;
          final url = server.url(ps[i]);
          rs.add(
            Resolution(
              CachedImageProvider(url, sourceKey: src.key, cid: 'd$i'),
            ),
          );
          rs.add(
            Resolution(HistoryImageProvider(testHistory('d$i', src, url))),
          );
        }
        final errors = await Future.wait(rs.map((r) => r.result));
        for (final r in rs) {
          r.dispose();
        }
        return {
          'errors': errors.where((e) => e != null).length,
          'http_requests': server.total,
          'distinct_covers': ps.length,
        };
      });
      results['scenarios']['history_and_cover_same_comic'] = {
        'raw': raw,
        'http_requests': [for (final r in raw) r['http_requests']],
      };
    });
  }, skip: !hasNativeHttp);

  testWidgets('valid cache hit: provider path vs full stream', (tester) async {
    await tester.runAsync(() async {
      final raw = await repeat(() async {
        server.resetCounters();
        final p1 = path('hit-provider', 0);
        final p2 = path('hit-stream', 0);
        for (final p in [p1, p2]) {
          server.images[p] = cover;
          await CacheManager().writeCache(
            thumbDiskKey(server.url(p), src.key, 'b'),
            cover,
          );
        }
        final err = await resolveOnce(cp(p1));
        var yields = 0;
        await for (final e in ImageDownloader.loadThumbnail(
          server.url(p2),
          src.key,
          'b',
        )) {
          if (e.imageBytes != null) yields++;
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return {
          'provider_error': err?.toString(),
          'provider_http_requests': server.count(p1),
          'full_stream_http_requests': server.count(p2),
          'full_stream_image_events': yields,
        };
      });
      results['scenarios']['cache_hit_paths'] = {'raw': raw};
    });
  }, skip: !hasNativeHttp);

  testWidgets('broken cache entries: first load and one retry', (tester) async {
    await tester.runAsync(() async {
      final raw = await repeat(() async {
        server.resetCounters();
        final ps = [for (var i = 0; i < 6; i++) path('broken', i)];
        for (var i = 0; i < ps.length; i++) {
          server.images[ps[i]] = cover;
          await CacheManager().writeCache(
            thumbDiskKey(server.url(ps[i]), src.key, 'b'),
            i.isEven ? corruptPng : <int>[],
          );
        }
        final first = await Future.wait(ps.map((p) => resolveOnce(cp(p))));
        final retry = await Future.wait(ps.map((p) => resolveOnce(cp(p))));
        return {
          'first_load_errors': first.where((e) => e != null).length,
          'retry_errors': retry.where((e) => e != null).length,
          'http_requests': server.total,
          'entries': ps.length,
        };
      });
      results['scenarios']['broken_cache_retry'] = {'raw': raw};
    });
  }, skip: !hasNativeHttp);
}
