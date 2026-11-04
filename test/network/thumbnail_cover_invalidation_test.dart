// Hook-level tests of cover cache invalidation (candidate API only).
//
// The bytes are obtained through ImageDownloader.loadCoverThumbnail, the same
// call the cover providers make, so they carry the disk cache key they were
// read from. The provider's onInvalidImageData hook is then called directly,
// which lets the test place a repair between the read and the invalidation.

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/image_provider/cached_image.dart';
import 'package:venera/foundation/image_provider/history_image_provider.dart';
import 'package:venera/network/images.dart';

import 'thumbnail_test_support.dart';

void main() {
  final server = CoverServer();
  final src = testSource('thumb_invalidation_src');

  setUpAll(() async {
    await initCoverTestEnvironment(server, sources: [src]);
  });

  tearDownAll(() => server.stop());

  setUp(() => PaintingBinding.instance.imageCache.clear());

  Future<Uint8List> readCover(String url, String cid) =>
      ImageDownloader.loadCoverThumbnail(url, src.key, cid, checkStop: () {});

  testWidgets('the entry the broken bytes came from is deleted', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final url = server.url('/i/broken.png');
      final key = thumbDiskKey(url, src.key, 'i1');
      final otherKey = thumbDiskKey(server.url('/i/other.png'), src.key, 'i1');
      await CacheManager().writeCache(key, corruptPng);
      await CacheManager().writeCache(otherKey, corruptPng);
      final broken = await readCover(url, 'i1');
      expect(broken, corruptPng);
      // ignore: invalid_use_of_protected_member
      await CachedImageProvider(
        url,
        sourceKey: src.key,
        cid: 'i1',
      ).onInvalidImageData(broken);
      expect(await CacheManager().findCache(key), isNull);
      expect(
        await CacheManager().findCache(otherKey),
        isNotNull,
        reason: 'only the entry the bytes came from',
      );
    });
  });

  testWidgets('an entry repaired after the read is kept', (tester) async {
    await tester.runAsync(() async {
      final url = server.url('/i/repaired.png');
      final key = thumbDiskKey(url, src.key, 'i2');
      await CacheManager().writeCache(key, corruptPng);
      // A failing load read the broken entry ...
      final stale = await readCover(url, 'i2');
      // ... and another load stored a good image before the invalidation.
      await CacheManager().writeCache(key, png(5));
      // ignore: invalid_use_of_protected_member
      await HistoryImageProvider(
        testHistory('i2', src, url),
      ).onInvalidImageData(stale);
      final file = await CacheManager().findCache(key);
      expect(await file!.readAsBytes(), png(5));
    });
  });

  testWidgets('bytes that did not come from the cover cache delete nothing', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final url = server.url('/i/foreign.png');
      final key = thumbDiskKey(url, src.key, 'i3');
      await CacheManager().writeCache(key, corruptPng);
      // Same content, but read elsewhere (e.g. a local file).
      final foreign = Uint8List.fromList(corruptPng);
      // ignore: invalid_use_of_protected_member
      await CachedImageProvider(
        url,
        sourceKey: src.key,
        cid: 'i3',
      ).onInvalidImageData(foreign);
      expect(await CacheManager().findCache(key), isNotNull);
    });
  });
}
