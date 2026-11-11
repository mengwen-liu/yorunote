// Synthetic comic server for Yorunote network acceptance tests.
//
// Everything it serves is generated here: comic list, details, chapter page
// lists, cover and page PNGs, and the comic source script itself
// (yorunote_synthetic_source.js, with the public base URL filled in). No real
// comics, accounts, cookies or reading history are involved.
//
// Pure dart:io, so it runs on a computer with `dart run` (see serve.dart) and
// can also be started in-process by tests.
//
// Control endpoints (GET, so a browser or curl can drive them):
//   /__control/delay?ms=N          delay every image response by N ms
//   /__control/pause               hold image responses ...
//   /__control/release             ... until released
//   /__control/fail?match=S&status=500   image paths containing S answer an
//                                  HTTP error
//   /__control/broken?match=S      ... answer undecodable PNG bytes
//   /__control/empty?match=S       ... answer an empty body
//   /__control/recover?match=S     remove fail/broken/empty rules for S
//                                  (no match: remove all rules)
//   /__control/reset               rules, pause, delay and counters
//   /__stats                       JSON counters
//   /                              status page

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Number of comics in the synthetic list.
const syntheticComicCount = 40;

/// Comic whose cover is served XOR-encoded (needs the source's onResponse).
const xorComicId = 'c37';

/// Comic listed with a `cover.` placeholder that is resolved via loadInfo.
const placeholderComicId = 'c38';

const _pagesPerChapter = 5;
const _chapters = 2;

class _Rule {
  _Rule(this.kind, this.match, [this.status = 500]);
  final String kind; // fail | broken | empty
  final String match;
  final int status;
}

class SyntheticServer {
  SyntheticServer({required this.sourceTemplate});

  /// Content of yorunote_synthetic_source.js with `__BASE_URL__`.
  final String sourceTemplate;

  HttpServer? _server;
  late String baseUrl;

  final requests = <String, int>{};
  int total = 0;
  int activeImages = 0;
  int peakImages = 0;
  int imageRequests = 0;

  Duration delay = Duration.zero;
  Completer<void>? _pause;
  final _rules = <_Rule>[];
  final _cache = <String, Uint8List>{};

  int get port => _server!.port;

  final _activeWaiters = <(int, Completer<void>)>[];

  /// Completes once at least [n] image requests are being served at once.
  Future<void> untilActive(
    int n, {
    Duration timeout = const Duration(seconds: 20),
  }) {
    if (activeImages >= n) return Future.value();
    final c = Completer<void>();
    _activeWaiters.add((n, c));
    return c.future.timeout(timeout);
  }

  /// Starts listening. [publicUrl] is the address devices use to reach this
  /// server (it is written into the source script); by default it is
  /// `http://host:port` as bound.
  Future<void> start({
    String host = '127.0.0.1',
    int port = 0,
    String? publicUrl,
  }) async {
    _server = await HttpServer.bind(host, port);
    baseUrl = (publicUrl ?? 'http://$host:${_server!.port}').replaceAll(
      RegExp(r'/+$'),
      '',
    );
    _server!.listen(_handle);
  }

  Future<void> stop() async {
    _pause?.complete();
    await _server?.close(force: true);
  }

  String get sourceScript => sourceTemplate.replaceAll('__BASE_URL__', baseUrl);

  Map<String, dynamic> stats() => {
    'total_requests': total,
    'image_requests': imageRequests,
    'active_image_requests': activeImages,
    'peak_active_image_requests': peakImages,
    'paused': _pause != null,
    'delay_ms': delay.inMilliseconds,
    'rules': [
      for (final r in _rules)
        {
          'kind': r.kind,
          'match': r.match,
          if (r.kind == 'fail') 'status': r.status,
        },
    ],
    'per_path': requests,
  };

  void resetCounters() {
    requests.clear();
    total = 0;
    imageRequests = 0;
    peakImages = activeImages;
  }

  int count(String path) => requests[path] ?? 0;

  Future<void> _handle(HttpRequest req) async {
    final path = req.uri.path;
    final res = req.response;
    res.headers.set('cache-control', 'no-store');
    try {
      if (path.startsWith('/__')) {
        _control(req);
        return;
      }
      requests[path] = (requests[path] ?? 0) + 1;
      total++;
      if (path == '/source.js') {
        res.headers.contentType = ContentType(
          'application',
          'javascript',
          charset: 'utf-8',
        );
        res.write(sourceScript);
      } else if (path.startsWith('/api/')) {
        _api(req);
      } else if (path.startsWith('/img/')) {
        await _image(req);
        return;
      } else {
        res.statusCode = HttpStatus.notFound;
      }
    } catch (e) {
      res.statusCode = HttpStatus.internalServerError;
      res.write('$e');
    }
    await res.close();
  }

  void _json(HttpResponse res, Object value) {
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode(value));
  }

  static String comicId(int i) => 'c${i.toString().padLeft(2, '0')}';

  String coverUrl(String id) => '$baseUrl/img/cover/$id.png';

  Map<String, dynamic> _comic(int i) {
    final id = comicId(i);
    return {
      'id': id,
      'title': '合成漫畫 $id',
      'subtitle': i == 37
          ? 'onResponse 封面'
          : i == 38
          ? 'cover. 佔位封面'
          : '合成資料',
      'cover': id == placeholderComicId ? 'cover.$id' : coverUrl(id),
    };
  }

  void _api(HttpRequest req) {
    final seg = req.uri.pathSegments; // api, ...
    final res = req.response;
    if (seg.length == 2 && seg[1] == 'explore') {
      final page = int.tryParse(req.uri.queryParameters['page'] ?? '1') ?? 1;
      const perPage = 20;
      final start = (page - 1) * perPage + 1;
      final comics = [
        for (
          var i = start;
          i < start + perPage && i <= syntheticComicCount;
          i++
        )
          _comic(i),
      ];
      _json(res, {
        'comics': comics,
        'maxPage': (syntheticComicCount / perPage).ceil(),
      });
    } else if (seg.length == 3 && seg[1] == 'comic') {
      final id = seg[2];
      _json(res, {
        'title': '合成漫畫 $id',
        'subtitle': '合成資料',
        'cover': coverUrl(id),
        'description': '由 Yorunote 合成測試伺服器產生的內容。',
        'tags': {
          '類型': ['合成'],
        },
        'chapters': {for (var c = 1; c <= _chapters; c++) '$c': '第 $c 話'},
      });
    } else if (seg.length == 5 && seg[1] == 'comic' && seg[3] == 'ep') {
      final id = seg[2];
      final ep = seg[4];
      _json(res, {
        'images': [
          for (var p = 1; p <= _pagesPerChapter; p++)
            '$baseUrl/img/page/$id/$ep/$p.png',
        ],
      });
    } else {
      res.statusCode = HttpStatus.notFound;
    }
  }

  Future<void> _image(HttpRequest req) async {
    final path = req.uri.path;
    final res = req.response;
    imageRequests++;
    activeImages++;
    if (activeImages > peakImages) peakImages = activeImages;
    _activeWaiters.removeWhere((w) {
      if (activeImages >= w.$1) {
        w.$2.complete();
        return true;
      }
      return false;
    });
    try {
      final pause = _pause;
      if (pause != null) await pause.future;
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      final rule = _rules.lastWhereOrNullMatch(path);
      if (rule?.kind == 'fail') {
        res.statusCode = rule!.status;
        res.write('synthetic error ${rule.status}');
      } else if (rule?.kind == 'empty') {
        res.headers.contentType = ContentType('image', 'png');
        res.contentLength = 0;
      } else {
        final bytes = rule?.kind == 'broken'
            ? _brokenPng
            : _imageBytes(req.uri.pathSegments);
        if (bytes == null) {
          res.statusCode = HttpStatus.notFound;
        } else {
          res.headers.contentType = ContentType('image', 'png');
          res.contentLength = bytes.length;
          res.add(bytes);
        }
      }
      await res.close();
    } catch (_) {
      // Client went away.
    } finally {
      activeImages--;
    }
  }

  Uint8List? _imageBytes(List<String> seg) {
    final key = seg.join('/');
    final cached = _cache[key];
    if (cached != null) return cached;
    Uint8List? bytes;
    if (seg.length == 3 && seg[1] == 'cover' && seg[2].endsWith('.png')) {
      final id = seg[2].substring(0, seg[2].length - 4);
      final n = int.tryParse(id.substring(1)) ?? 0;
      bytes = coverPng(n);
      if (id == xorComicId) {
        bytes = Uint8List.fromList([for (final b in bytes) b ^ 0x5a]);
      }
    } else if (seg.length == 5 && seg[1] == 'page') {
      final n = int.tryParse(seg[4].replaceAll('.png', '')) ?? 1;
      bytes = pagePng(n);
    }
    if (bytes != null) _cache[key] = bytes;
    return bytes;
  }

  void _control(HttpRequest req) {
    final res = req.response;
    final q = req.uri.queryParameters;
    final match = q['match'] ?? '';
    switch (req.uri.path) {
      case '/__stats':
        _json(res, stats());
      case '/__control/delay':
        delay = Duration(milliseconds: int.tryParse(q['ms'] ?? '0') ?? 0);
        _json(res, stats());
      case '/__control/pause':
        _pause ??= Completer<void>();
        _json(res, stats());
      case '/__control/release':
        _pause?.complete();
        _pause = null;
        _json(res, stats());
      case '/__control/fail':
        _rules.add(
          _Rule('fail', match, int.tryParse(q['status'] ?? '') ?? 500),
        );
        _json(res, stats());
      case '/__control/broken':
        _rules.add(_Rule('broken', match));
        _json(res, stats());
      case '/__control/empty':
        _rules.add(_Rule('empty', match));
        _json(res, stats());
      case '/__control/recover':
        _rules.removeWhere((r) => match.isEmpty || r.match == match);
        _json(res, stats());
      case '/__control/reset':
        _rules.clear();
        delay = Duration.zero;
        _pause?.complete();
        _pause = null;
        resetCounters();
        _json(res, stats());
      case '/':
      case '/__':
        res.headers.contentType = ContentType.html;
        res.write(_statusPage());
      default:
        res.statusCode = HttpStatus.notFound;
    }
    res.close();
  }

  String _statusPage() {
    final s = const HtmlEscape().convert(
      const JsonEncoder.withIndent('  ').convert(stats()),
    );
    return '<!doctype html><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width">'
        '<meta http-equiv="refresh" content="2">'
        '<title>Yorunote synthetic server</title>'
        '<h3>Yorunote 合成伺服器</h3><p>來源：$baseUrl/source.js</p>'
        '<pre>$s</pre>';
  }

  static final Uint8List _brokenPng = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    ...List<int>.filled(64, 0x5a),
  ]);
}

extension on List<_Rule> {
  _Rule? lastWhereOrNullMatch(String path) {
    for (var i = length - 1; i >= 0; i--) {
      if (this[i].match.isNotEmpty && path.contains(this[i].match)) {
        return this[i];
      }
    }
    return null;
  }
}

/// A 240x320 RGB cover: a colour per comic and [n] mod 8 + 1 white bars.
Uint8List coverPng(int n) {
  const w = 240, h = 320;
  final r = (n * 67) % 200 + 40,
      g = (n * 131) % 200 + 40,
      b = (n * 29) % 200 + 40;
  final bars = n % 8 + 1;
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0);
    final bar = (y ~/ 20) < bars * 2 && (y ~/ 20).isOdd;
    for (var x = 0; x < w; x++) {
      if (bar && x > 30 && x < w - 30) {
        raw.add([250, 250, 250]);
      } else {
        raw.add([r, g, b]);
      }
    }
  }
  return _png(w, h, 2, raw.takeBytes());
}

/// A 600x900 grayscale page with [n] dark bars.
Uint8List pagePng(int n) {
  const w = 600, h = 900;
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0);
    final dark = (y ~/ 60).isOdd && (y ~/ 120) < n;
    raw.add(List<int>.filled(w, dark ? 40 : 230));
  }
  return _png(w, h, 0, raw.takeBytes());
}

Uint8List _png(int w, int h, int colorType, List<int> raw) {
  List<int> chunk(String type, List<int> data) {
    final body = [...ascii.encode(type), ...data];
    return [..._u32(data.length), ...body, ..._u32(_crc32(body))];
  }

  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    ...chunk('IHDR', [..._u32(w), ..._u32(h), 8, colorType, 0, 0, 0]),
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

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = c & 1 != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final b in bytes) {
    crc = _crcTable[(crc ^ b) & 0xff] ^ (crc >> 8);
  }
  return crc ^ 0xffffffff;
}
