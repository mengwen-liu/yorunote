import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals, visibleForTesting;
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

  /// Test-only timing probe for cover network loads: called with
  /// `enqueue` (before waiting for a slot of [coverRequestLimiter]),
  /// `granted` (slot obtained) and `request` (request handed to Dio), and the
  /// disk cache key. Null in the app.
  @visibleForTesting
  static void Function(String event, String cacheKey)? debugCoverLoadEvent;

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
  /// [checkStop] throws once the caller's load has been stopped. [stopped],
  /// if given, completes at that moment; the caller then returns right away,
  /// and when it was the last load using the request, the request is
  /// cancelled down to rhttp (also while waiting for headers or body bytes)
  /// or, if still queued, removed from [coverRequestLimiter].
  static Future<Uint8List> loadCoverThumbnail(
    String url,
    String? sourceKey,
    String? cid, {
    required void Function() checkStop,
    void Function(int currentBytes, int? totalBytes)? onProgress,
    Future<void>? stopped,
  }) async {
    final consumer = _CoverConsumer(
      () {
        try {
          checkStop();
          return false;
        } catch (_) {
          return true;
        }
      },
      onProgress,
      stopped,
    );
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
    if (load == null) {
      final newLoad = _CoverLoad(cacheKey);
      load = newLoad;
      _coverLoads[cacheKey] = newLoad;
      newLoad.attach(consumer);
      newLoad.future = _fetchCover(
        url,
        sourceKey,
        cid,
        cacheKey,
        newLoad,
      ).whenComplete(() => _forgetCoverLoad(newLoad));
    } else {
      load.attach(consumer);
    }
    return consumer.wait(load.future);
  }

  /// Removes [load] from the loads that new consumers can join.
  static void _forgetCoverLoad(_CoverLoad load) {
    if (_coverLoads[load.cacheKey] == load) {
      _coverLoads.remove(load.cacheKey);
    }
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

  /// [_readCoverCache] for the check made after waiting for a slot: empty or
  /// undecodable bytes are treated as a miss, so the request goes out and its
  /// result replaces them. The decode happens only when an entry appeared
  /// while waiting, never for an ordinary cache hit.
  static Future<Uint8List?> _readValidCoverCache(String cacheKey) async {
    final data = await _readCoverCache(cacheKey);
    if (data == null || data.isEmpty || !await _canDecode(data)) {
      return null;
    }
    return data;
  }

  static Future<bool> _canDecode(Uint8List data) async {
    try {
      final codec = await ui.instantiateImageCodec(data);
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
      return true;
    } catch (_) {
      return false;
    }
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
          _CoverConsumer(load.isCancelled, load.progress, load.abandoned),
        );
      }
    }

    debugCoverLoadEvent?.call('enqueue', cacheKey);
    final release = await coverRequestLimiter.acquire(
      isCancelled: load.isCancelled,
      cancelSignal: load.abandoned,
    );
    debugCoverLoadEvent?.call('granted', cacheKey);
    try {
      // Another path may have stored the cover while this load was waiting
      // for its slot; empty or broken bytes stored meanwhile are no hit.
      final cache = await _readValidCoverCache(cacheKey);
      if (cache != null) {
        return cache;
      }
      load.throwIfCancelled();

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
      debugCoverLoadEvent?.call('request', cacheKey);
      Response<ResponseBody> req;
      var buffer = <int>[];
      int? expectedBytes;
      try {
        req = await dio.request<ResponseBody>(
          requestUrl,
          data: configs['data'],
          cancelToken: load.cancelToken,
        );
        load.headersReceived = true;
        if (load.isAbandoned) {
          // Abandoned while waiting for the headers: tear it down now.
          load.cancelToken.cancel();
          throw const RequestCancelledException();
        }
        var stream = req.data?.stream ?? (throw "Error: Empty response body.");
        expectedBytes = req.data!.contentLength;
        if (expectedBytes == -1) {
          expectedBytes = null;
        }
        await for (var data in stream) {
          load.throwIfCancelled();
          buffer.addAll(data);
          if (expectedBytes != null) {
            load.progress(buffer.length, expectedBytes);
          }
        }
      } on DioException catch (e) {
        if (CancelToken.isCancel(e) || load.isAbandoned) {
          throw const RequestCancelledException();
        }
        rethrow;
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
  _CoverLoad(this.cacheKey);

  final String cacheKey;

  final consumers = <_CoverConsumer>[];

  late final Future<Uint8List> future;

  /// Cancels the request in Dio and, through RHttpAdapter, in rhttp.
  /// Only used once the headers are in (see RHttpAdapter.fetch): before
  /// that, Dio would give up on the request while rhttp keeps it open, so
  /// the slot would be returned for a request that is still running.
  final cancelToken = CancelToken();

  /// True once the response headers have arrived.
  bool headersReceived = false;

  final _abandoned = Completer<void>();

  /// Completes once every load sharing this one has been stopped.
  Future<void> get abandoned => _abandoned.future;

  bool get isAbandoned => _abandoned.isCompleted;

  void attach(_CoverConsumer consumer) {
    consumers.add(consumer);
    consumer.onStop(_abandonIfUnused);
  }

  /// True once every load sharing this one has been stopped.
  bool isCancelled() => isAbandoned || consumers.every((c) => c.isCancelled());

  void throwIfCancelled() {
    if (isCancelled()) {
      _abandonIfUnused();
      throw const RequestCancelledException();
    }
  }

  /// Abandons the load when no consumer needs it any more: new consumers
  /// start a new load, a queued request leaves the queue and a running
  /// request is cancelled.
  void _abandonIfUnused() {
    if (isAbandoned || !consumers.every((c) => c.isCancelled())) {
      return;
    }
    _abandoned.complete();
    ImageDownloader._forgetCoverLoad(this);
    if (headersReceived) {
      cancelToken.cancel();
    }
  }

  void progress(int currentBytes, int? totalBytes) {
    for (final c in consumers) {
      if (!c.isCancelled()) {
        c.onProgress?.call(currentBytes, totalBytes);
      }
    }
  }
}

class _CoverConsumer {
  _CoverConsumer(this._isStopped, this.onProgress, this._stopped) {
    _stopped?.then((_) {
      _stopSignalled = true;
      for (final listener in _stopListeners) {
        listener();
      }
      _stopListeners.clear();
    });
  }

  final bool Function() _isStopped;

  final void Function(int currentBytes, int? totalBytes)? onProgress;

  final Future<void>? _stopped;

  bool _stopSignalled = false;

  final _stopListeners = <void Function()>[];

  bool isCancelled() => _stopSignalled || _isStopped();

  /// Calls [listener] when this consumer's stop signal fires.
  void onStop(void Function() listener) {
    if (_stopSignalled) {
      listener();
    } else {
      _stopListeners.add(listener);
    }
  }

  /// Waits for [load], or fails with [RequestCancelledException] as soon as
  /// this consumer is stopped (other consumers keep the load alive).
  Future<Uint8List> wait(Future<Uint8List> load) {
    final stopped = _stopped;
    if (stopped == null) {
      return load;
    }
    return Future.any([
      load,
      stopped.then<Uint8List>((_) => throw const RequestCancelledException()),
    ]);
  }
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
