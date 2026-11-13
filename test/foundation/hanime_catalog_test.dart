import 'package:flutter_test/flutter_test.dart';
import 'package:venera/foundation/hanime_catalog.dart';

void main() {
  test('normalizes watch URLs and rejects other hosts or paths', () {
    expect(
      hanimeWatchUri(' https://hanime1.me/watch?v=7&extra=1 ').toString(),
      'https://hanime1.me/watch?v=7',
    );
    expect(hanimeWatchUri('https://hanime1.me.evil.test/watch?v=7'), isNull);
    expect(hanimeWatchUri('https://hanime1.me/search?v=7'), isNull);
    expect(hanimeWatchUri('http://hanime1.me/watch?v=7'), isNull);
    expect(hanimeWatchUri('https://hanime1.me/watch?v=no'), isNull);
  });

  test('reads both catalog layouts and filters unrelated links', () {
    final items = parseHanimeListings('''
      <a href="/watch?v=1"><img data-src="/one.jpg">
        <div class="home-rows-videos-title">First video</div></a>
      <div class="horizontal-card"><a href="/watch?v=2">
        <img src="https://media.example/two.jpg"></a>
        <h4 class="video-title">Second video</h4></div>
      <a href="/watch?v=1">Duplicate</a>
      <a href="https://example.test/watch?v=3">External</a>
    ''');
    expect(items.map((item) => item.title), ['First video', 'Second video']);
    expect(items.first.thumbnail.toString(), 'https://hanime1.me/one.jpg');
    expect(items.last.thumbnail.toString(), 'https://media.example/two.jpg');
  });
}
