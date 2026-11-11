import 'dart:async' show Future;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/js_engine.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/network/images.dart';
import 'package:venera/utils/io.dart';
import 'base_image_provider.dart';
import 'reader_image.dart' as image_provider;
import 'package:venera/foundation/appdata.dart';

class ReaderImageProvider
    extends BaseImageProvider<image_provider.ReaderImageProvider> {
  /// Image provider for normal image.
  const ReaderImageProvider(this.imageKey, this.sourceKey, this.cid, this.eid, this.page, {this.enableResize = false});

  final String imageKey;

  final String? sourceKey;

  final String cid;

  final String eid;

  final int page;

  @override
  final bool enableResize;

  @override
  Future<Uint8List> load(chunkEvents, checkStop) async {
    Uint8List? imageBytes;
    if (imageKey.startsWith('file://')) {
      var file = File(imageKey);
      if (await file.exists()) {
        imageBytes = await file.readAsBytes();
      } else {
        throw "Error: File not found.";
      }
    } else {
      await for (var event in ImageDownloader.loadComicImage(
        imageKey,
        sourceKey,
        cid,
        eid,
        stopOnCacheHit: true,
      )) {
        checkStop();
        chunkEvents.add(ImageChunkEvent(
          cumulativeBytesLoaded: event.currentBytes,
          expectedTotalBytes: event.totalBytes,
        ));
        if (event.imageBytes != null) {
          imageBytes = event.imageBytes;
          break;
        }
      }
    }
    if (imageBytes == null) {
      throw "Error: Empty response body.";
    }
    if (appdata.settings['enableCustomImageProcessing']) {
      var script = appdata.settings['customImageProcessing'].toString();
      if (!script.contains('function processImage')) {
        return imageBytes;
      }
      var func = JsEngine().runCode('''
        (() => {
          $script
          return processImage;
        })()
      ''');
      if (func is JSInvokable) {
        var autoFreeFunc = JSAutoFreeFunction(func);
        var result = autoFreeFunc([imageBytes, cid, eid, page, sourceKey]);
        if (result is Uint8List) {
          imageBytes = result;
        } else if (result is Future) {
          var futureResult = await result;
          if (futureResult is Uint8List) {
            imageBytes = futureResult;
          }
        } else if (result is Map) {
          var image = result['image'];
          if (image is Uint8List) {
            imageBytes = image;
          } else if (image is Future) {
            JSAutoFreeFunction? onCancel;
            if (result['onCancel'] is JSInvokable) {
              onCancel = JSAutoFreeFunction(result['onCancel']);
            }
            if (onCancel == null) {
              var futureImage = await image;
              if (futureImage is Uint8List) {
                imageBytes = futureImage;
              }
            } else {
              dynamic futureImage;
              image.then((value) {
                futureImage = value;
                futureImage ??= Uint8List(0);
              });
              while (futureImage == null) {
                try {
                  checkStop();
                }
                catch(e) {
                  onCancel([]);
                  rethrow;
                }
                await Future.delayed(Duration(milliseconds: 50));
              }
              if (futureImage is Uint8List) {
                imageBytes = futureImage;
              }
            }
          }
        }
      }
    }
    return imageBytes!;
  }

  @override
  Future<ReaderImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  String get key => "$imageKey@$sourceKey@$cid@$eid@$enableResize";

  /// Deletes the disk cache entry of this image only if the cached bytes
  /// themselves are empty or cannot be decoded, so that a manual retry
  /// downloads the image again.
  ///
  /// [data] may differ from the cached bytes because of custom image
  /// processing, and the entry may be replaced by another request at any
  /// time, so only the checked entry is deleted.
  @override
  Future<void> onInvalidImageData(Uint8List data) async {
    if (imageKey.startsWith('file://')) {
      return;
    }
    final cacheKey = ImageDownloader.comicImageCacheKey(
      imageKey,
      sourceKey,
      cid,
      eid,
    );
    try {
      final file = await CacheManager().findCache(cacheKey);
      if (file == null) {
        return;
      }
      if (await _canDecode(await file.readAsBytes())) {
        return;
      }
      await CacheManager().delete(cacheKey, onlyIfStoredIn: file);
    } catch (e, s) {
      Log.error("Image Loading", e, s);
    }
  }

  static Future<bool> _canDecode(Uint8List data) async {
    if (data.isEmpty) {
      return false;
    }
    try {
      final codec = await ui.instantiateImageCodec(data);
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
