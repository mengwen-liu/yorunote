import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:venera/components/components.dart';
import 'package:venera/components/home_widgets.dart';
import 'package:venera/components/yorunote_mascot.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/consts.dart';
import 'package:venera/foundation/favorites.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/foundation/ui_tokens.dart';
import 'package:venera/pages/comic_details_page/comic_page.dart';
import 'package:venera/pages/comic_source_page.dart';
import 'package:venera/pages/downloading_page.dart';
import 'package:venera/pages/follow_updates_page.dart';
import 'package:venera/pages/history_page.dart';
import 'package:venera/pages/image_favorites_page/image_favorites_page.dart';
import 'package:venera/pages/search_page.dart';
import 'package:venera/utils/data_sync.dart';
import 'package:venera/utils/import_comic.dart';
import 'package:venera/utils/tags_translation.dart';
import 'package:venera/utils/translations.dart';

import 'local_comics_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    var widget = SmoothCustomScrollView(
      slivers: [
        SliverPadding(padding: EdgeInsets.only(top: context.padding.top)),
        if (Theme.of(context).platform == TargetPlatform.android)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                UiSpace.s6,
                UiSpace.s2,
                UiSpace.s6,
                0,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: YorunoteMascot(),
              ),
            ),
          ),
        const _SearchBar(),
        const _History(),
        const FollowUpdatesWidget(),
        const ImageFavorites(leadingTool: _ComicSourceWidget()),
        const _Local(),
        const _SyncDataWidget(),
        SliverPadding(padding: EdgeInsets.only(top: context.padding.bottom)),
      ],
    );
    return context.width > changePoint ? widget.paddingHorizontal(8) : widget;
  }
}

/// Home presentation only; storage and navigation stay in the caller.
class HomeHistorySection extends StatelessWidget {
  const HomeHistorySection({
    super.key,
    required this.count,
    required this.onViewAll,
    required this.onSearch,
    this.recentComics,
  });
  final int count;
  final VoidCallback onViewAll, onSearch;
  final Widget? recentComics;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      UiSpace.s6,
      UiSpace.s4,
      UiSpace.s6,
      UiSpace.s3,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionHeading(
          title: 'History'.tl,
          emphasized: true,
          actionLabel: 'View more'.tl,
          onAction: onViewAll,
        ),
        Text(
          '${'History'.tl} · $count',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: UiSpace.s3),
        if (recentComics != null)
          recentComics!
        else
          HomeEmptyState(
            icon: Icons.auto_stories_outlined,
            message: '${'History'.tl}: 0',
            actionLabel: 'Search'.tl,
            onAction: onSearch,
          ),
      ],
    ),
  );
}

class HomeLocalSection extends StatelessWidget {
  const HomeLocalSection({
    super.key,
    required this.count,
    required this.onOpen,
    required this.onImport,
    this.recentComics,
    this.downloadingAction,
  });
  final int count;
  final VoidCallback onOpen, onImport;
  final Widget? recentComics, downloadingAction;
  @override
  Widget build(BuildContext context) => HomeToolRow(
    title: 'Local'.tl,
    icon: Icons.folder_outlined,
    count: count,
    actionLabel: 'View'.tl,
    onAction: onOpen,
    additionalActions: [
      FilledButton(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: Colors.transparent,
          foregroundColor: Theme.of(context).colorScheme.primary,
        ),
        onPressed: onImport,
        child: Text('Import Comics'.tl),
      ),
    ],
    children: [
      if (recentComics != null) ...[
        const SizedBox(height: UiSpace.s2),
        recentComics!,
      ],
      Wrap(
        spacing: UiSpace.s2,
        runSpacing: UiSpace.s2,
        alignment: WrapAlignment.end,
        children: [if (downloadingAction != null) downloadingAction!],
      ),
    ],
  );
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: HomeSearchEntry(
        label: 'Search'.tl,
        onTap: () => context.to(() => const SearchPage()),
      ),
    );
  }
}

/// Source names are informational labels; only the explicit management entry
/// navigates. Count and available updates are supplied by the existing caller.
class HomeSourceSection extends StatelessWidget {
  const HomeSourceSection({
    super.key,
    required this.names,
    required this.onManage,
    this.availableUpdates = 0,
  });
  final List<String> names;
  final VoidCallback onManage;
  final int availableUpdates;
  @override
  Widget build(BuildContext context) => HomeLibraryTool(
    title: 'Comic Source'.tl,
    icon: Icons.hub_outlined,
    count: names.length,
    actionLabel: 'Manage'.tl,
    onAction: onManage,
    detail: availableUpdates > 0
        ? '@c updates'.tlParams({'c': availableUpdates})
        : null,
  );
}

class _SyncDataWidget extends StatefulWidget {
  const _SyncDataWidget();

  @override
  State<_SyncDataWidget> createState() => _SyncDataWidgetState();
}

class _SyncDataWidgetState extends State<_SyncDataWidget>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    DataSync().addListener(update);
    WidgetsBinding.instance.addObserver(this);
    lastCheck = DateTime.now();
  }

  void update() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    super.dispose();
    DataSync().removeListener(update);
    WidgetsBinding.instance.removeObserver(this);
  }

  late DateTime lastCheck;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      if (DateTime.now().difference(lastCheck) > const Duration(minutes: 10)) {
        lastCheck = DateTime.now();
        DataSync().downloadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!DataSync().isEnabled) {
      return const SliverPadding(padding: EdgeInsets.zero);
    }
    final busy = DataSync().isUploading || DataSync().isDownloading;
    return SliverToBoxAdapter(
      child: HomeSyncSection(
        title: (busy ? 'Syncing Data' : 'Sync Data').tl,
        busy: busy,
        uploadLabel: 'Upload'.tl,
        downloadLabel: 'Download'.tl,
        onUpload: () => DataSync().uploadData(),
        onDownload: () => DataSync().downloadData(),
        errorLabel: DataSync().lastError == null ? null : 'Error'.tl,
        onError: () => showDialogMessage(
          App.rootContext,
          'Error'.tl,
          DataSync().lastError!,
        ),
      ),
    );
  }
}

class _History extends StatefulWidget {
  const _History();

  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  late List<History> history;
  late int count;

  void onHistoryChange() {
    if (mounted) {
      setState(() {
        history = HistoryManager().getRecent();
        count = HistoryManager().count();
      });
    }
  }

  @override
  void initState() {
    history = HistoryManager().getRecent();
    count = HistoryManager().count();
    HistoryManager().addListener(onHistoryChange);
    super.initState();
  }

  @override
  void dispose() {
    HistoryManager().removeListener(onHistoryChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: HomeHistorySection(
        count: count,
        onViewAll: () => context.to(() => const HistoryPage()),
        onSearch: () => context.to(() => const SearchPage()),
        recentComics: history.isEmpty
            ? null
            : SizedBox(
                height: HomeCoverCard.shelfHeight(context),
                child: ListView.separated(
                  key: const PageStorageKey('home-history-shelf'),
                  scrollDirection: Axis.horizontal,
                  itemCount: history.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: UiSpace.s4),
                  itemBuilder: (context, index) {
                    final heroID = history[index].id.hashCode;
                    return HomeCoverCard(
                      title: history[index].title,
                      cover: SimpleComicTile(
                        comic: history[index],
                        heroID: heroID,
                      ),
                      onTap: () {
                        context.to(
                          () => ComicPage(
                            id: history[index].id,
                            sourceKey: history[index].type.sourceKey,
                            cover: history[index].cover,
                            title: history[index].title,
                            heroID: heroID,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _Local extends StatefulWidget {
  const _Local();

  @override
  State<_Local> createState() => _LocalState();
}

class _LocalState extends State<_Local> {
  late List<LocalComic> local;
  late int count;

  void onLocalComicsChange() {
    setState(() {
      local = LocalManager().getRecent();
      count = LocalManager().count;
    });
  }

  @override
  void initState() {
    local = LocalManager().getRecent();
    count = LocalManager().count;
    LocalManager().addListener(onLocalComicsChange);
    super.initState();
  }

  @override
  void dispose() {
    LocalManager().removeListener(onLocalComicsChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: HomeLocalSection(
        count: count,
        onOpen: () => context.to(() => const LocalComicsPage()),
        onImport: import,
        recentComics: local.isEmpty
            ? null
            : SizedBox(
                height: HomeCoverCard.shelfHeight(context),
                child: ListView.separated(
                  key: const PageStorageKey('home-local-shelf'),
                  scrollDirection: Axis.horizontal,
                  itemCount: local.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: UiSpace.s4),
                  itemBuilder: (context, index) {
                    final heroID = local[index].id.hashCode;
                    return HomeCoverCard(
                      title: local[index].title,
                      cover: SimpleComicTile(
                        comic: local[index],
                        heroID: heroID,
                      ),
                      onTap: () {
                        context.to(
                          () => ComicPage(
                            id: local[index].id,
                            sourceKey: local[index].sourceKey,
                            cover: local[index].cover,
                            title: local[index].title,
                            heroID: heroID,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
        downloadingAction: LocalManager().downloadingTasks.isEmpty
            ? null
            : Button.outlined(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (LocalManager().downloadingTasks.first.isPaused)
                      const Icon(Icons.pause_circle_outline, size: 18)
                    else
                      const _AnimatedDownloadingIcon(),
                    const SizedBox(width: UiSpace.s2),
                    Text(
                      '@a Tasks'.tlParams({
                        'a': LocalManager().downloadingTasks.length,
                      }),
                    ),
                  ],
                ),
                onPressed: () {
                  showPopUpWidget(context, const DownloadingPage());
                },
              ),
      ),
    );
  }

  void import() {
    showDialog(
      barrierDismissible: false,
      context: App.rootContext,
      builder: (context) {
        return const _ImportComicsWidget();
      },
    );
  }
}

class _ImportComicsWidget extends StatefulWidget {
  const _ImportComicsWidget();

  @override
  State<_ImportComicsWidget> createState() => _ImportComicsWidgetState();
}

class _ImportComicsWidgetState extends State<_ImportComicsWidget> {
  int type = 0;

  bool loading = false;

  var key = GlobalKey();

  var height = 200.0;

  var folders = LocalFavoritesManager().folderNames;

  String? selectedFolder;

  bool copyToLocalFolder = true;

  bool cancelled = false;

  @override
  void dispose() {
    loading = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String info = [
      "Select a directory which contains the comic files.".tl,
      "Select a directory which contains the comic directories.".tl,
      "Select an archive file (cbz, zip, 7z, cb7)".tl,
      "Select a directory which contains multiple archive files.".tl,
      "Select an EhViewer database and a download folder.".tl,
      "Scan the current local path and restore the local database.".tl,
    ][type];
    List<String> importMethods = [
      "Single Comic".tl,
      "Multiple Comics".tl,
      "An archive file".tl,
      "Multiple archive files".tl,
      "EhViewer downloads".tl,
      "Restore local downloads".tl,
    ];

    return ContentDialog(
      dismissible: !loading,
      title: "Import Comics".tl,
      content: loading
          ? SizedBox(
              width: 600,
              height: height,
              child: const Center(child: CircularProgressIndicator()),
            )
          : RadioGroup<int>(
              groupValue: type,
              onChanged: (value) {
                setState(() {
                  type = value ?? type;
                  if (type == 5) {
                    selectedFolder = null;
                  }
                });
              },
              child: Column(
                key: key,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(width: 600),
                  ...List.generate(importMethods.length, (index) {
                    return RadioListTile<int>(
                      title: Text(importMethods[index]),
                      value: index,
                    );
                  }),
                  if (type != 4 && type != 5)
                    ListTile(
                      title: Text("Add to favorites".tl),
                      trailing: Select(
                        current: selectedFolder,
                        values: folders,
                        minWidth: 112,
                        onTap: (v) {
                          setState(() {
                            selectedFolder = folders[v];
                          });
                        },
                      ),
                    ).paddingHorizontal(8),
                  if (!App.isIOS &&
                      !App.isMacOS &&
                      type != 2 &&
                      type != 3 &&
                      type != 5)
                    CheckboxListTile(
                      enabled: true,
                      title: Text("Copy to app local path".tl),
                      value: copyToLocalFolder,
                      onChanged: (v) {
                        setState(() {
                          copyToLocalFolder = !copyToLocalFolder;
                        });
                      },
                    ).paddingHorizontal(8),
                  const SizedBox(height: 8),
                  Text(info).paddingHorizontal(24),
                ],
              ),
            ),
      actions: [
        Button.text(
          child: Row(
            children: [
              Icon(
                Icons.help_outline,
                size: 18,
                color: context.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text("help".tl),
            ],
          ),
          onPressed: () {
            launchUrlString(
              "https://github.com/venera-app/venera/blob/master/doc/import_comic.md",
            );
          },
        ).fixWidth(90).paddingRight(8),
        Button.filled(
          isLoading: loading,
          onPressed: selectAndImport,
          child: Text("Select".tl),
        ),
      ],
    );
  }

  void selectAndImport() async {
    height = key.currentContext!.size!.height;

    setState(() {
      loading = true;
    });
    var importer = ImportComic(
      selectedFolder: selectedFolder,
      copyToLocal: copyToLocalFolder,
    );
    var result = switch (type) {
      0 => await importer.directory(true),
      1 => await importer.directory(false),
      2 => await importer.cbz(),
      3 => await importer.multipleCbz(),
      4 => await importer.ehViewer(),
      5 => await importer.localDownloads(),
      int() => true,
    };
    if (result) {
      context.pop();
    } else {
      setState(() {
        loading = false;
      });
    }
  }
}

class _ComicSourceWidget extends StatefulWidget {
  const _ComicSourceWidget();

  @override
  State<_ComicSourceWidget> createState() => _ComicSourceWidgetState();
}

class _ComicSourceWidgetState extends State<_ComicSourceWidget> {
  late List<String> comicSources;

  void onComicSourceChange() {
    setState(() {
      comicSources = ComicSource.all().map((e) => e.name).toList();
    });
  }

  @override
  void initState() {
    comicSources = ComicSource.all().map((e) => e.name).toList();
    ComicSourceManager().addListener(onComicSourceChange);
    super.initState();
  }

  @override
  void dispose() {
    ComicSourceManager().removeListener(onComicSourceChange);
    super.dispose();
  }

  int get _availableUpdates {
    int c = 0;
    ComicSourceManager().availableUpdates.forEach((key, version) {
      var source = ComicSource.find(key);
      if (source != null) {
        if (compareSemVer(version, source.version)) {
          c++;
        }
      }
    });
    return c;
  }

  @override
  Widget build(BuildContext context) {
    return HomeSourceSection(
      names: comicSources,
      availableUpdates: _availableUpdates,
      onManage: () => context.to(() => const ComicSourcePage()),
    );
  }
}

class _AnimatedDownloadingIcon extends StatefulWidget {
  const _AnimatedDownloadingIcon();

  @override
  State<_AnimatedDownloadingIcon> createState() =>
      __AnimatedDownloadingIconState();
}

class __AnimatedDownloadingIconState extends State<_AnimatedDownloadingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      lowerBound: -1,
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
          clipBehavior: Clip.hardEdge,
          child: Transform.translate(
            offset: Offset(0, 18 * _controller.value),
            child: Icon(
              Icons.arrow_downward,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        );
      },
    );
  }
}

class ImageFavorites extends StatefulWidget {
  const ImageFavorites({super.key, this.leadingTool});

  /// Optional adjacent tool; manager lifecycle and statistics remain here.
  final Widget? leadingTool;

  @override
  State<ImageFavorites> createState() => _ImageFavoritesState();
}

class _ImageFavoritesState extends State<ImageFavorites> {
  ImageFavoritesComputed? imageFavoritesCompute;

  int displayType = 0;

  void refreshImageFavorites() async {
    try {
      imageFavoritesCompute =
          await ImageFavoriteManager.computeImageFavorites();
      if (mounted) {
        setState(() {});
      }
    } catch (e, stackTrace) {
      Log.error("Unhandled Exception", e.toString(), stackTrace);
    }
  }

  @override
  void initState() {
    refreshImageFavorites();
    ImageFavoriteManager().addListener(refreshImageFavorites);
    super.initState();
  }

  @override
  void dispose() {
    ImageFavoriteManager().removeListener(refreshImageFavorites);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool hasData =
        imageFavoritesCompute != null && !imageFavoritesCompute!.isEmpty;
    final tool = HomeLibraryTool(
      title: 'Image Favorites'.tl,
      icon: Icons.collections_outlined,
      count: hasData ? imageFavoritesCompute!.count : null,
      actionLabel: 'View'.tl,
      onAction: () => context.to(() => const ImageFavoritesPage()),
    );
    final statistics = hasData
        ? HomeImageFavoritesStatistics(
            computed: imageFavoritesCompute!,
            displayType: displayType,
            onSelect: (type) async {
              setState(() {
                displayType = type;
              });
              await Future.delayed(const Duration(milliseconds: 20));
              var scrollController = ScrollState.of(context).controller;
              scrollController.animateTo(
                scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.ease,
              );
            },
            onKeyword: (text) {
              context.to(() => ImageFavoritesPage(initialKeyword: text));
            },
          )
        : null;
    return SliverToBoxAdapter(
      child: widget.leadingTool == null
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [tool, if (statistics != null) statistics],
              ),
            )
          : HomeLibraryTools(
              source: widget.leadingTool!,
              favorites: tool,
              statistics: statistics,
            ),
    );
  }
}

/// Storage-free rendering of the existing computed statistics. The owning
/// State still supplies selection, scroll and filtered-navigation callbacks.
class HomeImageFavoritesStatistics extends StatelessWidget {
  const HomeImageFavoritesStatistics({
    super.key,
    required this.computed,
    required this.displayType,
    required this.onSelect,
    required this.onKeyword,
  });
  final ImageFavoritesComputed computed;
  final int displayType;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onKeyword;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        spacing: UiSpace.s2,
        runSpacing: UiSpace.s2,
        children: [
          for (final (type, label) in [
            (0, 'Tags'.tl),
            (1, 'Authors'.tl),
            (2, 'Comics'.tl),
          ])
            HomeFavoriteTypeButton(
              label: label,
              selected: displayType == type,
              onTap: () => onSelect(type),
            ),
        ],
      ),
      const SizedBox(height: UiSpace.s2),
      buildChart(switch (displayType) {
        0 => computed.tags,
        1 => computed.authors,
        2 => computed.comics,
        _ => [],
      }),
    ],
  );

  Widget buildChart(List<TextWithCount> data) {
    if (data.isEmpty) return const SizedBox();
    var maxCount = data.map((e) => e.count).reduce((a, b) => a > b ? a : b);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 164),
      child: SingleChildScrollView(
        child: Column(
          key: ValueKey(displayType),
          children: data.map((e) {
            return _ChartLine(
              text: e.text,
              count: e.count,
              maxCount: maxCount,
              enableTranslation: displayType != 2,
              onTap: onKeyword,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ChartLine extends StatefulWidget {
  const _ChartLine({
    required this.text,
    required this.count,
    required this.maxCount,
    required this.enableTranslation,
    this.onTap,
  });

  final String text;

  final int count;

  final int maxCount;

  final bool enableTranslation;

  final void Function(String text)? onTap;

  @override
  State<_ChartLine> createState() => __ChartLineState();
}

class __ChartLineState extends State<_ChartLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 0,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var text = widget.text;
    var enableTranslation =
        App.locale.countryCode == 'CN' && widget.enableTranslation;
    if (enableTranslation) {
      text = text.translateTagsToCN;
    }
    if (widget.enableTranslation && text.contains(':')) {
      text = text.split(':').last;
    }
    return Row(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () {
            widget.onTap?.call(widget.text);
          },
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)
              .paddingHorizontal(4)
              .toAlign(Alignment.centerLeft)
              .fixWidth(context.width > 600 ? 120 : 80)
              .fixHeight(double.infinity),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constrains) {
              var width = constrains.maxWidth * widget.count / widget.maxCount;
              return AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Container(
                    width: width * _controller.value,
                    height: 18,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: context.isDarkMode
                            ? [Colors.blue.shade800, Colors.blue.shade500]
                            : [Colors.blue.shade300, Colors.blue.shade600],
                      ),
                    ),
                  ).toAlign(Alignment.centerLeft);
                },
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Text(
          widget.count.toString(),
          style: ts.s12,
        ).fixWidth(context.width > 600 ? 60 : 30),
      ],
    ).fixHeight(48);
  }
}
