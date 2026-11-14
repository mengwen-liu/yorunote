import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/foundation.dart';
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

class YorunoteVideoEntry extends StatefulWidget {
  const YorunoteVideoEntry({super.key});

  @override
  State<YorunoteVideoEntry> createState() => _YorunoteVideoEntryState();
}

class _YorunoteVideoEntryState extends State<YorunoteVideoEntry> {
  static const _channel = MethodChannel('yorunote/embedded_video');
  bool _opening = false;

  Future<void> _openNative() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final response = await _channel.invokeMethod<String>('open');
      if (response != 'launch_accepted') _showLaunchError();
    } on PlatformException catch (error) {
      if (error.code != 'already_open') _showLaunchError();
    } on MissingPluginException {
      _showLaunchError();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _showLaunchError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _label(context, '無法開啟原版影音。', 'Could not open native videos.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: const Icon(Icons.ondemand_video_outlined),
      title: Text(_label(context, '影音', 'Videos')),
      trailing: const Icon(Icons.chevron_right),
      onTap: !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? (_opening ? null : _openNative)
          : () => Navigator.of(context, rootNavigator: true).push<void>(
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

enum _VideoShelf { favorites, later, recent }

class _VideoCatalogPageState extends State<_VideoCatalogPage> {
  final _catalog = HanimeCatalog();
  final _query = TextEditingController();
  CancelToken? _request;
  List<VideoSection> _sections = [];
  _VideoShelf? _shelf;
  bool _loading = false;
  bool _failed = false;
  String _activeQuery = '';

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
      _activeQuery = query;
      _shelf = null;
      _loading = true;
      _failed = false;
    });
    try {
      final sections = await _catalog.load(query, request);
      if (!mounted || request != _request) return;
      setState(() => _sections = sections);
    } on Exception {
      if (!mounted || request != _request) return;
      setState(() => _failed = true);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _submit(String input) {
    FocusScope.of(context).unfocus();
    final uri = hanimeWatchUri(input);
    if (uri == null) {
      unawaited(_load(input.trim()));
      return;
    }
    final saved = _readShelf(
      _VideoShelf.recent,
    ).where((video) => video.uri == uri).firstOrNull;
    unawaited(
      _open(
        saved ??
            VideoListing(uri, 'Hanime1 #${uri.queryParameters['v']}', null),
      ),
    );
  }

  Future<void> _open(VideoListing video) async {
    FocusScope.of(context).unfocus();
    await _openVideoDetails(context, video);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final shelf = _shelf;
    final browsing = _activeQuery.isEmpty;
    final firstVideo = _sections.firstOrNull?.videos.firstOrNull;
    final grid = shelf != null
        ? _readShelf(shelf)
        : (browsing
              ? const <VideoListing>[]
              : _sections.expand((section) => section.videos).toList());
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
                hintText: _label(
                  context,
                  '搜尋或貼上影片連結',
                  'Search or paste a video link',
                ),
                leading: IconButton(
                  tooltip: _label(context, '搜尋', 'Search'),
                  onPressed: () => _submit(_query.text),
                  icon: const Icon(Icons.search),
                ),
                onSubmitted: _submit,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  ChoiceChip(
                    label: Text(_label(context, '瀏覽', 'Browse')),
                    selected: shelf == null,
                    onSelected: (_) => setState(() => _shelf = null),
                  ),
                  for (final item in _VideoShelf.values)
                    ChoiceChip(
                      label: Text(_shelfLabel(context, item)),
                      selected: item == shelf,
                      onSelected: (_) => setState(() => _shelf = item),
                    ),
                ],
              ),
            ),
          ),
          if (shelf == null && _loading)
            const SliverToBoxAdapter(child: LinearProgressIndicator()),
          if (shelf == null && !_loading && (_failed || _sections.isEmpty))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      _failed
                          ? _label(
                              context,
                              '無法載入目錄。你仍可貼上影片連結。',
                              'The catalog could not load. You can still paste a video link.',
                            )
                          : _label(
                              context,
                              '沒有可顯示的影片。',
                              'No videos to display.',
                            ),
                    ),
                    if (_failed)
                      TextButton(
                        onPressed: () => _load(_activeQuery),
                        child: Text(_label(context, '重試', 'Retry')),
                      ),
                  ],
                ),
              ),
            ),
          if (shelf == null &&
              !_loading &&
              !_failed &&
              browsing &&
              firstVideo != null) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: SizedBox(
                  height: 232,
                  child: _VideoCard(
                    video: firstVideo,
                    onTap: () => _open(firstVideo),
                  ),
                ),
              ),
            ),
            for (final section in _sections)
              SliverToBoxAdapter(child: _section(context, section)),
          ],
          if (shelf != null && grid.isEmpty)
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _label(context, '清單目前是空的。', 'This list is empty.'),
                  ),
                ),
              ),
            ),
          if (grid.isNotEmpty && (shelf != null || (!_loading && !_failed)))
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisExtent: 185,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: grid.length,
                itemBuilder: (_, index) => _VideoCard(
                  video: grid[index],
                  onTap: () => _open(grid[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, VideoSection section) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title.isEmpty
                ? _label(context, '影片', 'Videos')
                : section.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: section.videos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final video = section.videos[index];
                return SizedBox(
                  width: 190,
                  child: _VideoCard(video: video, onTap: () => _open(video)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _shelfKey(_VideoShelf shelf) => switch (shelf) {
  _VideoShelf.favorites => 'yorunoteFavoriteVideos',
  _VideoShelf.later => 'yorunoteWatchLaterVideos',
  _VideoShelf.recent => 'yorunoteRecentVideos',
};

String _shelfLabel(BuildContext context, _VideoShelf shelf) => switch (shelf) {
  _VideoShelf.favorites => _label(context, '收藏', 'Favorites'),
  _VideoShelf.later => _label(context, '稍後觀看', 'Watch later'),
  _VideoShelf.recent => _label(context, '最近播放', 'Recently played'),
};

List<VideoListing> _readShelf(_VideoShelf shelf) {
  final data = appdata.implicitData[_shelfKey(shelf)];
  if (data is! List) return [];
  final entries = <VideoListing>[];
  for (final row in data) {
    if (row is! Map) continue;
    final url = row['url'];
    final title = row['title'];
    if (url is! String || title is! String) continue;
    final uri = hanimeWatchUri(url);
    final image = row['thumbnail'];
    final thumbnail = image is String ? Uri.tryParse(image) : null;
    final duration = row['duration'];
    if (uri != null) {
      entries.add(
        VideoListing(
          uri,
          title,
          thumbnail?.scheme == 'https' ? thumbnail : null,
          duration: duration is String ? duration : null,
        ),
      );
    }
  }
  return entries;
}

void _saveShelf(_VideoShelf shelf, List<VideoListing> items) {
  appdata.implicitData[_shelfKey(shelf)] = [
    for (final item in items)
      {
        'url': item.uri.toString(),
        'title': item.title,
        'thumbnail': item.thumbnail?.toString(),
        'duration': item.duration,
      },
  ];
  appdata.writeImplicitData();
}

Future<void> _openVideoDetails(BuildContext context, VideoListing video) {
  return Navigator.of(
    context,
  ).push<void>(MaterialPageRoute(builder: (_) => _VideoDetailsPage(video)));
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video, required this.onTap});

  final VideoListing video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const placeholder = Center(child: Icon(Icons.play_circle_outline));
    final thumbnail = video.thumbnail;
    final duration = video.duration;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
              child: Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (duration != null && duration.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(
                  duration,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoDetailsPage extends StatefulWidget {
  const _VideoDetailsPage(this.video);

  final VideoListing video;

  @override
  State<_VideoDetailsPage> createState() => _VideoDetailsPageState();
}

class _VideoDetailsPageState extends State<_VideoDetailsPage> {
  final _catalog = HanimeCatalog();
  final _token = CancelToken();
  late Future<VideoDetails> _details;

  @override
  void initState() {
    super.initState();
    _details = _catalog.details(widget.video.uri, _token);
  }

  @override
  void dispose() {
    _token.cancel();
    _catalog.close();
    super.dispose();
  }

  bool _contains(_VideoShelf shelf) =>
      _readShelf(shelf).any((video) => video.uri == widget.video.uri);

  void _toggle(_VideoShelf shelf) {
    final items = _readShelf(shelf);
    final index = items.indexWhere((video) => video.uri == widget.video.uri);
    if (index >= 0) {
      items.removeAt(index);
    } else {
      items.insert(0, widget.video);
    }
    setState(() => _saveShelf(shelf, items));
  }

  Future<void> _play() async {
    final video = widget.video;
    final recent = _readShelf(_VideoShelf.recent)
      ..removeWhere((item) => item.uri == video.uri);
    _saveShelf(_VideoShelf.recent, [video, ...recent.take(39)]);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _VideoPage(video.uri, video.title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    return Scaffold(
      appBar: AppBar(title: Text(_label(context, '影片詳情', 'Video details'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SizedBox(
                height: 230,
                width: double.infinity,
                child: _VideoCard(video: video, onTap: _play),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton.icon(
                onPressed: _play,
                icon: const Icon(Icons.play_arrow),
                label: Text(_label(context, '播放／續播', 'Play or resume')),
              ),
              FilterChip(
                label: Text(_shelfLabel(context, _VideoShelf.favorites)),
                selected: _contains(_VideoShelf.favorites),
                onSelected: (_) => _toggle(_VideoShelf.favorites),
              ),
              FilterChip(
                label: Text(_shelfLabel(context, _VideoShelf.later)),
                selected: _contains(_VideoShelf.later),
                onSelected: (_) => _toggle(_VideoShelf.later),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<VideoDetails>(
            future: _details,
            builder: (context, snapshot) {
              final details = snapshot.data;
              if (details == null) {
                if (snapshot.hasError) {
                  return TextButton(
                    onPressed: () => setState(() {
                      _details = _catalog.details(video.uri, _token);
                    }),
                    child: Text(
                      _label(context, '重試載入詳情', 'Retry loading details'),
                    ),
                  );
                }
                return const LinearProgressIndicator();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (details.description.isNotEmpty) ...[
                    Text(
                      _label(context, '簡介', 'Description'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(details.description),
                    const SizedBox(height: 16),
                  ],
                  if (details.related.isNotEmpty)
                    Text(
                      _label(context, '相關影片', 'Related videos'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  for (final item in details.related)
                    ListTile(
                      leading: const Icon(Icons.play_circle_outline),
                      title: Text(item.title),
                      onTap: () async {
                        await _openVideoDetails(context, item);
                        if (mounted) setState(() {});
                      },
                    ),
                ],
              );
            },
          ),
        ],
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
      _desktopPlacement = WindowPlacement(
        await windowManager.getBounds(),
        true,
      );
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _label(
            context,
            '請先開始播放，並確認裝置允許小窗播放。',
            'Start playback and check whether your device allows mini player.',
          ),
        ),
      ),
    );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _label(
                  context,
                  '啟用應用程式鎖定時，子母畫面無法使用。',
                  'Picture-in-picture is unavailable while app lock is enabled.',
                ),
              ),
            ),
          );
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

  Future<void> _setPlaybackSpeed(double speed) async {
    final controller = _controller;
    if (controller == null || !_playerReady) return;
    try {
      await controller.evaluateJavascript(
        source:
            "(() => { const video = document.querySelector('.plyr video, video'); "
            'if (video) video.playbackRate = $speed; })()',
      );
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _label(context, '無法調整播放速度。', 'Could not change playback speed.'),
            ),
          ),
        );
      }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _label(context, '無法開啟瀏覽器。', 'Could not open the browser.'),
        ),
      ),
    );
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
                title: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
                      icon: Icon(
                        _theaterMode ? Icons.fullscreen_exit : Icons.fullscreen,
                      ),
                    ),
                  if (!_mini)
                    PopupMenuButton<double>(
                      enabled: _playerReady && !_busy,
                      tooltip: _label(context, '播放速度', 'Playback speed'),
                      onSelected: _setPlaybackSpeed,
                      itemBuilder: (_) => [
                        for (final speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                          PopupMenuItem(value: speed, child: Text('$speed×')),
                      ],
                      icon: const Icon(Icons.speed),
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
                if (mounted && _playerReady) {
                  setState(() => _playerReady = false);
                }
              },
              onLoadStop: (controller, url) async {
                if (url == null || hanimeWatchUri(url.toString()) == null) {
                  return;
                }
                try {
                  final installed = await controller.evaluateJavascript(
                    source: _videoScript,
                  );
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
