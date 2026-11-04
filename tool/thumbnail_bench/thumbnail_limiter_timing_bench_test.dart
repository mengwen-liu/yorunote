// Candidate-only timing breakdown of the cold-grid scenario of the r2
// benchmark, using ImageDownloader.debugCoverLoadEvent (not in the start
// version, so there is no baseline counterpart for these segments).
//
// Per image (all 32 are cache misses):
//   resolve_to_enqueue_ms     ImageProvider.resolve -> waiting for a slot
//   limiter_wait_ms           waiting for a slot -> slot granted
//   granted_to_request_ms     slot granted -> request handed to Dio
//                             (includes the re-check of the disk cache)
//   request_to_arrival_ms     request handed to Dio -> arrival at the server
//
// Run explicitly:
//   FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR=<dir of librhttp.so> \
//   THUMB_BENCH_OUT=<file.json> THUMB_BENCH_LABEL=<label> \
//   flutter test --no-pub tool/thumbnail_bench/thumbnail_limiter_timing_bench_test.dart

// This benchmark is a test run from tool/; the timing probe is test-only.
// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:convert';
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/image_provider/cached_image.dart';
import 'package:venera/network/images.dart';

import '../../test/network/thumbnail_test_support.dart';
import 'bench_stats.dart';

const _warmup = 1;
const _samples = 7;
const _latency = Duration(milliseconds: 40);

double _ms(int us) => us / 1000.0;

void main() {
  final server = CoverServer();
  final src = testSource('thumb_timing_src');
  final out = Platform.environment['THUMB_BENCH_OUT'];
  final label = Platform.environment['THUMB_BENCH_LABEL'] ?? 'unlabelled';
  final cover = png(1, width: 160, height: 240);
  final runs = <Map<String, dynamic>>[];
  var run = 0;

  setUpAll(() async {
    await initCoverTestEnvironment(server, sources: [src]);
  });

  tearDownAll(() async {
    ImageDownloader.debugCoverLoadEvent = null;
    await server.stop();
    if (out != null) {
      final metrics = [
        'resolve_to_enqueue_ms',
        'limiter_wait_ms',
        'granted_to_request_ms',
        'request_to_arrival_ms',
      ];
      await File(out).writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'label': label,
          'samples': _samples,
          'warmup': _warmup,
          'server_latency_ms': _latency.inMilliseconds,
          'runs': runs,
          'per_run_median': {
            for (final m in metrics)
              m: [for (final r in runs) median(r[m] as List<double>)],
          },
        }),
      );
    }
  });

  testWidgets('cold grid timing breakdown', (tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < _warmup + _samples; i++) {
        PaintingBinding.instance.imageCache.clear();
        await server.drain();
        server.delay = _latency;
        final events = <String, Map<String, int>>{};
        ImageDownloader.debugCoverLoadEvent = (event, key) {
          (events[key] ??= {})[event] = server.clock.elapsedMicroseconds;
        };
        final ps = [for (var k = 0; k < 32; k++) '/t/${run++}/$k.png'];
        for (final p in ps) {
          server.images[p] = cover;
        }
        final rs = [
          for (final p in ps)
            Resolution(
              CachedImageProvider(server.url(p), sourceKey: src.key, cid: 't'),
              clock: server.clock,
            ),
        ];
        final errors = await Future.wait(rs.map((r) => r.result));
        ImageDownloader.debugCoverLoadEvent = null;
        final m = <String, List<double>>{
          'resolve_to_enqueue_ms': [],
          'limiter_wait_ms': [],
          'granted_to_request_ms': [],
          'request_to_arrival_ms': [],
        };
        for (var k = 0; k < ps.length; k++) {
          final key = thumbDiskKey(server.url(ps[k]), src.key, 't');
          final e = events[key]!;
          final arrival = server.arrivals[ps[k]]!.first;
          m['resolve_to_enqueue_ms']!.add(_ms(e['enqueue']! - rs[k].startUs!));
          m['limiter_wait_ms']!.add(_ms(e['granted']! - e['enqueue']!));
          m['granted_to_request_ms']!.add(_ms(e['request']! - e['granted']!));
          m['request_to_arrival_ms']!.add(_ms(arrival - e['request']!));
        }
        for (final r in rs) {
          r.dispose();
        }
        expect(errors, everyElement(isNull));
        if (i >= _warmup) runs.add({...m, 'http_requests': server.total});
        server.resetCounters();
      }
    });
  }, skip: !hasNativeHttp);
}
