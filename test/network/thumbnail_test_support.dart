// Shared fixtures for the cover / thumbnail tests and the queue benchmark.
// Synthetic images only; no third-party covers, accounts or reading history.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:rhttp/rhttp.dart' show Rhttp;
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/local.dart';

/// Directory of a host build of librhttp.so, as used by flutter_rust_bridge.
/// Tests that need real HTTP are skipped when it is not provided; set
/// FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR to run them.
final String? nativeLibDir =
    Platform.environment['FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR'];

final bool hasNativeHttp =
    nativeLibDir != null &&
    File('$nativeLibDir${Platform.pathSeparator}librhttp.so').existsSync();

/// A valid grayscale PNG built from scratch.
Uint8List png(int shade, {int width = 8, int height = 8}) {
  List<int> chunk(String type, List<int> data) {
    final body = [...ascii.encode(type), ...data];
    return [..._u32(data.length), ...body, ..._u32(_crc32(body))];
  }

  final raw = <int>[];
  for (var y = 0; y < height; y++) {
    raw.add(0);
    for (var x = 0; x < width; x++) {
      raw.add((shade + x + y) & 0xff);
    }
  }
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    ...chunk('IHDR', [..._u32(width), ..._u32(height), 8, 0, 0, 0, 0]),
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
final Uint8List corruptPng = Uint8List.fromList([
  ...png(0).sublist(0, 16),
  ...List<int>.filled(64, 0x5a),
]);

/// How the server answers one path.
enum Reply { image, status, partial }

/// Local cover server: counts requests, tracks concurrency and can hold
/// responses until the test releases them.
class CoverServer {
  HttpServer? _server;

  final requests = <String, int>{};
  final images = <String, Uint8List>{};
  final statusCodes = <String, int>{};
  final partial = <String>{};
  final requestHeaders = <String, HttpHeaders>{};

  /// Microseconds of [clock] at which each request for a path arrived.
  final arrivals = <String, List<int>>{};

  /// Shared clock for arrival times.
  final Stopwatch clock = Stopwatch()..start();

  /// Responses wait for [release] / [releaseAll] while this is true.
  bool holdResponses = false;

  /// Fixed delay before each response (after any hold).
  Duration delay = Duration.zero;

  final _held = Queue<Completer<void>>();

  int inflight = 0;
  int peakInflight = 0;
  int total = 0;

  final _inflightWaiters = <(int, Completer<void>)>[];
  final _arrivalWaiters = <Completer<int>>[];

  /// Completes with the [clock] time of the next request that arrives.
  Future<int> nextArrival() {
    final c = Completer<int>();
    _arrivalWaiters.add(c);
    return c.future;
  }

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
  }

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    requests[path] = (requests[path] ?? 0) + 1;
    requestHeaders[path] = request.headers;
    (arrivals[path] ??= []).add(clock.elapsedMicroseconds);
    total++;
    final now = clock.elapsedMicroseconds;
    for (final c in _arrivalWaiters) {
      c.complete(now);
    }
    _arrivalWaiters.clear();
    inflight++;
    if (inflight > peakInflight) peakInflight = inflight;
    _notifyInflight();
    try {
      if (holdResponses) {
        final c = Completer<void>();
        _held.add(c);
        await c.future;
      }
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      final data = images[path];
      final code = statusCodes[path];
      if (code != null) {
        request.response.statusCode = code;
        request.response.write('error $code');
        await request.response.close();
      } else if (data == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      } else if (partial.contains(path)) {
        // Announces the full length, sends half and drops the connection.
        request.response.headers.contentLength = data.length;
        final socket = await request.response.detachSocket();
        socket.add(data.sublist(0, data.length ~/ 2));
        await socket.flush();
        socket.destroy();
      } else {
        request.response.headers.contentLength = data.length;
        request.response.add(data);
        await request.response.close();
      }
    } catch (_) {
      // The client may have gone away.
    } finally {
      inflight--;
    }
  }

  void _notifyInflight() {
    _inflightWaiters.removeWhere((w) {
      if (inflight >= w.$1) {
        w.$2.complete();
        return true;
      }
      return false;
    });
  }

  /// Completes once at least [n] requests are being served at the same time.
  Future<void> inflightAtLeast(int n) {
    if (inflight >= n) return Future.value();
    final c = Completer<void>();
    _inflightWaiters.add((n, c));
    return c.future;
  }

  int get heldCount => _held.length;

  /// Releases everything and completes once no request is being served.
  Future<void> drain() async {
    holdResponses = false;
    delay = Duration.zero;
    releaseAll();
    while (inflight > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  /// Releases the oldest held response.
  void release() {
    if (_held.isNotEmpty) _held.removeFirst().complete();
  }

  void releaseAll() {
    while (_held.isNotEmpty) {
      _held.removeFirst().complete();
    }
  }

  void resetCounters() {
    peakInflight = inflight;
    total = 0;
  }

  /// Without a running server the URL points at an unused port.
  String url(String path) => 'http://127.0.0.1:${_server?.port ?? 9}$path';

  int count(String path) => requests[path] ?? 0;

  Future<void> stop() async {
    releaseAll();
    await _server?.close(force: true);
  }
}

/// Starts resolving [provider]; the returned handle reports the outcome.
class Resolution {
  Resolution(this.provider, {this.clock}) {
    startUs = clock?.elapsedMicroseconds;
    stream = provider.resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener(
      (info, _) {
        info.dispose();
        doneUs ??= clock?.elapsedMicroseconds;
        if (!_done.isCompleted) _done.complete(null);
      },
      onError: (error, _) {
        doneUs ??= clock?.elapsedMicroseconds;
        if (!_done.isCompleted) _done.complete(error);
      },
    );
    stream.addListener(_listener);
  }

  final ImageProvider provider;

  /// Optional clock for [startUs] and [doneUs], in microseconds.
  final Stopwatch? clock;
  int? startUs;
  int? doneUs;
  late final ImageStream stream;
  late final ImageStreamListener _listener;
  final _done = Completer<Object?>();

  bool get isDone => _done.isCompleted;

  /// Null on success, otherwise the reported error.
  Future<Object?> get result =>
      _done.future.timeout(const Duration(seconds: 60));

  /// Stops listening and evicts the pending image, which cancels its load the
  /// way an image cache eviction does in the app.
  void cancel() {
    stream.removeListener(_listener);
    PaintingBinding.instance.imageCache.evict(provider);
  }

  void dispose() => stream.removeListener(_listener);
}

/// Resolves [provider] and returns null on success or the reported error.
Future<Object?> resolveOnce(ImageProvider provider) async {
  final r = Resolution(provider);
  try {
    return await r.result;
  } finally {
    r.dispose();
    // Lets the provider evict a failed image before a retry.
    await Future<void>.delayed(Duration.zero);
  }
}

/// A comic source with only a key and, optionally, a thumbnail config.
ComicSource testSource(
  String key, {
  Map<String, dynamic> Function(String url)? thumbnailConfig,
}) {
  return ComicSource(
    key, // name
    key, // key
    null, // account
    null, // categoryData
    null, // categoryComicsData
    null, // favoriteData
    const [], // explorePages
    null, // searchPageData
    null, // settings
    null, // loadComicInfo
    null, // loadComicThumbnail
    null, // loadComicPages
    null, // getImageLoadingConfig
    thumbnailConfig, // getThumbnailLoadingConfig
    '', // filePath
    '', // url
    '1.0.0', // version
    null, // commentsLoader
    null, // sendCommentFunc
    null, // chapterCommentsLoader
    null, // sendChapterCommentFunc
    null, // likeOrUnlikeComic
    null, // voteCommentFunc
    null, // likeCommentFunc
    null, // idMatcher
    null, // translations
    null, // handleClickTagEvent
    null, // onTagSuggestionSelected
    null, // linkHandler
    false, // enableTagsSuggestions
    false, // enableTagsTranslate
    null, // starRatingFunc
    null, // archiveDownloader
  );
}

/// Points App at a fresh temporary data directory, opens the local comic
/// database and starts [server] when real HTTP is available.
///
/// LocalManager.init() opens its database first and then waits for the JS
/// engine, which a host test does not have, so only the database part is
/// awaited here.
Future<Directory> initCoverTestEnvironment(
  CoverServer server, {
  List<ComicSource> sources = const [],
}) async {
  final dir = await Directory.systemTemp.createTemp('yorunote_cover_test');
  App.cachePath = '${dir.path}/cache';
  App.dataPath = '${dir.path}/data';
  await Directory(App.dataPath).create(recursive: true);
  for (final s in sources) {
    ComicSourceManager().add(s);
  }
  unawaited(LocalManager().init().catchError((_) {}));
  // The database is opened synchronously at the start of init().
  await Future<void>.delayed(Duration.zero);
  if (hasNativeHttp) {
    await Rhttp.init();
    await server.start();
  }
  return dir;
}

/// Adds a local comic whose cover file holds [coverBytes].
Future<File> addLocalComic(
  Directory root,
  String id,
  ComicType type,
  Uint8List coverBytes,
) async {
  final dir = Directory('${root.path}/local_comics/${type.value}_$id');
  await dir.create(recursive: true);
  final cover = File('${dir.path}/cover.png');
  await cover.writeAsBytes(coverBytes);
  await LocalManager().add(
    LocalComic(
      id: id,
      title: 'synthetic $id',
      subtitle: '',
      tags: const [],
      directory: dir.path,
      chapters: null,
      cover: 'cover.png',
      comicType: type,
      downloadedChapters: [],
      createdAt: DateTime(2026),
    ),
  );
  return cover;
}

/// A reading history entry of a synthetic comic.
History testHistory(String id, ComicSource source, String cover) {
  return History.fromMap({
    'type': source.intKey,
    'time': 0,
    'title': 'synthetic $id',
    'subtitle': '',
    'cover': cover,
    'ep': 1,
    'page': 1,
    'id': id,
  });
}

/// Disk cache key used by ImageDownloader.loadThumbnail.
String thumbDiskKey(String url, String? sourceKey, [String? cid]) =>
    "$url@$sourceKey${cid != null ? '@$cid' : ''}";
