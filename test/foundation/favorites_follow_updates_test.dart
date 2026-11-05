import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/favorites.dart';

void main() {
  test('read marker accepts a profile with no follow-updates folder', () {
    final previous = appdata.settings['followUpdatesFolder'];
    try {
      appdata.settings['followUpdatesFolder'] = null;
      expect(
        () => LocalFavoritesManager().markAsRead('synthetic', ComicType.local),
        returnsNormally,
      );
    } finally {
      appdata.settings['followUpdatesFolder'] = previous;
    }
  });
}
