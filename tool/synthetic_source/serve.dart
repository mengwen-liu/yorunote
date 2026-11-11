// Starts the Yorunote synthetic comic server on a computer.
//
//   dart run tool/synthetic_source/serve.dart [options]
//
// Options:
//   --host <addr>        address to bind (default 127.0.0.1)
//   --port <n>           port (default 8765)
//   --public-url <url>   address the device uses to reach this server; it is
//                        written into /source.js. Required when --host is not
//                        a loopback address (the server never guesses a LAN
//                        address). With `adb reverse tcp:<port> tcp:<port>`
//                        use the default http://127.0.0.1:<port>.
//   --list-interfaces    print this computer's interface addresses and exit
//
// Stop with Ctrl+C.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'synthetic_server.dart';

Future<void> main(List<String> args) async {
  String? arg(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  if (args.contains('--list-interfaces')) {
    for (final ni in await NetworkInterface.list()) {
      for (final a in ni.addresses) {
        stdout.writeln('${ni.name}\t${a.address}');
      }
    }
    return;
  }

  final host = arg('--host') ?? '127.0.0.1';
  final port = int.parse(arg('--port') ?? '8765');
  var publicUrl = arg('--public-url');
  final loopback = host == '127.0.0.1' || host == 'localhost' || host == '::1';
  if (publicUrl == null && !loopback) {
    stderr.writeln(
      'error: --public-url is required with --host $host '
      '(e.g. --public-url http://<this computer\'s LAN address>:$port)',
    );
    exitCode = 64;
    return;
  }
  publicUrl ??= 'http://127.0.0.1:$port';

  final scriptDir = File.fromUri(Platform.script).parent.path;
  final template = await File(
    '$scriptDir/yorunote_synthetic_source.js',
  ).readAsString();
  final server = SyntheticServer(sourceTemplate: template);
  await server.start(host: host, port: port, publicUrl: publicUrl);

  stdout.writeln('Yorunote synthetic server listening on $host:${server.port}');
  stdout.writeln('Source script for the app: ${server.baseUrl}/source.js');
  stdout.writeln('Status page:              ${server.baseUrl}/');
  stdout.writeln('Counters (JSON):          ${server.baseUrl}/__stats');
  stdout.writeln('Synthetic data only. Ctrl+C to stop.');

  var last = '';
  final timer = Timer.periodic(const Duration(seconds: 2), (_) {
    final s = server.stats();
    final line =
        'requests=${s['total_requests']} images=${s['image_requests']} '
        'active=${s['active_image_requests']} '
        'peak=${s['peak_active_image_requests']} paused=${s['paused']} '
        'delay=${s['delay_ms']}ms rules=${jsonEncode(s['rules'])}';
    if (line != last) {
      stdout.writeln('[${DateTime.now().toIso8601String()}] $line');
      last = line;
    }
  });

  await ProcessSignal.sigint.watch().first;
  timer.cancel();
  await server.stop();
  stdout.writeln('stopped');
}
