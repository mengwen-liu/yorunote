import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:rhttp/rhttp.dart' as rhttp;
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/network/cache.dart';
import 'package:venera/network/proxy.dart';

import '../foundation/app.dart';
import 'cloudflare.dart';
import 'cookie_jar.dart';

export 'package:dio/dio.dart';

class MyLogInterceptor implements Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    Log.error("Network",
        "${err.requestOptions.method} ${err.requestOptions.path}\n$err\n${err.response?.data.toString()}");
    switch (err.type) {
      case DioExceptionType.badResponse:
        var statusCode = err.response?.statusCode;
        if (statusCode != null) {
          err = err.copyWith(
              message: "Invalid Status Code: $statusCode. "
                  "${_getStatusCodeInfo(statusCode)}");
        }
      case DioExceptionType.connectionTimeout:
        err = err.copyWith(message: "Connection Timeout");
      case DioExceptionType.receiveTimeout:
        err = err.copyWith(
            message: "Receive Timeout: "
                "This indicates that the server is too busy to respond");
      case DioExceptionType.unknown:
        if (err.toString().contains("Connection terminated during handshake")) {
          err = err.copyWith(
              message: "Connection terminated during handshake: "
                  "This may be caused by the firewall blocking the connection "
                  "or your requests are too frequent.");
        } else if (err.toString().contains("Connection reset by peer")) {
          err = err.copyWith(
              message: "Connection reset by peer: "
                  "The error is unrelated to app, please check your network.");
        }
      default:
        {}
    }
    handler.next(err);
  }

  static const errorMessages = <int, String>{
    400: "The Request is invalid.",
    401: "The Request is unauthorized.",
    403: "No permission to access the resource. Check your account or network.",
    404: "Not found.",
    429: "Too many requests. Please try again later.",
  };

  String _getStatusCodeInfo(int? statusCode) {
    if (statusCode != null && statusCode >= 500) {
      return "This is server-side error, please try again later. "
          "Do not report this issue.";
    } else {
      return errorMessages[statusCode] ?? "";
    }
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    var headers = response.headers.map.map((key, value) => MapEntry(
        key.toLowerCase(), value.length == 1 ? value.first : value.toString()));
    headers.remove("cookie");
    String content;
    if (response.data is List<int>) {
      try {
        content = utf8.decode(response.data, allowMalformed: false);
      } catch (e) {
        content = "<Bytes>\nlength:${response.data.length}";
      }
    } else {
      content = response.data.toString();
    }
    Log.addLog(
        (response.statusCode != null && response.statusCode! < 400)
            ? LogLevel.info
            : LogLevel.error,
        "Network",
        "Response ${response.realUri.toString()} ${response.statusCode}\n"
            "headers:\n$headers\n$content");
    handler.next(response);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    const String headerMask = "********";
    const String dataMask = "****** DATA_PROTECTED ******";
    Log.info(
        "Network",
        "${options.method} ${options.uri}\n"
            "headers:\n${
              options.extra.containsKey("maskHeadersInLog")
                ? options.headers.map((key, value) =>
                  MapEntry(
                    key,
                    options.extra["maskHeadersInLog"].contains(key)
                      ? headerMask
                      : value
                  ))
                : options.headers
            }\n"
            "data:\n${
              options.extra["maskDataInLog"] == true
                ? dataMask
                : options.data
            }"
    );
    options.connectTimeout = const Duration(seconds: 15);
    options.receiveTimeout = const Duration(seconds: 15);
    options.sendTimeout = const Duration(seconds: 15);
    handler.next(options);
  }
}

class AppDio with DioMixin {
  AppDio([BaseOptions? options]) {
    this.options = options ?? BaseOptions();
    httpClientAdapter = RHttpAdapter();
    if (App.isInitialized) {
      interceptors.add(CookieManagerSql(SingleInstanceCookieJar.instance!));
      interceptors.add(NetworkCacheManager());
      interceptors.add(CloudflareInterceptor());
      interceptors.add(MyLogInterceptor());
    }
  }

  static final Map<String, bool> _requests = {};

  @override
  Future<Response<T>> request<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    if (options?.headers?['prevent-parallel'] == 'true') {
      while (_requests.containsKey(path)) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
      _requests[path] = true;
      options!.headers!.remove('prevent-parallel');
    }
    try {
      return super.request<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: options,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } finally {
      if (_requests.containsKey(path)) {
        _requests.remove(path);
      }
    }
  }
}

class RHttpAdapter implements HttpClientAdapter {
  /// [RequestOptions.extra] key that asks for a total timeout (a [Duration])
  /// on each HTTP attempt of that request.
  ///
  /// It is rhttp's `TimeoutSettings.timeout`: in rhttp 0.15.1 it is passed to
  /// reqwest's client `timeout`, which runs from the start of the attempt
  /// (DNS, connection, TLS, redirects, request, waiting for the headers) until
  /// the response body has been read completely. When it expires before the
  /// headers, rhttp reports a timeout error and the connection is closed by
  /// Rust itself; after the headers, the body stream fails with an error. It
  /// does not include queueing, retries made by callers, or the time the
  /// caller takes to consume the body after it has been received.
  ///
  /// Requests without this key keep the old behaviour (no total timeout).
  static const totalTimeoutKey = 'rhttpTotalTimeout';

  Future<rhttp.ClientSettings> get settings => _buildSettings(null);

  Future<rhttp.ClientSettings> _buildSettings(Duration? totalTimeout) async {
    var proxy = await getProxy();

    return rhttp.ClientSettings(
      proxySettings: proxy == null
          ? const rhttp.ProxySettings.noProxy()
          : rhttp.ProxySettings.proxy(proxy),
      redirectSettings: const rhttp.RedirectSettings.limited(5),
      timeoutSettings: rhttp.TimeoutSettings(
        timeout: totalTimeout,
        connectTimeout: const Duration(seconds: 15),
        keepAliveTimeout: const Duration(seconds: 60),
        keepAlivePing: const Duration(seconds: 30),
      ),
      throwOnStatusCode: false,
      dnsSettings: rhttp.DnsSettings.static(overrides: _getOverrides()),
      tlsSettings: rhttp.TlsSettings(
        sni: appdata.settings['sni'] != false,
        verifyCertificates: appdata.settings['ignoreBadCertificate'] != true,
      ),
    );
  }

  static Map<String, List<String>> _getOverrides() {
    if (!appdata.settings['enableDnsOverrides'] == true) {
      return {};
    }
    var config = appdata.settings["dnsOverrides"];
    var result = <String, List<String>>{};
    if (config is Map) {
      for (var entry in config.entries) {
        if (entry.key is String && entry.value is String) {
          result[entry.key] = [entry.value];
        }
      }
    }
    return result;
  }

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.headers['User-Agent'] == null &&
        options.headers['user-agent'] == null) {
      options.headers['User-Agent'] = "venera/v${App.version}";
    }

    // Without a cancel signal the request is made exactly as before.
    //
    // With one, the rhttp request is cancelled only after its headers have
    // arrived. rhttp 0.15.1 (built with panic = "abort") cancels by dropping
    // the Rust future; if that future is waiting for the reply of a Dart
    // callback (onResponse / onError, i.e. around the arrival of the
    // headers), flutter_rust_bridge 2.11.1 panics when the reply comes and
    // the whole process aborts. Once the headers are in and one event-loop
    // turn has passed, the Rust side only streams the body, so dropping it
    // is safe. A request still waiting for its headers is therefore not torn
    // down until they arrive.
    rhttp.CancelToken? cancelToken;
    var cancelled = false;
    var headersReceived = false;
    var rhttpCancelScheduled = false;
    void scheduleRhttpCancel() {
      final token = cancelToken;
      if (token == null || rhttpCancelScheduled) return;
      rhttpCancelScheduled = true;
      Timer.run(() {
        token.cancel().catchError((Object e, StackTrace s) {
          Log.error("Network", "Failed to cancel request: $e", s);
        });
      });
    }

    if (cancelFuture != null) {
      cancelToken = rhttp.CancelToken();
      unawaited(
        cancelFuture.then((_) {
          cancelled = true;
          if (headersReceived) scheduleRhttpCancel();
        }),
      );
    }

    final requested = options.extra[totalTimeoutKey];
    final totalTimeout = requested is Duration && requested > Duration.zero
        ? requested
        : null;

    var res = await rhttp.Rhttp.request(
      method: rhttp.HttpMethod(options.method),
      url: options.uri.toString(),
      settings: await _buildSettings(totalTimeout),
      expectBody: rhttp.HttpExpectBody.stream,
      body: requestStream == null ? null : rhttp.HttpBody.stream(requestStream),
      cancelToken: cancelToken,
      headers: rhttp.HttpHeaders.rawMap(
        Map.fromEntries(
          options.headers.entries.map(
            (e) => MapEntry(e.key, e.value.toString().trim()),
          ),
        ),
      ),
    );
    headersReceived = true;
    if (cancelled) scheduleRhttpCancel();
    if (res is! rhttp.HttpStreamResponse) {
      throw Exception("Invalid response type: ${res.runtimeType}");
    }
    var headers = <String, List<String>>{};
    for (var entry in res.headers) {
      var key = entry.$1.toLowerCase();
      headers[key] ??= [];
      headers[key]!.add(entry.$2);
    }
    return ResponseBody(
      cancelToken == null
          ? res.body
          : _drainAfterCancel(res.body, () => cancelled),
      res.statusCode,
      statusMessage: _getStatusMessage(res.statusCode),
      isRedirect: false,
      headers: headers,
    );
  }

  /// Forwards [body]. Once the request was cancelled, the rhttp stream is
  /// kept and drained until it ends (rhttp ends it with a cancel error right
  /// after the cancellation) so that this error has a listener; data is no
  /// longer forwarded then. Before the cancellation every event, errors
  /// included, is forwarded unchanged.
  static Stream<Uint8List> _drainAfterCancel(
    Stream<Uint8List> body,
    bool Function() cancelled,
  ) {
    late StreamSubscription<Uint8List> sub;
    final out = StreamController<Uint8List>(
      onCancel: () {
        if (cancelled()) {
          return null;
        }
        return sub.cancel();
      },
    );
    sub = body.listen(
      (data) {
        if (!cancelled()) {
          out.add(data);
        }
      },
      onError: (Object e, StackTrace s) {
        if (!cancelled()) {
          out.addError(e, s);
        }
      },
      onDone: out.close,
    );
    return out.stream;
  }

  static String _getStatusMessage(int statusCode) {
    return switch (statusCode) {
      200 => "OK",
      201 => "Created",
      202 => "Accepted",
      204 => "No Content",
      206 => "Partial Content",
      301 => "Moved Permanently",
      302 => "Found",
      400 => "Invalid Status Code 400: The Request is invalid.",
      401 => "Invalid Status Code 401: The Request is unauthorized.",
      403 =>
        "Invalid Status Code 403: No permission to access the resource. Check your account or network.",
      404 => "Invalid Status Code 404: Not found.",
      429 =>
        "Invalid Status Code 429: Too many requests. Please try again later.",
      _ => "Invalid Status Code $statusCode",
    };
  }
}
