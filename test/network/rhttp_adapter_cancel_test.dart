// RHttpAdapter with and without a Dio cancel signal, against a raw local
// server: requests without a CancelToken behave as before, and a cancelled
// request is torn down in rhttp (the server sees the connection closed)
// without leaving an unhandled rhttp stream error behind.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:venera/network/app_dio.dart';

import 'raw_image_server.dart';
import 'thumbnail_test_support.dart';

void main() {
  final unused = CoverServer();
  final server = RawImageServer();

  setUpAll(() async {
    await initCoverTestEnvironment(unused);
    if (hasNativeHttp) await server.start();
  });

  tearDownAll(() async {
    await unused.stop();
    if (hasNativeHttp) await server.stop();
  });

  AppDio streamDio() => AppDio(BaseOptions(responseType: ResponseType.stream));

  Future<Uint8List> readAll(Stream<Uint8List> s) async {
    final b = BytesBuilder();
    await for (final c in s) {
      b.add(c);
    }
    return b.takeBytes();
  }

  String path(String name, RawMode mode) {
    final p = '/adapter/$name.png';
    server.images[p] = png(3, width: 64, height: 64);
    server.modes[p] = mode;
    return p;
  }

  test(
    'without a CancelToken a full response is read as before',
    () async {
      final p = path('plain', RawMode.immediate);
      final res = await streamDio().request<ResponseBody>(server.url(p));
      expect(await readAll(res.data!.stream), server.images[p]);
    },
    skip: !hasNativeHttp,
  );

  test(
    'with an unused CancelToken a full response is read as before',
    () async {
      final p = path('token-unused', RawMode.immediate);
      final res = await streamDio().request<ResponseBody>(
        server.url(p),
        cancelToken: CancelToken(),
      );
      expect(await readAll(res.data!.stream), server.images[p]);
    },
    skip: !hasNativeHttp,
  );

  for (final withToken in [false, true]) {
    test('a broken body still fails (CancelToken: $withToken)', () async {
      final p = path('truncate-$withToken', RawMode.truncate);
      final res = await streamDio().request<ResponseBody>(
        server.url(p),
        cancelToken: withToken ? CancelToken() : null,
      );
      await expectLater(readAll(res.data!.stream), throwsA(anything));
    }, skip: !hasNativeHttp);
  }

  test('cancel while waiting for headers: Dio gives up at once, rhttp '
      'closes the connection when the headers arrive', () async {
    final p = path('cancel-headers', RawMode.holdHeaders);
    final token = CancelToken();
    final req = streamDio().request<ResponseBody>(
      server.url(p),
      cancelToken: token,
    );
    await server.until(() => server.count(p) == 1);
    token.cancel();
    await expectLater(
      req,
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.cancel,
        ),
      ),
    );
    final h = server.heldFor(p).single;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(h.isClosedByClient, isFalse, reason: 'not torn down before headers');
    await h.sendHeadersAndStall();
    await h.closedByClient.timeout(const Duration(seconds: 10));
    expect(h.isClosedByClient, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }, skip: !hasNativeHttp);

  test(
    'cancel inside the body closes the connection, no stray error',
    () async {
      final p = path('cancel-body', RawMode.stallBody);
      final token = CancelToken();
      final res = await streamDio().request<ResponseBody>(
        server.url(p),
        cancelToken: token,
      );
      final first = Completer<void>();
      final done = Completer<Object?>();
      res.data!.stream.listen(
        (_) {
          if (!first.isCompleted) first.complete();
        },
        onError: (Object e) {
          if (!done.isCompleted) done.complete(e);
        },
        onDone: () {
          if (!done.isCompleted) done.complete(null);
        },
      );
      await first.future.timeout(const Duration(seconds: 10));
      token.cancel();
      final error = await done.future.timeout(const Duration(seconds: 10));
      expect(error, isA<DioException>());
      final h = server.heldFor(p).single;
      await h.closedByClient.timeout(const Duration(seconds: 10));
      expect(h.isClosedByClient, isTrue);
      // Gives rhttp time to deliver its own cancel error; an unhandled error
      // would fail this test.
      await Future<void>.delayed(const Duration(milliseconds: 300));
    },
    skip: !hasNativeHttp,
  );
}
