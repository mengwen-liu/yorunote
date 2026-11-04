import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rhttp/rhttp.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/image_provider/base_image_provider.dart';
import 'package:venera/foundation/image_provider/reader_image.dart';

// These tests drive ReaderImageProvider through ImageProvider.resolve, the
// same call the reader's ComicImage makes. A retry is simulated by resolving
// the provider again after the error, as ComicImage's Retry handler does; the
// Retry button itself needs the full reader and is not tapped here.

/// Directory of a host build of librhttp.so, as used by flutter_rust_bridge.
/// Tests that need real HTTP are skipped when it is not provided; set
/// FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR to run them.
final String? _nativeLibDir =
    Platform.environment['FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR'];

final bool _hasNativeHttp =
    _nativeLibDir != null &&
    File('$_nativeLibDir${Platform.pathSeparator}librhttp.so').existsSync();

/// A valid 8x8 grayscale PNG built from scratch.
Uint8List _png(int shade) {
  List<int> chunk(String type, List<int> data) {
    final body = [...ascii.encode(type), ...data];
    return [..._u32(data.length), ...body, ..._u32(_crc32(body))];
  }

  final raw = <int>[];
  for (var y = 0; y < 8; y++) {
    raw.add(0);
    raw.addAll(List<int>.filled(8, shade));
  }
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    ...chunk('IHDR', [..._u32(8), ..._u32(8), 8, 0, 0, 0, 0]),
    ...chunk('IDAT', zlib.encode(raw)),
    ...chunk('IEND', const []),
  ]);
}

List<int> _u32(int v) => [
  v >> 24 & 0xff,
  v >> 16 & 0xff,
  v >> 8 & 0xff,
  v & 0xff,
];

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final b in bytes) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = crc & 1 != 0 ? 0xedb88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return crc ^ 0xffffffff;
}

/// PNG signature followed by bytes that cannot be decoded.
final Uint8List _corrupt = Uint8List.fromList([
  ..._png(0).sublist(0, 16),
  ...List<int>.filled(64, 0x5a),
]);

/// Local image server that counts requests per path.
class _ImageServer {
  HttpServer? _server;
  final requests = <String, int>{};
  final images = <String, Uint8List>{};
  Duration delay = Duration.zero;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((request) async {
      final path = request.uri.path;
      requests[path] = (requests[path] ?? 0) + 1;
      await Future<void>.delayed(delay);
      final data = images[path];
      if (data == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.headers.contentLength = data.length;
        request.response.add(data);
      }
      await request.response.close();
    });
  }

  /// Without a running server the URL points at an unused port.
  String url(String path) => 'http://127.0.0.1:${_server?.port ?? 9}$path';

  int count(String path) => requests[path] ?? 0;

  Future<void> stop() async => _server?.close(force: true);
}

String _diskKey(String url) => '$url@null@cid@eid';

ReaderImageProvider _reader(String url, {bool resize = false}) =>
    ReaderImageProvider(url, null, 'cid', 'eid', 1, enableResize: resize);

/// Resolves [provider] and returns null on success or the reported error.
Future<Object?> _resolve(ImageProvider provider) async {
  final done = Completer<Object?>();
  final stream = provider.resolve(ImageConfiguration.empty);
  final listener = ImageStreamListener(
    (info, _) {
      info.dispose();
      if (!done.isCompleted) done.complete(null);
    },
    onError: (error, _) {
      if (!done.isCompleted) done.complete(error);
    },
  );
  stream.addListener(listener);
  try {
    return await done.future.timeout(const Duration(seconds: 20));
  } finally {
    stream.removeListener(listener);
    // Lets the provider evict a failed image before a retry.
    await Future<void>.delayed(Duration.zero);
  }
}

/// A provider that keeps BaseImageProvider's default invalid-data handling.
class _PlainProvider extends BaseImageProvider<_PlainProvider> {
  const _PlainProvider(this.key, this.data);

  @override
  final String key;

  final Uint8List data;

  @override
  Future<Uint8List> load(chunkEvents, checkStop) async => data;

  @override
  Future<_PlainProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
}

void main() {
  final server = _ImageServer();
  // Lets work that continues after a provider finishes reach the server.
  const settle = Duration(milliseconds: 500);

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('venera_reader_cache');
    App.cachePath = '${dir.path}/cache';
    App.dataPath = '${dir.path}/data';
    await Directory(App.dataPath).create(recursive: true);
    if (_hasNativeHttp) {
      await Rhttp.init();
      await server.start();
    }
  });

  tearDownAll(() => server.stop());

  setUp(() => PaintingBinding.instance.imageCache.clear());

  testWidgets('a valid cache hit is shown without requests', (tester) async {
    await tester.runAsync(() async {
      const path = '/hit.png';
      final url = server.url(path);
      server.images[path] = _png(10);
      await CacheManager().writeCache(_diskKey(url), _png(10));

      expect(await _resolve(_reader(url)), isNull);
      await Future<void>.delayed(settle);
      expect(server.count(path), 0);

      // Visible page and preloading with the other resize setting.
      PaintingBinding.instance.imageCache.clear();
      final results = await Future.wait([
        _resolve(_reader(url)),
        _resolve(_reader(url, resize: true)),
      ]);
      expect(results, [null, null]);
      await Future<void>.delayed(settle);
      expect(server.count(path), 0);
    });
  }, skip: !_hasNativeHttp);

  testWidgets(
    'a miss, an expired entry and parallel misses each request once',
    (tester) async {
      await tester.runAsync(() async {
        const missPath = '/miss.png';
        final missUrl = server.url(missPath);
        server.images[missPath] = _png(20);
        expect(await _resolve(_reader(missUrl)), isNull);
        expect(server.count(missPath), 1);
        final stored = await CacheManager().findCache(_diskKey(missUrl));
        expect(await stored!.readAsBytes(), _png(20));

        const expiredPath = '/expired.png';
        final expiredUrl = server.url(expiredPath);
        server.images[expiredPath] = _png(30);
        await CacheManager().writeCache(_diskKey(expiredUrl), _png(31), -1000);
        expect(await _resolve(_reader(expiredUrl)), isNull);
        expect(server.count(expiredPath), 1);

        const sharedPath = '/shared.png';
        final sharedUrl = server.url(sharedPath);
        server.images[sharedPath] = _png(40);
        server.delay = const Duration(milliseconds: 200);
        final results = await Future.wait([
          _resolve(_reader(sharedUrl)),
          _resolve(_reader(sharedUrl, resize: true)),
        ]);
        server.delay = Duration.zero;
        expect(results, [null, null]);
        await Future<void>.delayed(settle);
        expect(server.count(sharedPath), 1);
      });
    },
    skip: !_hasNativeHttp,
  );

  for (final (name, broken) in [
    ('undecodable', _corrupt),
    ('empty', Uint8List(0)),
  ]) {
    testWidgets('an $name cache entry is invalidated, other entries kept', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final url = server.url('/$name-only.png');
        final otherUrl = server.url('/$name-other.png');
        await CacheManager().writeCache(_diskKey(url), broken);
        await CacheManager().writeCache(_diskKey(otherUrl), _png(50));

        expect(await _resolve(_reader(url)), isNotNull);
        expect(await CacheManager().findCache(_diskKey(url)), isNull);
        expect(await CacheManager().findCache(_diskKey(otherUrl)), isNotNull);
      });
    });

    testWidgets('one retry recovers from an $name cache entry', (tester) async {
      await tester.runAsync(() async {
        final path = '/$name-recover.png';
        final url = server.url(path);
        server.images[path] = _png(60);
        await CacheManager().writeCache(_diskKey(url), broken);

        expect(await _resolve(_reader(url)), isNotNull);
        await Future<void>.delayed(settle);
        expect(server.count(path), 0, reason: 'no automatic refetch');

        expect(await _resolve(_reader(url)), isNull, reason: 'retry');
        expect(server.count(path), 1);

        PaintingBinding.instance.imageCache.clear();
        expect(await _resolve(_reader(url)), isNull, reason: 'read again');
        await Future<void>.delayed(settle);
        expect(server.count(path), 1);
      });
    }, skip: !_hasNativeHttp);
  }

  testWidgets('both resize settings recover with one shared request', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const path = '/resize-recover.png';
      final url = server.url(path);
      server.images[path] = _png(70);
      await CacheManager().writeCache(_diskKey(url), _corrupt);

      final failed = await Future.wait([
        _resolve(_reader(url)),
        _resolve(_reader(url, resize: true)),
      ]);
      expect(failed, everyElement(isNotNull));

      server.delay = const Duration(milliseconds: 200);
      final retried = await Future.wait([
        _resolve(_reader(url)),
        _resolve(_reader(url, resize: true)),
      ]);
      server.delay = Duration.zero;
      expect(retried, [null, null]);
      await Future<void>.delayed(settle);
      expect(server.count(path), 1);
    });
  }, skip: !_hasNativeHttp);

  testWidgets('other providers keep the default invalid-data handling', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await CacheManager().writeCache('plain-corrupt', _png(80));
      await CacheManager().writeCache('plain-empty', _png(81));

      expect(
        await _resolve(_PlainProvider('plain-corrupt', _corrupt)),
        isNotNull,
      );
      expect(await CacheManager().findCache('plain-corrupt'), isNull);

      expect(
        await _resolve(_PlainProvider('plain-empty', Uint8List(0))),
        isNotNull,
      );
      expect(await CacheManager().findCache('plain-empty'), isNotNull);
    });
  });

  // BEGIN invalidation-hook group (uses the hook added with this test)
  group('ReaderImageProvider.onInvalidImageData keeps', () {
    testWidgets('a valid entry when only processed data is broken', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final url = server.url('/processed.png');
        await CacheManager().writeCache(_diskKey(url), _png(90));
        // ignore: invalid_use_of_protected_member
        await _reader(url).onInvalidImageData(_corrupt);
        expect(await CacheManager().findCache(_diskKey(url)), isNotNull);
      });
    });

    testWidgets('an entry another request has just repaired', (tester) async {
      await tester.runAsync(() async {
        final url = server.url('/repaired.png');
        await CacheManager().writeCache(_diskKey(url), _corrupt);
        await CacheManager().writeCache(_diskKey(url), _png(100));
        // The stale broken bytes arrive after the repair.
        // ignore: invalid_use_of_protected_member
        await _reader(url).onInvalidImageData(_corrupt);
        final file = await CacheManager().findCache(_diskKey(url));
        expect(await file!.readAsBytes(), _png(100));
      });
    });

    testWidgets('local comic files and their keys', (tester) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('venera_local');
        final local = File('${dir.path}/1.png');
        await local.writeAsBytes(_corrupt);
        final key = 'file://${local.path}';
        await CacheManager().writeCache(_diskKey(key), _corrupt);
        // ignore: invalid_use_of_protected_member
        await _reader(key).onInvalidImageData(_corrupt);
        expect(await local.exists(), isTrue);
        expect(await CacheManager().findCache(_diskKey(key)), isNotNull);
      });
    });
  });
  // END invalidation-hook group
}
