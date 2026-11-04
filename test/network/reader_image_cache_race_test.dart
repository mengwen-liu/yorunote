import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rhttp/rhttp.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/image_provider/reader_image.dart';
import 'package:venera/network/images.dart';

// Races between the reader invalidating a broken disk cache entry and a
// request writing a valid image for the same key. The order is forced with
// explicit gates instead of delays:
//
// * "before delete": the invalidation is held when it asks the cache manager
//   to delete the entry, after it has checked which entry it is.
// * "delete started": the invalidation is held inside CacheManager.delete,
//   after the broken file is removed and before its index row is removed.
//
// While an invalidation is held, a valid image is written for the same key,
// either directly or by a new download request. After the invalidation
// resumes, the valid image must still be indexed, stored and readable.

/// Directory of a host build of librhttp.so, as used by flutter_rust_bridge.
/// Tests that need real HTTP are skipped when it is not provided; set
/// FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR to run them.
final String? _nativeLibDir =
    Platform.environment['FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR'];

final bool _hasNativeHttp =
    _nativeLibDir != null &&
    File('$_nativeLibDir${Platform.pathSeparator}librhttp.so').existsSync();

/// Guards against a hang if a gate is never reached; it does not order work.
const _guard = Duration(seconds: 20);

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

/// A one-shot synchronization point.
class _Gate {
  final _reached = Completer<void>();
  final _released = Completer<void>();

  Future<void> get reached => _reached.future.timeout(_guard);

  /// Holds the caller until [release]; later calls pass through.
  Future<void> hold() {
    if (_reached.isCompleted) return Future.value();
    _reached.complete();
    return _released.future;
  }

  void release() => _released.complete();
}

/// Forwards to the real cache manager and holds the first deletion of
/// [gateKey] at [gate].
class _GatedCacheManager implements CacheManager {
  _GatedCacheManager(this._real, this.gateKey, this.gate);

  final CacheManager _real;
  final String gateKey;
  final _Gate gate;

  @override
  Future<void> delete(String key, {File? onlyIfStoredIn}) async {
    if (key == gateKey) {
      await gate.hold();
    }
    if (onlyIfStoredIn == null) {
      return _real.delete(key);
    }
    // Dynamic so that this test also compiles against a cache manager
    // without the identity check, to show the race there.
    return (_real as dynamic).delete(key, onlyIfStoredIn: onlyIfStoredIn);
  }

  @override
  Future<File?> findCache(String key) => _real.findCache(key);

  @override
  Future<void> writeCache(
    String key,
    List<int> data, [
    int duration = 7 * 24 * 60 * 60 * 1000,
  ]) => _real.writeCache(key, data, duration);

  @override
  Future<void> clear() => _real.clear();

  @override
  Future<void> checkCache() => _real.checkCache();

  @override
  void checkCacheIfRequired() => _real.checkCacheIfRequired();

  @override
  void setLimitSize(int size) => _real.setLimitSize(size);

  @override
  int get currentSize => _real.currentSize;

  @override
  int get dir => _real.dir;

  @override
  set dir(int value) => _real.dir = value;
}

/// Holds the first deletion of the file at [path] at [gate], after the file
/// is removed from disk.
final class _FileDeleteGate extends IOOverrides {
  _FileDeleteGate(this.path, this.gate);

  final String path;
  final _Gate gate;

  @override
  File createFile(String path) {
    final file = super.createFile(path);
    return path == this.path ? _GatedFile(file, gate) : file;
  }
}

class _GatedFile implements File {
  _GatedFile(this._file, this._gate);

  final File _file;
  final _Gate _gate;

  @override
  String get path => _file.path;

  @override
  Uri get uri => _file.uri;

  @override
  Future<bool> exists() => _file.exists();

  @override
  bool existsSync() => _file.existsSync();

  @override
  Future<int> length() => _file.length();

  @override
  Future<Uint8List> readAsBytes() => _file.readAsBytes();

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    final result = await _file.delete(recursive: recursive);
    await _gate.hold();
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('_GatedFile: ${invocation.memberName}');
}

/// Local image server that counts requests per path.
class _ImageServer {
  HttpServer? _server;
  final requests = <String, int>{};
  final images = <String, Uint8List>{};

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen((request) async {
      final path = request.uri.path;
      requests[path] = (requests[path] ?? 0) + 1;
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

ReaderImageProvider _reader(String url) =>
    ReaderImageProvider(url, null, 'cid', 'eid', 1);

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
    return await done.future.timeout(_guard);
  } finally {
    stream.removeListener(listener);
    // Lets the provider evict a failed image before the next resolve.
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  final server = _ImageServer();
  late CacheManager realCache;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('venera_cache_race');
    App.cachePath = '${dir.path}/cache';
    App.dataPath = '${dir.path}/data';
    await Directory(App.dataPath).create(recursive: true);
    realCache = CacheManager();
    if (_hasNativeHttp) {
      await Rhttp.init();
      await server.start();
    }
  });

  tearDownAll(() => server.stop());

  setUp(() {
    PaintingBinding.instance.imageCache.clear();
    CacheManager.instance = realCache;
  });

  tearDown(() => CacheManager.instance = realCache);

  /// Writes the valid image for [url] the way the case asks for.
  Future<void> writeValid(String url, String path, bool byRequest) async {
    if (!byRequest) {
      await CacheManager().writeCache(_diskKey(url), server.images[path]!);
      return;
    }
    await ImageDownloader.loadComicImageUnwrapped(
      url,
      null,
      'cid',
      'eid',
    ).drain<void>();
  }

  /// Checks that the valid image is indexed, stored and read from the cache.
  Future<void> expectValidImageKept(String url, String path, int http) async {
    final file = await CacheManager().findCache(_diskKey(url));
    expect(file, isNotNull, reason: 'index entry of the valid image');
    expect(await file!.readAsBytes(), server.images[path], reason: 'file');
    PaintingBinding.instance.imageCache.clear();
    expect(await _resolve(_reader(url)), isNull, reason: 'next read');
    expect(server.count(path), http, reason: 'requests');
  }

  for (final byRequest in [false, true]) {
    final writer = byRequest ? 'a new request' : 'a direct cache write';

    testWidgets(
      'before delete: $writer keeps its valid image',
      (tester) async {
        await tester.runAsync(() async {
          final path = '/before-delete-$byRequest.png';
          final url = server.url(path);
          server.images[path] = _png(byRequest ? 11 : 10);
          await realCache.writeCache(_diskKey(url), _corrupt);

          final gate = _Gate();
          CacheManager.instance = _GatedCacheManager(
            realCache,
            _diskKey(url),
            gate,
          );
          final oldRead = _resolve(_reader(url));
          await gate.reached;
          await writeValid(url, path, byRequest);
          gate.release();
          expect(await oldRead, isNotNull, reason: 'the broken image fails');

          await expectValidImageKept(url, path, byRequest ? 1 : 0);
        });
      },
      skip: byRequest && !_hasNativeHttp,
    );

    testWidgets(
      'delete started: $writer keeps its valid image',
      (tester) async {
        await tester.runAsync(() async {
          final path = '/delete-started-$byRequest.png';
          final url = server.url(path);
          server.images[path] = _png(byRequest ? 21 : 20);
          await realCache.writeCache(_diskKey(url), _corrupt);
          final brokenPath = (await realCache.findCache(_diskKey(url)))!.path;

          final gate = _Gate();
          final oldRead = IOOverrides.runWithIOOverrides(
            () => _resolve(_reader(url)),
            _FileDeleteGate(brokenPath, gate),
          );
          await gate.reached;
          expect(File(brokenPath).existsSync(), isFalse);
          await writeValid(url, path, byRequest);
          gate.release();
          expect(await oldRead, isNotNull, reason: 'the broken image fails');

          await expectValidImageKept(url, path, byRequest ? 1 : 0);
        });
      },
      skip: byRequest && !_hasNativeHttp,
    );
  }
}
