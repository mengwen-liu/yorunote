// A local HTTP/1.1 image server that hands each request over to the test as
// a raw socket, so the test decides exactly when headers and body bytes are
// sent and can observe when the client closes the connection (which is the
// evidence that the underlying request was really torn down).

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// How the server answers a request for a path.
enum RawMode {
  /// Full response right away.
  immediate,

  /// Nothing (not even headers) until [HeldRequest.release].
  holdHeaders,

  /// Headers and the first half of the body, then nothing until release.
  stallBody,

  /// An HTTP status error right away.
  status,

  /// Headers announcing the full length, half the body, then the server
  /// closes the connection (a broken response).
  truncate,
}

class HeldRequest {
  HeldRequest(this.path, this._socket, this._body, this.mode) {
    _socket.listen(
      (_) {},
      onDone: _markClosed,
      onError: (_) => _markClosed(),
      cancelOnError: true,
    );
  }

  final String path;
  final Socket _socket;
  final Uint8List _body;
  final RawMode mode;

  final _closed = Completer<void>();
  bool _finished = false;

  /// True once the server finished the response itself.
  bool get finished => _finished;

  /// Completes when the connection is closed by the client (or broken)
  /// before the server finished the response.
  Future<void> get closedByClient => _closed.future;

  bool get isClosedByClient => _closed.isCompleted && !_finished;

  void _markClosed() {
    if (!_closed.isCompleted) _closed.complete();
  }

  String _headers(int length) =>
      'HTTP/1.1 200 OK\r\n'
      'Content-Type: image/png\r\n'
      'Content-Length: $length\r\n'
      'Connection: close\r\n\r\n';

  void _sendHeadersAndHalf() {
    _socket.write(_headers(_body.length));
    _socket.add(_body.sublist(0, _body.length ~/ 2));
  }

  bool _headersSent = false;

  /// For a request held before its headers: sends the headers and half of
  /// the body, then waits again (like [RawMode.stallBody]).
  Future<void> sendHeadersAndStall() async {
    if (_headersSent || _finished || _closed.isCompleted) return;
    _headersSent = true;
    try {
      _sendHeadersAndHalf();
      await _socket.flush();
    } catch (_) {
      // The client went away in the meantime.
    }
  }

  /// Sends the rest of the response and closes the connection.
  Future<void> release() async {
    if (_finished || _closed.isCompleted) return;
    _finished = true;
    try {
      if (mode == RawMode.stallBody || _headersSent) {
        _socket.add(_body.sublist(_body.length ~/ 2));
      } else {
        _socket.write(_headers(_body.length));
        _socket.add(_body);
      }
      await _socket.flush();
      await _socket.close();
    } catch (_) {
      // The client went away in the meantime.
    }
    _markClosed();
  }
}

class RawImageServer {
  HttpServer? _server;

  final images = <String, Uint8List>{};
  final modes = <String, RawMode>{};
  final statusCodes = <String, int>{};
  final requests = <String, int>{};
  final held = <HeldRequest>[];

  int total = 0;
  int active = 0;
  int peakActive = 0;

  final _waiters = <(bool Function(), Completer<void>)>[];

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server!.listen(_handle);
  }

  String url(String path) => 'http://127.0.0.1:${_server!.port}$path';

  int count(String path) => requests[path] ?? 0;

  Future<void> _handle(HttpRequest request) async {
    final path = request.uri.path;
    requests[path] = (requests[path] ?? 0) + 1;
    total++;
    final mode = modes[path] ?? RawMode.immediate;
    final body = images[path] ?? Uint8List(0);
    if (mode == RawMode.status || images[path] == null) {
      request.response.statusCode = statusCodes[path] ?? HttpStatus.notFound;
      request.response.headers.set('connection', 'close');
      await request.response.close();
      _notify();
      return;
    }
    final socket = await request.response.detachSocket(writeHeaders: false);
    final h = HeldRequest(path, socket, body, mode);
    held.add(h);
    active++;
    if (active > peakActive) peakActive = active;
    unawaited(
      h.closedByClient.then((_) {
        active--;
        _notify();
      }),
    );
    switch (mode) {
      case RawMode.immediate:
        unawaited(h.release());
      case RawMode.stallBody:
        h._sendHeadersAndHalf();
        await socket.flush();
      case RawMode.truncate:
        h._finished = true;
        h._sendHeadersAndHalf();
        await socket.flush();
        socket.destroy();
        h._markClosed();
      case RawMode.holdHeaders:
      case RawMode.status:
        break;
    }
    _notify();
  }

  void _notify() {
    _waiters.removeWhere((w) {
      if (w.$1()) {
        w.$2.complete();
        return true;
      }
      return false;
    });
  }

  /// Completes once [condition] holds; re-checked on every server event.
  Future<void> until(bool Function() condition, {Duration? timeout}) {
    final f = condition()
        ? Future<void>.value()
        : (() {
            final c = Completer<void>();
            _waiters.add((condition, c));
            return c.future;
          })();
    return f.timeout(timeout ?? const Duration(seconds: 20));
  }

  /// Held requests for [path] in arrival order.
  List<HeldRequest> heldFor(String path) =>
      held.where((h) => h.path == path).toList();

  Future<void> releaseAll() async {
    for (final h in [...held]) {
      await h.release();
    }
  }

  Future<void> stop() async {
    await releaseAll();
    await _server?.close(force: true);
  }
}
