import 'package:html/dom.dart' show Element;
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
  const VideoListing(this.uri, this.title, this.thumbnail, {this.duration});
  final String? duration;
  final Uri uri;
  final String title;
  final Uri? thumbnail;
}

List<VideoListing> parseHanimeListings(String body) {
  final root = html.parse(body).body;
  return root == null ? [] : _listings(root);
}

List<VideoListing> _listings(Element root) {
  final result = <Uri, VideoListing>{};
  for (final link in root.querySelectorAll('a[href*="watch?"]')) {
    final href = Uri.tryParse(link.attributes['href'] ?? '');
    if (href == null) continue;
    final target = _origin.resolveUri(href);
    final uri = hanimeWatchUri(target.toString());
    if (uri == null || result.containsKey(uri)) continue;

    var card = link;
    for (var depth = 0; depth < 3; depth++) {
      if (card.querySelector('.home-rows-videos-title, .video-title, .title') != null) break;
      final parent = card.parent;
      if (parent == null || identical(card, root) || parent.querySelectorAll('a[href*="watch?"]').length != 1) break;
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
      duration: card.querySelector('.duration, [class*="card-mobile-duration"]')?.text.trim(),
    );
    if (result.length >= 60) break;
  }
  return result.values.toList(growable: false);
}


class VideoSection {
  const VideoSection(this.title, this.videos);
  final String title;
  final List<VideoListing> videos;
}

class VideoDetails {
  const VideoDetails(this.description, this.related);
  final String description;
  final List<VideoListing> related;
}

List<VideoSection> parseHanimeHome(String body) {
  final root = html.parse(body).body;
  if (root == null) return [];
  final sections = <VideoSection>[];
  for (final row in root.querySelectorAll('#home-rows-wrapper > div')) {
    final title = row.querySelector('.home-rows-title, h2, h3, h4')?.text.trim();
    if (title == null || title.isEmpty) continue;
    final videos = _listings(row);
    if (videos.isNotEmpty) sections.add(VideoSection(title, videos));
  }
  if (sections.isNotEmpty) return sections;
  final videos = _listings(root);
  return videos.isEmpty ? [] : [VideoSection('', videos)];
}

VideoDetails parseHanimeDetails(String body, Uri uri) {
  final document = html.parse(body);
  final root = document.body;
  if (root == null) return const VideoDetails('', []);
  final description = root.querySelector('.video-caption-text')?.text.trim() ??
      document.querySelector('meta[property="og:description"]')?.attributes['content'] ??
      '';
  final related = _listings(root)
      .where((video) => video.uri != uri && video.thumbnail != null)
      .take(12)
      .toList();
  return VideoDetails(description, related);
}

class HanimeCatalog {
  final _client = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 12),
    receiveTimeout: const Duration(seconds: 18),
    followRedirects: false,
    responseType: ResponseType.plain,
    headers: {'Accept': 'text/html'},
  ));

  Future<List<VideoSection>> load(String query, CancelToken token) async {
    if (query.isEmpty) {
      return parseHanimeHome(await _fetch(_origin, token));
    }
    final uri = Uri.https('hanime1.me', '/search', {'query': query});
    final videos = parseHanimeListings(await _fetch(uri, token));
    return videos.isEmpty ? [] : [VideoSection(query, videos)];
  }

  Future<VideoDetails> details(Uri uri, CancelToken token) async {
    final watch = hanimeWatchUri(uri.toString());
    if (watch == null) throw const FormatException('Invalid watch URL');
    return parseHanimeDetails(await _fetch(watch, token), watch);
  }

  Future<String> _fetch(Uri uri, CancelToken token) async {
    final response = await _client.getUri<String>(uri, cancelToken: token);
    final body = response.data;
    if (body == null || body.isEmpty) throw const FormatException('Empty response');
    return body;
  }

  void close() => _client.close(force: true);
}
