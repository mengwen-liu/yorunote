import 'dart:async' show Future;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/network/images.dart';
import '../history.dart';
import 'base_image_provider.dart';
import 'history_image_provider.dart' as image_provider;

class HistoryImageProvider
    extends BaseImageProvider<image_provider.HistoryImageProvider> {
  /// Image provider for normal image.
  ///
  /// [url] is the url of the image. Local file path is also supported.
  const HistoryImageProvider(this.history);

  final History history;

  @override
  Future<Uint8List> load(chunkEvents, checkStop) async {
    var url = history.cover;
    if (!url.contains('/')) {
      var localComic = LocalManager().find(history.id, history.type);
      if (localComic != null) {
        return localComic.coverFile.readAsBytes();
      }
      var comicSource =
          history.type.comicSource ?? (throw "Comic source not found.");
      var comic = await comicSource.loadComicInfo!(history.id);
      checkStop();
      url = comic.data.cover;
      history.cover = url;
      HistoryManager().addHistory(history);
    }
    return ImageDownloader.loadCoverThumbnail(
      url,
      history.type.sourceKey,
      history.id,
      checkStop: checkStop,
      onProgress: (currentBytes, totalBytes) {
        chunkEvents.add(
          ImageChunkEvent(
            cumulativeBytesLoaded: currentBytes,
            expectedTotalBytes: totalBytes,
          ),
        );
      },
    );
  }

  /// Invalidates only the disk cache entry the broken cover was read from or
  /// written to; local comic covers are never deleted.
  @override
  Future<void> onInvalidImageData(Uint8List data) =>
      ImageDownloader.invalidateCoverCache(data);

  @override
  Future<HistoryImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture(this);
  }

  @override
  String get key => "history${history.id}${history.type.value}";
}
