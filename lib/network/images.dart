import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/consts.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/utils/image.dart';

import 'app_dio.dart';
import 'request_limiter.dart';

abstract class ImageDownloader {
  static Stream<ImageDownloadProgress> loadThumbnail(
      String url, String? sourceKey,
      [String? cid]) async* {
    final cacheKey = thumbnailCacheKey(url, sourceKey, cid);
    final cache = await CacheManager().findCache(cacheKey);

    if (cache != null) {
      var data = await cache.readAsBytes();
      yield ImageDownloadProgress(
        currentBytes: data.length,
        totalBytes: data.length,
        imageBytes: data,
      );
    }

    var configs = <String, dynamic>{};
    if (sourceKey != null) {
      var comicSource = ComicSource.find(sourceKey);
      configs = comicSource?.getThumbnailLoadingConfig?.call(url) ?? {};
    }
    configs['headers'] ??= {};
    if (configs['headers']['user-agent'] == null &&
        configs['headers']['User-Agent'] == null) {
      configs['headers']['user-agent'] = webUA;
    }

    if (((configs['url'] as String?) ?? url).startsWith('cover.') &&
        sourceKey != null) {
      var comicSource = ComicSource.find(sourceKey);
      if(comicSource != null) {
        var comicInfo = await comicSource.loadComicInfo!(cid!);
        yield* loadThumbnail(comicInfo.data.cover, sourceKey);
        return;
      }
    }

    var dio = AppDio(BaseOptions(
      headers: Map<String, dynamic>.from(configs['headers']),
      method: configs['method'] ?? 'GET',
      responseType: ResponseType.stream,
    ));

    String requestUrl = configs['url'] ?? url;
    if (requestUrl.startsWith('//')) {
      requestUrl = 'https:$requestUrl';
    }
    var req = await dio.request<ResponseBody>(requestUrl,
        data: configs['data']);
    var stream = req.data?.stream ?? (throw "Error: Empty response body.");
    int? expectedBytes = req.data!.contentLength;
    if (expectedBytes == -1) {
      expectedBytes = null;
    }
    var buffer = <int>[];
    await for (var data in stream) {
      buffer.addAll(data);
      if (expectedBytes != null) {
        yield ImageDownloadProgress(
          currentBytes: buffer.length,
          totalBytes: expectedBytes,
        );
      }
    }

    if (configs['onResponse'] is JSInvokable) {
      final uint8List = Uint8List.fromList(buffer);
      buffer = (configs['onResponse'] as JSInvokable)([uint8List]);
      (configs['onResponse'] as JSInvokable).free();
    }

    await CacheManager().writeCache(cacheKey, buffer);
    yield ImageDownloadProgress(
      currentBytes: buffer.length,
      totalBytes: buffer.length,
      imageBytes: Uint8List.fromList(buffer),
    );
  }

  /// Disk cache key of a thumbnail.
  static String thumbnailCacheKey(
    String url,
    String? sourceKey, [
    String? cid,
  ]) => "$url@$sourceKey${cid != null ? '@$cid' : ''}";

  /// Maximum number of cover requests of [loadCoverThumbnail] running at the
  /// same time.
  static const maxCoverRequests = 8;

  /// Limits the network requests of [loadCoverThumbnail].
  /// Disk cache hits and local files never wait for it.
  static final coverRequestLimiter = RequestLimiter(maxCoverRequests);

  /// Cover network loads in progress, by disk cache key.
  static final _coverLoads = <String, _CoverLoad>{};

  /// Disk cache key of the cover bytes returned by [loadCoverThumbnail].
  /// Bytes from anywhere else (local files) have no entry.
  static final _coverCacheKeys = Expando<String>();

  /// Loads a cover for an image provider.
  ///
  /// Same cache and request behaviour as [loadThumbnail], except that:
  /// - a valid disk cache hit is returned without any request;
  /// - requests wait for a slot of [coverRequestLimiter];
  /// - concurrent loads of the same disk cache key share one request, which is
  ///   abandoned only when every load sharing it has been stopped.
  ///
  /// [checkStop] throws once the caller's load has been stopped.
  static Future<Uint8List> loadCoverThumbnail(
    String url,
    String? sourceKey,
    String? cid, {
    required void Function() checkStop,
    void Function(int currentBytes, int? totalBytes)? onProgress,
  }) async {
    final consumer = _CoverConsumer(() {
      try {
        checkStop();
        return false;
      } catch (_) {
        return true;
      }
    }, onProgress);
    while (true) {
      try {
        return await _loadCover(url, sourceKey, cid, consumer);
      } on RequestCancelledException {
        checkStop();
        // Joined a shared load just as all its other loads were stopped.
      }
    }
  }

  /// Deletes the disk cache entry that [data] was read from or written to by
  /// [loadCoverThumbnail], if the entry still holds exactly these bytes.
  ///
  /// Call it only for bytes that are empty or cannot be decoded. Bytes from
  /// local files, and entries replaced in the meantime, are left alone.
  static Future<void> invalidateCoverCache(Uint8List data) async {
    final cacheKey = _coverCacheKeys[data];
    if (cacheKey == null) {
      return;
    }
    try {
      final file = await CacheManager().findCache(cacheKey);
      if (file == null) {
        return;
      }
      if (!listEquals(await file.readAsBytes(), data)) {
        return;
      }
      await CacheManager().delete(cacheKey, onlyIfStoredIn: file);
    } catch (e, s) {
      Log.error("Image Loading", e, s);
    }
  }

  static Future<Uint8List> _loadCover(
    String url,
    String? sourceKey,
    String? cid,
    _CoverConsumer consumer,
  ) async {
    final cacheKey = thumbnailCacheKey(url, sourceKey, cid);
    final cache = await _readCoverCache(cacheKey);
    if (cache != null) {
      return cache;
    }
    var load = _coverLoads[cacheKey];
    if (load != null) {
      load.consumers.add(consumer);
      return load.future;
    }
    final newLoad = _CoverLoad()..consumers.add(consumer);
    _coverLoads[cacheKey] = newLoad;
    newLoad.future = _fetchCover(url, sourceKey, cid, cacheKey, newLoad)
        .whenComplete(() {
          if (_coverLoads[cacheKey] == newLoad) {
            _coverLoads.remove(cacheKey);
          }
        });
    return newLoad.future;
  }

  static Future<Uint8List?> _readCoverCache(String cacheKey) async {
    final cache = await CacheManager().findCache(cacheKey);
    if (cache == null) {
      return null;
    }
    final data = await cache.readAsBytes();
    _coverCacheKeys[data] = cacheKey;
    return data;
  }

  static Future<Uint8List> _fetchCover(
    String url,
    String? sourceKey,
    String? cid,
    String cacheKey,
    _CoverLoad load,
  ) async {
    var configs = <String, dynamic>{};
    if (sourceKey != null) {
      var comicSource = ComicSource.find(sourceKey);
      configs = comicSource?.getThumbnailLoadingConfig?.call(url) ?? {};
    }
    configs['headers'] ??= {};
    if (configs['headers']['user-agent'] == null &&
        configs['headers']['User-Agent'] == null) {
      configs['headers']['user-agent'] = webUA;
    }

    if (((configs['url'] as String?) ?? url).startsWith('cover.') &&
        sourceKey != null) {
      var comicSource = ComicSource.find(sourceKey);
      if (comicSource != null) {
        var comicInfo = await comicSource.loadComicInfo!(cid!);
        return _loadCover(
          comicInfo.data.cover,
          sourceKey,
          null,
          _CoverConsumer(load.isCancelled, load.progress),
        );
      }
    }

    final release = await coverRequestLimiter.acquire(
      isCancelled: load.isCancelled,
    );
    try {
      // Another load may have stored the cover while this one was waiting.
      final cache = await _readCoverCache(cacheKey);
      if (cache != null) {
        return cache;
      }
      if (load.isCancelled()) {
        throw const RequestCancelledException();
      }

      var dio = AppDio(
        BaseOptions(
          headers: Map<String, dynamic>.from(configs['headers']),
          method: configs['method'] ?? 'GET',
          responseType: ResponseType.stream,
        ),
      );

      String requestUrl = configs['url'] ?? url;
      if (requestUrl.startsWith('//')) {
        requestUrl = 'https:$requestUrl';
      }
      var req = await dio.request<ResponseBody>(
        requestUrl,
        data: configs['data'],
      );
      var stream = req.data?.stream ?? (throw "Error: Empty response body.");
      int? expectedBytes = req.data!.contentLength;
      if (expectedBytes == -1) {
        expectedBytes = null;
      }
      var buffer = <int>[];
      await for (var data in stream) {
        if (load.isCancelled()) {
          throw const RequestCancelledException();
        }
        buffer.addAll(data);
        if (expectedBytes != null) {
          load.progress(buffer.length, expectedBytes);
        }
      }

      if (configs['onResponse'] is JSInvokable) {
        final uint8List = Uint8List.fromList(buffer);
        buffer = (configs['onResponse'] as JSInvokable)([uint8List]);
        (configs['onResponse'] as JSInvokable).free();
      }

      await CacheManager().writeCache(cacheKey, buffer);
      final result = Uint8List.fromList(buffer);
      _coverCacheKeys[result] = cacheKey;
      return result;
    } finally {
      release();
    }
  }

  static final _loadingImages = <String, _StreamWrapper<ImageDownloadProgress>>{};

  /// Cancel all loading images.
  static void cancelAllLoadingImages() {
    for (var wrapper in _loadingImages.values) {
      wrapper.cancel();
    }
    _loadingImages.clear();
  }

  /// Disk cache key of a comic image.
  static String comicImageCacheKey(
    String imageKey,
    String? sourceKey,
    String cid,
    String eid,
  ) => "$imageKey@$sourceKey@$cid@$eid";

  /// Load a comic image from the network or cache.
  /// The function will prevent multiple requests for the same image.
  ///
  /// If [stopOnCacheHit] is true, a valid disk cache hit ends the stream
  /// without requesting the image again.
  static Stream<ImageDownloadProgress> loadComicImage(
    String imageKey,
    String? sourceKey,
    String cid,
    String eid, {
    bool stopOnCacheHit = false,
  }) {
    final cacheKey = comicImageCacheKey(imageKey, sourceKey, cid, eid);
    final loadingKey = stopOnCacheHit ? "$cacheKey@stopOnCacheHit" : cacheKey;
    if (_loadingImages.containsKey(loadingKey)) {
      return _loadingImages[loadingKey]!.stream;
    }
    final stream = _StreamWrapper<ImageDownloadProgress>(
      _loadComicImage(
        imageKey,
        sourceKey,
        cid,
        eid,
        stopOnCacheHit: stopOnCacheHit,
      ),
      (wrapper) {
        _loadingImages.remove(loadingKey);
      },
    );
    _loadingImages[loadingKey] = stream;
    return stream.stream;
  }

  static Stream<ImageDownloadProgress> loadComicImageUnwrapped(
      String imageKey, String? sourceKey, String cid, String eid) {
    return _loadComicImage(imageKey, sourceKey, cid, eid);
  }

  static Stream<ImageDownloadProgress> _loadComicImage(
    String imageKey,
    String? sourceKey,
    String cid,
    String eid, {
    bool stopOnCacheHit = false,
  }) async* {
    final cacheKey = comicImageCacheKey(imageKey, sourceKey, cid, eid);
    final cache = await CacheManager().findCache(cacheKey);

    if (cache != null) {
      var data = await cache.readAsBytes();
      yield ImageDownloadProgress(
        currentBytes: data.length,
        totalBytes: data.length,
        imageBytes: data,
      );
      if (stopOnCacheHit) {
        return;
      }
    }

    Future<Map<String, dynamic>?> Function()? onLoadFailed;

    var configs = <String, dynamic>{};
    if (sourceKey != null) {
      var comicSource = ComicSource.find(sourceKey);
      configs = (await comicSource!.getImageLoadingConfig
              ?.call(imageKey, cid, eid)) ??
          {};
    }
    var retryLimit = 5;
    while (true) {
      try {
        configs['headers'] ??= {
          'user-agent': webUA,
        };

        if (configs['onLoadFailed'] is JSInvokable) {
          onLoadFailed = () async {
            dynamic result = (configs['onLoadFailed'] as JSInvokable)([]);
            if (result is Future) {
              result = await result;
            }
            if (result is! Map<String, dynamic>) return null;
            return result;
          };
        }

        var dio = AppDio(BaseOptions(
          headers: configs['headers'],
          method: configs['method'] ?? 'GET',
          responseType: ResponseType.stream,
        ));

        var req = await dio.request<ResponseBody>(configs['url'] ?? imageKey,
            data: configs['data']);
        var stream = req.data?.stream ?? (throw "Error: Empty response body.");
        int? expectedBytes = req.data!.contentLength;
        if (expectedBytes == -1) {
          expectedBytes = null;
        }
        var buffer = <int>[];
        await for (var data in stream) {
          buffer.addAll(data);
          yield ImageDownloadProgress(
            currentBytes: buffer.length,
            totalBytes: expectedBytes,
          );
        }

        if (configs['onResponse'] is JSInvokable) {
          dynamic result = (configs['onResponse'] as JSInvokable)([Uint8List.fromList(buffer)]);
          if (result is Future) {
            result = await result;
          }
          if (result is List<int>) {
            buffer = result;
          } else {
            throw "Error: Invalid onResponse result.";
          }
          (configs['onResponse'] as JSInvokable).free();
        }

        Uint8List data;
        if (buffer is Uint8List) {
          data = buffer;
        } else {
          data = Uint8List.fromList(buffer);
          buffer.clear();
        }

        if (configs['modifyImage'] != null) {
          var newData = await modifyImageWithScript(
            data,
            configs['modifyImage'],
          );
          data = newData;
        }

        await CacheManager().writeCache(cacheKey, data);
        yield ImageDownloadProgress(
          currentBytes: data.length,
          totalBytes: data.length,
          imageBytes: data,
        );
        return;
      } catch (e) {
        if (retryLimit < 0 || onLoadFailed == null) {
          rethrow;
        }
        var newConfig = await onLoadFailed();
        (configs['onLoadFailed'] as JSInvokable).free();
        onLoadFailed = null;
        if (newConfig == null) {
          rethrow;
        }
        configs = newConfig;
        retryLimit--;
      } finally {
        if (onLoadFailed != null) {
          (configs['onLoadFailed'] as JSInvokable).free();
        }
      }
    }
  }
}

/// One cover network load and the provider loads sharing it.
class _CoverLoad {
  final consumers = <_CoverConsumer>[];

  late final Future<Uint8List> future;

  /// True once every load sharing this one has been stopped.
  bool isCancelled() => consumers.every((c) => c.isCancelled());

  void progress(int currentBytes, int? totalBytes) {
    for (final c in consumers) {
      if (!c.isCancelled()) {
        c.onProgress?.call(currentBytes, totalBytes);
      }
    }
  }
}

class _CoverConsumer {
  const _CoverConsumer(this.isCancelled, this.onProgress);

  final bool Function() isCancelled;

  final void Function(int currentBytes, int? totalBytes)? onProgress;
}

/// A wrapper class for a stream that
/// allows multiple listeners to listen to the same stream.
class _StreamWrapper<T> {
  final Stream<T> _stream;

  final List<StreamController> controllers = [];

  final void Function(_StreamWrapper<T> wrapper) onClosed;

  bool isClosed = false;

  _StreamWrapper(this._stream, this.onClosed) {
    _listen();
  }

  void _listen() async {
    try {
      await for (var data in _stream) {
        if (isClosed) {
          break;
        }
        for (var controller in controllers) {
          if (!controller.isClosed) {
            controller.add(data);
          }
        }
      }
    }
    catch (e) {
      for (var controller in controllers) {
        if (!controller.isClosed) {
          controller.addError(e);
        }
      }
    }
    finally {
      for (var controller in controllers) {
        if (!controller.isClosed) {
          controller.close();
        }
      }
    }
    controllers.clear();
    isClosed = true;
    onClosed(this);
  }

  Stream<T> get stream {
    if (isClosed) {
      throw Exception('Stream is closed');
    }
    var controller = StreamController<T>();
    controllers.add(controller);
    controller.onCancel = () {
      controllers.remove(controller);
    };
    return controller.stream;
  }

  void cancel() {
    for (var controller in controllers) {
      controller.close();
    }
    controllers.clear();
    isClosed = true;
  }
}

class ImageDownloadProgress {
  final int currentBytes;

  final int? totalBytes;

  final Uint8List? imageBytes;

  const ImageDownloadProgress({
    required this.currentBytes,
    required this.totalBytes,
    this.imageBytes,
  });
}
