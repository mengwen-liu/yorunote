import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:venera/components/window_frame.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/hanime_catalog.dart';
import 'package:window_manager/window_manager.dart';

String _label(BuildContext context, String chinese, String english) =>
    Localizations.localeOf(context).languageCode == 'zh' ? chinese : english;

class YorunoteVideoEntry extends StatelessWidget {
  const YorunoteVideoEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: const Icon(Icons.ondemand_video_outlined),
      title: Text(_label(context, '影音', 'Videos')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context, rootNavigator: true).push<void>(
        MaterialPageRoute(builder: (_) => const _VideoCatalogPage()),
      ),
    );
  }
}

class _VideoCatalogPage extends StatefulWidget {
  const _VideoCatalogPage();

  @override
  State<_VideoCatalogPage> createState() => _VideoCatalogPageState();
}

class _VideoCatalogPageState extends State<_VideoCatalogPage> {
  final _catalog = HanimeCatalog();
  final _query = TextEditingController();
  CancelToken? _request;
  List<VideoListing> _videos = [];
  bool _loading = false;
  bool _failed = false;

  static const _companionChannel = MethodChannel('yorunote/hanime_companion');
  bool _openingCompanion = false;

  static const _recentKey = 'yorunoteRecentVideos';

  List<VideoListing> get _recent {
    final data = appdata.implicitData[_recentKey];
    if (data is! List) return [];
    final entries = <VideoListing>[];
    for (final row in data) {
      if (row is! Map) continue;
      final url = row['url'];
      final title = row['title'];
      if (url is! String || title is! String) continue;
      final uri = hanimeWatchUri(url);
      if (uri != null) entries.add(VideoListing(uri, title, null));
    }
    return entries;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load(''));
  }

  @override
  void dispose() {
    _request?.cancel();
    _catalog.close();
    _query.dispose();
    super.dispose();
  }

  Future<void> _load(String query) async {
    _request?.cancel();
    final request = _request = CancelToken();
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final videos = await _catalog.load(query.trim(), request);
      if (!mounted || request != _request) return;
      setState(() => _videos = videos);
    } on Exception {
      if (!mounted || request != _request) return;
      setState(() => _failed = true);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _openCompanion() async {
    if (_openingCompanion) return;
    setState(() => _openingCompanion = true);
    try {
      final opened = await _companionChannel.invokeMethod<bool>('open');
      if (opened == true || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_label(
          context,
          '請先安裝 Han1meViewer Remastered，再從這裡開啟。',
          'Install Han1meViewer Remastered to open it here.',
        )),
      ));
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_label(
          context,
          '無法開啟 Han1meViewer Remastered。',
          'Could not open Han1meViewer Remastered.',
        )),
      ));
    } finally {
      if (mounted) setState(() => _openingCompanion = false);
    }
  }

  void _submit(String input) {
    FocusScope.of(context).unfocus();
    final uri = hanimeWatchUri(input);
    if (uri != null) {
      final previous = _recent.where((entry) => entry.uri == uri).firstOrNull;
      unawaited(_open(previous ?? VideoListing(uri, 'Hanime1 #${uri.queryParameters['v']}', null)));
    } else {
      unawaited(_load(input));
    }
  }

  Future<void> _open(VideoListing video) async {
    final items = [video, ..._recent.where((item) => item.uri != video.uri)];
    setState(() {
      appdata.implicitData[_recentKey] = [
        for (final item in items.take(20))
          {'url': item.uri.toString(), 'title': item.title},
      ];
    });
    appdata.writeImplicitData();
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _VideoPage(video.uri, video.title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recent = _recent;
    return Scaffold(
      appBar: AppBar(title: Text(_label(context, '影音', 'Videos'))),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SearchBar(
                controller: _query,
                hintText: _label(context, '搜尋或貼上影片連結', 'Search or paste a video link'),
                leading: IconButton(
                  tooltip: _label(context, '搜尋', 'Search'),
                  onPressed: () => _submit(_query.text),
                  icon: const Icon(Icons.search),
                ),
                onSubmitted: _submit,
              ),
            ),
          ),
          if (App.isAndroid)
            SliverToBoxAdapter(
              child: ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Han1meViewer Remastered'),
                subtitle: Text(_label(
                  context,
                  '開啟已安裝的完整版 App',
                  'Open the separately installed app',
                )),
                onTap: _openingCompanion ? null : _openCompanion,
              ),
            ),
          if (recent.isNotEmpty)
            SliverToBoxAdapter(
              child: ExpansionTile(
                title: Text(_label(context, '最近開啟', 'Recently opened')),
                children: [
                  for (final item in recent)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.history),
                      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _open(item),
                    ),
                ],
              ),
            ),
          if (_loading)
            const SliverToBoxAdapter(child: LinearProgressIndicator()),
          if (!_loading && (_failed || _videos.isEmpty))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(_failed
                        ? _label(context, '無法載入 Hanime1 目錄，仍可貼上影片連結。',
                            'Could not load the Hanime1 catalog. You can still paste a video link.')
                        : _label(context, '沒有可顯示的影片。', 'No videos to display.')),
                    TextButton(
                      onPressed: () => _submit(_query.text),
                      child: Text(_label(context, '重新載入', 'Reload')),
                    ),
                  ],
                ),
              ),
            ),
          if (!_loading && !_failed && _videos.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 280,
                  childAspectRatio: 1.25,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: _videos.length,
                itemBuilder: (context, index) => _buildCard(_videos[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(VideoListing video) {
    const placeholder = Center(child: Icon(Icons.play_circle_outline));
    final thumbnail = video.thumbnail;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(video),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: thumbnail == null
                  ? placeholder
                  : Image.network(
                      thumbnail.toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => placeholder,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage(this.uri, this.title);

  final Uri uri;
  final String title;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> {
  static const _pipChannel = MethodChannel('yorunote/video_pip');
  static const _normalMinimumSize = Size(500, 600);

  static Future<WebViewEnvironment>? _windowsEnvironment;

  late final Future<WebViewEnvironment?> _environment = _createEnvironment();
  InAppWebViewController? _controller;
  WindowPlacement? _desktopPlacement;
  bool _previousTopmost = false;
  bool _mini = false;
  bool _busy = false;
  bool _failed = false;
  bool _playerReady = false;
  bool _theaterMode = false;

  Future<WebViewEnvironment?> _createEnvironment() async {
    if (!App.isWindows) return null;
    try {
      return await (_windowsEnvironment ??= WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
          userDataFolder: "${App.dataPath}\\video_webview",
        ),
      ));
    } on Exception {
      _windowsEnvironment = null;
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    if (App.isAndroid) _pipChannel.setMethodCallHandler(_onPipEvent);
  }

  @override
  void dispose() {
    if (App.isAndroid) _pipChannel.setMethodCallHandler(null);
    if (_desktopPlacement != null) unawaited(_restoreDesktop());
    super.dispose();
  }

  Future<void> _onPipEvent(MethodCall call) async {
    if (call.method != 'modeChanged' || !mounted) return;
    final entered = call.arguments == true;
    setState(() => _mini = entered);
    if (!entered) await _setVideoMode(0);
  }

  Future<bool> _setVideoMode(int mode) async {
    final controller = _controller;
    if (controller == null) return false;
    try {
      final result = await controller.evaluateJavascript(
        source: 'window.yorunoteVideo && window.yorunoteVideo($mode)',
      );
      return result == true || result == 'true';
    } on Exception {
      return false;
    }
  }

  Future<void> _enterDesktopMini() async {
    _previousTopmost = await windowManager.isAlwaysOnTop();
    final maximized = await windowManager.isMaximized();
    final previousBounds = await windowManager.getBounds();
    WindowPlacement.suspendSaving = true;
    _desktopPlacement = WindowPlacement(previousBounds, maximized);
    if (maximized) {
      await windowManager.unmaximize();
      _desktopPlacement = WindowPlacement(await windowManager.getBounds(), true);
    }
    final bounds = _desktopPlacement!.rect;
    await windowManager.setMinimumSize(const Size(320, 240));
    await windowManager.setBounds(bounds.topLeft & const Size(480, 340));
    await windowManager.setAlwaysOnTop(true);
    if (mounted) setState(() => _mini = true);
  }

  Future<void> _restoreDesktop() async {
    final placement = _desktopPlacement;
    if (placement == null) return;
    _desktopPlacement = null;
    try {
      await windowManager.setAlwaysOnTop(_previousTopmost);
      await windowManager.setMinimumSize(_normalMinimumSize);
      await placement.applyToWindow();
    } finally {
      WindowPlacement.suspendSaving = false;
    }
  }

  void _showMiniError() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_label(
        context,
        '請先開始播放，並確認裝置允許小窗播放。',
        'Start playback and check whether your device allows mini player.',
      )),
    ));
  }

  Future<void> _toggleMini() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (_mini && App.isWindows) {
        await _restoreDesktop();
        await _setVideoMode(0);
        if (mounted) setState(() => _mini = false);
        return;
      }
      if (App.isAndroid && appdata.settings['authorizationRequired'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_label(
              context,
              '啟用應用程式鎖定時，子母畫面無法使用。',
              'Picture-in-picture is unavailable while app lock is enabled.',
            )),
          ));
        }
        return;
      }
      if (!await _setVideoMode(App.isAndroid ? 2 : 1)) {
        if (mounted) _showMiniError();
        return;
      }
      if (!mounted) return;
      if (App.isAndroid) {
        if (await _pipChannel.invokeMethod<bool>('enter') != true) {
          await _setVideoMode(0);
          if (mounted) _showMiniError();
        }
      } else {
        await _enterDesktopMini();
      }
    } on Exception {
      try {
        await _restoreDesktop();
      } on Exception {
        // Continue restoring the web player even if the window call fails.
      }
      await _setVideoMode(0);
      if (mounted) {
        setState(() => _mini = false);
        _showMiniError();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openBrowser() async {
    try {
      if (await launchUrl(widget.uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } on Exception {
      // The same message is used if the OS has no handler.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_label(context, '無法開啟瀏覽器。', 'Could not open the browser.')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final androidPip = App.isAndroid && _mini;
    return PopScope(
      canPop: !_busy && !_mini && !_theaterMode,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (App.isWindows && _mini) unawaited(_toggleMini());
        if (_theaterMode && !_mini) setState(() => _theaterMode = false);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: androidPip
            ? null
            : AppBar(
                toolbarHeight: _mini || _theaterMode ? 44 : kToolbarHeight,
                automaticallyImplyLeading: !_mini && !_busy && !_theaterMode,
                title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                actions: [
                  IconButton(
                    tooltip: _mini
                        ? _label(context, '還原視窗', 'Restore window')
                        : _label(context, '小窗播放', 'Mini player'),
                    onPressed: _busy || !_playerReady ? null : _toggleMini,
                    icon: Icon(
                      _mini ? Icons.open_in_full : Icons.picture_in_picture_alt,
                    ),
                  ),
                  if (!_mini)
                    IconButton(
                      tooltip: _theaterMode
                          ? _label(context, '退出劇院模式', 'Exit theater mode')
                          : _label(context, '劇院模式', 'Theater mode'),
                      onPressed: !_playerReady || _busy
                          ? null
                          : () => setState(() => _theaterMode = !_theaterMode),
                      icon: Icon(_theaterMode ? Icons.fullscreen_exit : Icons.fullscreen),
                    ),
                  if (!_mini && !_theaterMode)
                    IconButton(
                      tooltip: _label(context, '在瀏覽器開啟', 'Open in browser'),
                      onPressed: _openBrowser,
                      icon: const Icon(Icons.open_in_browser),
                    ),
                ],
              ),
        body: FutureBuilder<WebViewEnvironment?>(
          future: _environment,
          builder: (context, snapshot) {
            if (snapshot.hasError || _failed) {
              return Center(
                child: TextButton.icon(
                  onPressed: _openBrowser,
                  icon: const Icon(Icons.open_in_browser),
                  label: Text(_label(context, '改用瀏覽器開啟', 'Open in browser')),
                ),
              );
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            return InAppWebView(
              webViewEnvironment: snapshot.data,
              initialUrlRequest: URLRequest(url: WebUri(widget.uri.toString())),
              initialSettings: InAppWebViewSettings(
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: true,
              ),
              onCreateWindow: (_, _) async => false,
              shouldOverrideUrlLoading: (_, action) async {
                final uri = action.request.url;
                if (action.isForMainFrame == false ||
                    (uri != null && hanimeWatchUri(uri.toString()) != null)) {
                  return NavigationActionPolicy.ALLOW;
                }
                return NavigationActionPolicy.CANCEL;
              },
              onLoadStart: (_, _) {
                if (mounted && _playerReady) setState(() => _playerReady = false);
              },
              onLoadStop: (controller, url) async {
                if (url == null || hanimeWatchUri(url.toString()) == null) return;
                try {
                  final installed = await controller.evaluateJavascript(source: _videoScript);
                  if (installed != true && installed != 'true') {
                    if (mounted) setState(() => _failed = true);
                    return;
                  }
                  if (!mounted) return;
                  _controller = controller;
                  setState(() => _playerReady = true);
                } on Exception {
                  if (mounted) setState(() => _failed = true);
                }
              },
              onReceivedError: (_, request, _) {
                if (mounted && request.isForMainFrame == true) {
                  setState(() => _failed = true);
                }
              },
            );
          },
        ),
      ),
    );
  }
}

const _videoScript = r'''
(() => {
  if (location.origin !== 'https://hanime1.me' || location.pathname !== '/watch') return false;
  const id = new URLSearchParams(location.search).get('v');
  if (!/^\d+$/.test(id || '')) return false;
  if (window.yorunoteVideo) return true;
  const key = 'yorunote.resume.' + id;
  let active, position = 0, lastWrite = 0, ready = false, restoring = false;
  let tapTime = 0, tapSide, tapX, tapY;
  try { position = Number(localStorage.getItem(key)) || 0; } catch (_) {}
  const player = () => document.querySelector('.plyr video, video#player, video');
  const save = (force = false) => {
    if (!active || !ready || restoring || active.seeking || !Number.isFinite(active.duration)) return;
    const now = Date.now();
    if (!force && now - lastWrite < 3000) return;
    lastWrite = now;
    const t = active.currentTime;
    try {
      if (active.ended || (t > 0 && active.duration - t < 3)) {
        localStorage.removeItem(key);
      } else if (t > 0) {
        localStorage.setItem(key, String(t));
      }
    } catch (_) {}
  };
  const attach = () => {
    const video = player();
    if (!video || video === active) return;
    const surface = video.closest('.plyr') || video;
    for (let node = surface.parentElement; node && node !== document.body; node = node.parentElement) {
      node.classList.add('yorunote-player-ancestor');
    }
    surface.classList.add('yorunote-video-surface');
    document.body.classList.add('yorunote-small');
    active = video;
    const restore = () => {
      if (video !== active || ready || !Number.isFinite(video.duration)) return;
      ready = true;
      if (position > 0 && position < video.duration - 3) {
        restoring = true;
        video.currentTime = position;
      }
    };
    video.addEventListener('seeked', () => { if (video === active) restoring = false; });
    video.addEventListener('loadedmetadata', restore);
    video.addEventListener('timeupdate', () => { if (video === active) save(); });
    video.addEventListener('pause', () => { if (video === active) save(true); });
    video.addEventListener('ended', () => { if (video === active) save(true); });
    if (video.readyState >= 1) restore();
  };
  const seek = (side) => {
    attach();
    if (!active || !Number.isFinite(active.duration)) return;
    active.currentTime = Math.max(0, Math.min(active.duration, active.currentTime + side * 10));
  };
  const sideFor = (event) => {
    const video = player();
    if (!video || !(event.target instanceof Element)) return 0;
    if (event.target.closest('button, a, input, select, textarea, [role=menu], .plyr__controls')) return 0;
    if (!video.contains(event.target) && !event.target.closest('.plyr__video-wrapper')) return 0;
    const rect = video.getBoundingClientRect();
    if (rect.width <= 0) return 0;
    const offset = (event.clientX - rect.left) / rect.width;
    return offset < 0.35 ? -1 : offset > 0.65 ? 1 : 0;
  };
  const handle = (event, side) => {
    event.preventDefault();
    event.stopImmediatePropagation();
    seek(side);
  };
  document.addEventListener('dblclick', (event) => {
    if (Date.now() - tapTime < 500) return;
    const side = sideFor(event);
    if (side) handle(event, side);
  }, true);
  document.addEventListener('pointerup', (event) => {
    if (event.pointerType !== 'touch') return;
    const side = sideFor(event);
    if (!side) { tapSide = 0; return; }
    const now = Date.now();
    if (side === tapSide && now - tapTime < 320 &&
        Math.hypot(event.clientX - tapX, event.clientY - tapY) < 55) {
      tapSide = 0;
      handle(event, side);
      return;
    }
    tapSide = side;
    tapTime = now;
    tapX = event.clientX;
    tapY = event.clientY;
  }, true);
  document.addEventListener('visibilitychange', () => { if (document.hidden) save(true); });
  window.addEventListener('pagehide', () => save(true));

  if (!player()) return false;
  const style = document.createElement('style');
  style.textContent = [
    'body.yorunote-small { overflow: hidden !important; background: black !important; }',
    'body.yorunote-small * { visibility: hidden !important; }',
    'body.yorunote-small .yorunote-player-ancestor { transform: none !important;',
    'filter: none !important; contain: none !important; overflow: visible !important;',
    'opacity: 1 !important; clip-path: none !important; }',
    'body.yorunote-small .yorunote-video-surface,',
    'body.yorunote-small .yorunote-video-surface * { visibility: visible !important; }',
    'body.yorunote-small .yorunote-video-surface { position: fixed !important;',
    'inset: 0 !important; width: 100vw !important; height: 100vh !important;',
    'max-width: none !important; max-height: none !important; margin: 0 !important;',
    'z-index: 2147483647 !important; background: black !important; }',
    'body.yorunote-small .yorunote-video-surface .plyr__video-wrapper { height: 100% !important;',
    'padding: 0 !important; }',
    'body.yorunote-small .yorunote-video-surface video,',
    'body.yorunote-small video.yorunote-video-surface { height: 100% !important;',
    'width: 100% !important; object-fit: contain !important; }',
    'body.yorunote-pip .yorunote-video-surface .plyr__controls,',
    'body.yorunote-pip .yorunote-video-surface .plyr__control--overlaid { display: none !important; }',
  ].join(' ');
  document.head.append(style);

  window.yorunoteVideo = (mode) => {
    attach();
    const video = player();
    if (!video) return false;
    if (mode && (!video.currentSrc || video.paused || video.ended)) return false;
    const surface = video.closest('.plyr') || video;
    surface.classList.add('yorunote-video-surface');
    document.body.classList.add('yorunote-small');
    document.body.classList.toggle('yorunote-pip', mode === 2);
    save(true);
    return true;
  };
  attach();
  new MutationObserver(attach).observe(document.body, {childList: true, subtree: true});
  return true;
})();
''';
