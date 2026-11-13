import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

final _idPattern = RegExp(r'^\d+$');
final _origin = Uri.https('hanime1.me');

bool _isSite(Uri uri) =>
    uri.scheme == 'https' &&
    uri.host == 'hanime1.me' &&
    uri.port == 443 &&
    uri.userInfo.isEmpty;

Uri? hanimeWatchUri(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null || !_isSite(uri) || uri.path != '/watch') return null;
  final id = uri.queryParameters['v'];
  if (id == null || !_idPattern.hasMatch(id)) return null;
  return Uri.https('hanime1.me', '/watch', {'v': id});
}

class VideoListing {
  const VideoListing(this.uri, this.title, this.thumbnail);
  final Uri uri;
  final String title;
  final Uri? thumbnail;
}

List<VideoListing> parseHanimeListings(String body) {
  final document = html.parse(body);
  final result = <Uri, VideoListing>{};
  for (final link in document.querySelectorAll('a[href*="watch?"]')) {
    final href = Uri.tryParse(link.attributes['href'] ?? '');
    if (href == null) continue;
    final target = _origin.resolveUri(href);
    final uri = hanimeWatchUri(target.toString());
    if (uri == null || result.containsKey(uri)) continue;

    var card = link;
    for (var depth = 0; depth < 3; depth++) {
      if (card.querySelector('.home-rows-videos-title, .video-title, .title') != null) break;
      final parent = card.parent;
      if (parent == null || parent.querySelectorAll('a[href*="watch?"]').length != 1) break;
      card = parent;
    }
    final image = card.querySelector('img');
    final title = (card.querySelector('.home-rows-videos-title, .video-title, .title')?.text ??
            link.attributes['title'] ??
            image?.attributes['alt'] ??
            link.text)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (title.isEmpty) continue;
    final imageSource = image?.attributes['data-src'] ?? image?.attributes['src'];
    final imageUri = imageSource == null ? null : Uri.tryParse(imageSource);
    final thumbnail = imageUri == null ? null : _origin.resolveUri(imageUri);
    result[uri] = VideoListing(
      uri,
      title,
      thumbnail != null && thumbnail.scheme == 'https' && thumbnail.userInfo.isEmpty
          ? thumbnail
          : null,
    );
    if (result.length >= 60) break;
  }
  return result.values.toList(growable: false);
}

class HanimeCatalog {
  final _client = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 18),
    followRedirects: false,
    responseType: ResponseType.plain,
    headers: {'Accept': 'text/html'},
  ));

  Future<List<VideoListing>> load(String query, CancelToken token) async {
    final uri = query.isEmpty
        ? Uri.https('hanime1.me', '/')
        : Uri.https('hanime1.me', '/search', {'query': query});
    final response = await _client.getUri<String>(uri, cancelToken: token);
    final body = response.data;
    if (body == null || body.isEmpty) throw const FormatException('Empty catalog');
    return parseHanimeListings(body);
  }

  void close() => _client.close(force: true);
}
