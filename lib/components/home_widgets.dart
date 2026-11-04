import 'package:flutter/material.dart';
import 'package:venera/foundation/ui_tokens.dart';

/// Pure presentation widgets for the Home refresh (UI Refresh v0.1, UX-01).
///
/// Everything here receives immutable display data and callbacks from the
/// caller. These widgets do not read storage, the network or comic sources,
/// do not navigate, and translate nothing: all strings come from the caller.
///
/// "Pure" means the widgets themselves have no storage or network dependency.
/// An [ImageProvider] supplied by the caller may still perform I/O (for
/// example a `NetworkImage`); tests should pass deterministic providers.

/// Reading progress within the current chapter.
@immutable
class ReadingProgress {
  const ReadingProgress._(this.page, this.total);

  /// 1-based page the reader stopped at.
  final int page;

  /// Number of pages in the chapter. Always greater than zero.
  final int total;

  /// `page / total`, between 0 and 1.
  double get fraction => (page / total).clamp(0.0, 1.0).toDouble();

  /// Returns null when the data cannot describe a progress: a missing or
  /// non-positive [maxPage], a [page] that is missing or below 1, or a [page]
  /// above [maxPage].
  ///
  /// A [page] above [maxPage] is treated as invalid (for example a stale
  /// record after the chapter got shorter), so it is never shown as a
  /// completed chapter. [page] equal to [maxPage] is valid.
  static ReadingProgress? tryCreate({int? page, int? maxPage}) {
    if (page == null || maxPage == null) return null;
    if (page < 1 || maxPage < 1) return null;
    if (page > maxPage) return null;
    return ReadingProgress._(page, maxPage);
  }
}

/// Display data of [RecentComicCard].
@immutable
class RecentComicCardData {
  const RecentComicCardData({
    required this.title,
    this.detailLine,
    this.sourceLabel,
    this.progress,
    this.progressLabel,
    this.cover,
  });

  final String title;

  /// For example "Chapter 3 - Page 8". Hidden when null or empty.
  final String? detailLine;

  /// Name of the comic source. Hidden when null or empty.
  final String? sourceLabel;

  /// The progress bar and [progressLabel] are only shown when this is not null.
  final ReadingProgress? progress;

  final String? progressLabel;

  /// A missing cover shows a placeholder.
  final ImageProvider? cover;

  /// One spoken sentence for assistive technologies.
  String semanticsLabel({String? prefix}) {
    return [
      prefix,
      title,
      detailLine,
      sourceLabel,
      if (progress != null) progressLabel,
    ].whereType<String>().where((e) => e.isNotEmpty).join(', ');
  }
}

/// Comic cover with a placeholder for a missing, loading or broken image.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    this.image,
    this.width = UiSize.coverWidth,
    this.height = UiSize.coverHeight,
  });

  final ImageProvider? image;

  final double width;

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Center(
      child: Icon(Icons.menu_book_outlined, color: scheme.uiOnCoverFill),
    );
    final provider = image;
    final Widget child;
    if (provider == null) {
      child = placeholder;
    } else {
      child = Image(
        image: provider,
        width: width,
        height: height,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          return wasSynchronouslyLoaded || frame != null ? child : placeholder;
        },
        errorBuilder: (context, error, stackTrace) => placeholder,
      );
    }
    return ExcludeSemantics(
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.uiCoverFill,
          borderRadius: BorderRadius.circular(UiRadius.cover),
        ),
        child: child,
      ),
    );
  }
}

/// Section title with an optional count badge and an optional action.
class HomeSectionHeading extends StatelessWidget {
  const HomeSectionHeading({
    super.key,
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.emphasized = false,
  });

  final String title;

  final int? count;

  /// The action is shown only when both [actionLabel] and [onAction] are set.
  final String? actionLabel;

  final VoidCallback? onAction;

  final IconData? icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = actionLabel;
    final onAction = this.onAction;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: UiSize.minTouchTarget),
      // LayoutBuilder bounds the action to half of the row, so a long label
      // wraps instead of overflowing. It does not support intrinsic sizing.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final titleWidget = Row(
            children: [
              if (icon != null) ...[
                ExcludeSemantics(
                  child: Icon(icon, color: scheme.primary, size: 24),
                ),
                const SizedBox(width: UiSpace.s2),
              ],
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: UiSpace.s2,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: theme.textTheme.uiSectionTitle?.copyWith(
                          color: scheme.uiTextPrimary,
                          fontSize: emphasized ? 22 : null,
                          fontWeight: emphasized ? FontWeight.w700 : null,
                        ),
                      ),
                    ),
                    if (count != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: UiSpace.s2,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.uiBadgeFill,
                          borderRadius: BorderRadius.circular(UiSpace.s2),
                        ),
                        child: Text(
                          count.toString(),
                          style: theme.textTheme.uiCaption?.copyWith(
                            color: scheme.uiOnBadge,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
          final action = label != null && onAction != null
              ? TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(
                      UiSize.minTouchTarget,
                      UiSize.minTouchTarget,
                    ),
                  ),
                  child: Text(label, textAlign: TextAlign.center),
                )
              : null;
          // Give both the title and action their full width at large text sizes.
          if (MediaQuery.textScalerOf(context).scale(18) > 25) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleWidget,
                if (action != null)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: action,
                  ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: titleWidget),
              if (action != null)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth / 2,
                  ),
                  child: action,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Shared home panel. Color roles follow the current light/dark/dynamic theme.
class HomeSurface extends StatelessWidget {
  const HomeSurface({super.key, required this.child, this.emphasized = false});

  final Widget child;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: UiSpace.s4,
        vertical: UiSpace.s2,
      ),
      padding: const EdgeInsets.all(UiSpace.s4),
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.surfaceContainer
            : scheme.surfaceContainerLow,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(UiRadius.card),
      ),
      child: child,
    );
  }
}

/// Compact search entry, sized by its content instead of a fixed text height.
class HomeSearchEntry extends StatelessWidget {
  const HomeSearchEntry({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: UiSpace.s6,
        vertical: UiSpace.s2,
      ),
      child: Material(
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(UiRadius.card),
        ),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          label: label,
          onTap: onTap,
          excludeSemantics: true,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 54),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: UiSpace.s3,
                  vertical: UiSpace.s2,
                ),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: scheme.primary),
                    const SizedBox(width: UiSpace.s3),
                    Expanded(
                      child: Text(label, style: theme.textTheme.uiItemTitle),
                    ),
                    const SizedBox(width: UiSpace.s2),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A bookshelf item with the caller's existing cover and navigation callback.
/// No chapter, progress, source lookup or Reader resume is inferred here.
class HomeCoverCard extends StatelessWidget {
  const HomeCoverCard({
    super.key,
    required this.title,
    required this.cover,
    required this.onTap,
  });
  final String title;
  final Widget cover;
  final VoidCallback onTap;

  static const double width = 112;
  static const double coverHeight = 168;

  static double cardWidth(BuildContext context) =>
      width +
      (MediaQuery.textScalerOf(context).scale(13) / 13 - 1).clamp(0.0, 1.0) *
          32;

  static TextStyle titleStyle(BuildContext context) => Theme.of(context)
      .textTheme
      .bodyMedium!
      .copyWith(fontSize: 13, height: 1.55, fontWeight: FontWeight.w500);

  static double shelfHeight(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: 'Ag\nAg', style: titleStyle(context)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 2,
    )..layout();
    final height = cardWidth(context) * 1.5 + UiSpace.s3 + painter.height + 4;
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: cardWidth(context),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(UiRadius.cover),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        button: true,
        label: title,
        onTap: onTap,
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IgnorePointer(
                child: SizedBox(
                  key: const ValueKey('home-portrait-cover'),
                  width: cardWidth(context),
                  height: cardWidth(context) * 1.5,
                  child: cover,
                ),
              ),
              const SizedBox(height: UiSpace.s3),
              Expanded(
                child: Text(
                  title.replaceAll('\n', ' '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class RecentComicCard extends StatelessWidget {
  const RecentComicCard({
    super.key,
    required this.data,
    this.onTap,
    this.actionLabel,
    this.onAction,
    this.semanticsPrefix,
  });

  final RecentComicCardData data;

  /// Tapping the cover and text area. The card is not interactive when null.
  final VoidCallback? onTap;

  /// The action button is shown only when both [actionLabel] and [onAction]
  /// are set. It is separate from [onTap].
  final String? actionLabel;

  final VoidCallback? onAction;

  /// Spoken before the comic title, for example "Continue reading".
  final String? semanticsPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final detailLine = data.detailLine;
    final sourceLabel = data.sourceLabel;
    final progress = data.progress;
    final progressLabel = data.progressLabel;
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;
    final secondary = textTheme.uiCaption?.copyWith(
      color: scheme.uiTextSecondary,
    );

    final content = Padding(
      padding: const EdgeInsets.all(UiSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoverImage(image: data.cover),
          const SizedBox(width: UiSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.uiItemTitle?.copyWith(
                    color: scheme.uiTextPrimary,
                  ),
                ),
                if (detailLine != null && detailLine.isNotEmpty) ...[
                  const SizedBox(height: UiSpace.s1),
                  Text(
                    detailLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: secondary,
                  ),
                ],
                if (sourceLabel != null && sourceLabel.isNotEmpty) ...[
                  const SizedBox(height: UiSpace.s1),
                  Text(
                    sourceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: secondary,
                  ),
                ],
                if (progress != null) ...[
                  const SizedBox(height: UiSpace.s3),
                  ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(UiSpace.s1),
                      child: LinearProgressIndicator(
                        value: progress.fraction,
                        minHeight: UiSpace.s1,
                        color: scheme.uiProgressIndicator,
                        backgroundColor: scheme.uiProgressTrack,
                      ),
                    ),
                  ),
                  if (progressLabel != null && progressLabel.isNotEmpty) ...[
                    const SizedBox(height: UiSpace.s1),
                    Text(progressLabel, style: secondary),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return Material(
      color: scheme.uiCardFill,
      borderRadius: BorderRadius.circular(UiRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            button: onTap != null,
            label: data.semanticsLabel(prefix: semanticsPrefix),
            onTap: onTap,
            excludeSemantics: true,
            child: InkWell(onTap: onTap, child: content),
          ),
          if (actionLabel != null && onAction != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                UiSpace.s4,
                0,
                UiSpace.s4,
                UiSpace.s4,
              ),
              child: FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(UiSize.minTouchTarget),
                ),
                child: Text(actionLabel),
              ),
            ),
        ],
      ),
    );
  }
}

/// Empty state with an optional call to action.
class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;

  final String message;

  /// The button is shown only when both [actionLabel] and [onAction] are set.
  final String? actionLabel;

  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(UiSpace.s6),
      decoration: BoxDecoration(
        color: scheme.uiCardFill,
        borderRadius: BorderRadius.circular(UiRadius.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: UiSpace.s8 + UiSpace.s2,
            color: scheme.uiTextSecondary,
          ),
          const SizedBox(height: UiSpace.s3),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.uiBody?.copyWith(
              color: scheme.uiTextPrimary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: UiSpace.s4),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                minimumSize: const Size(
                  UiSize.minTouchTarget,
                  UiSize.minTouchTarget,
                ),
              ),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }
}

/// Static loading placeholder with the footprint of a [RecentComicCard].
///
/// It has no animation, so it needs no reduced-motion handling.
class HomeCardPlaceholder extends StatelessWidget {
  const HomeCardPlaceholder({
    super.key,
    this.height = UiSize.coverHeight + 2 * UiSpace.s4,
    this.semanticsLabel,
  });

  final double height;

  /// Spoken label such as "Loading". The placeholder is silent when null.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final box = Container(
      height: height,
      decoration: BoxDecoration(
        color: scheme.uiCardFill,
        borderRadius: BorderRadius.circular(UiRadius.card),
      ),
    );
    final label = semanticsLabel;
    if (label == null) return ExcludeSemantics(child: box);
    return Semantics(container: true, label: label, child: box);
  }
}

/// Low-weight tool presentation; all data and actions belong to the caller.
class HomeToolRow extends StatelessWidget {
  const HomeToolRow({
    super.key,
    required this.title,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    this.summary,
    this.count,
    this.children = const [],
    this.highlight = false,
    this.additionalActions = const [],
  });
  final String title;
  final IconData icon;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget? summary;
  final int? count;
  final List<Widget> children;
  final bool highlight;
  final List<Widget> additionalActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final heading = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ExcludeSemantics(
          child: Icon(
            icon,
            size: 22,
            color: highlight ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: UiSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: UiSpace.s2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  if (count != null)
                    Text(
                      '$count',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              if (summary != null)
                DefaultTextStyle.merge(
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  child: summary!,
                ),
            ],
          ),
        ),
      ],
    );
    final primaryAction = TextButton(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: onAction,
      child: Text(actionLabel, textAlign: TextAlign.center),
    );
    final action = additionalActions.isEmpty
        ? primaryAction
        : Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [primaryAction, ...additionalActions],
          );
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: UiSpace.s6),
      constraints: BoxConstraints(minHeight: highlight ? 78 : 0),
      padding: EdgeInsets.symmetric(
        horizontal: highlight ? UiSpace.s4 : 0,
        vertical: UiSpace.s3,
      ),
      decoration: BoxDecoration(
        color: highlight ? scheme.surfaceContainerHigh : null,
        borderRadius: highlight ? BorderRadius.circular(UiRadius.card) : null,
        border: highlight
            ? null
            : Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (MediaQuery.textScalerOf(context).scale(16) > 22) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: action,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: heading),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth:
                          constraints.maxWidth *
                          (additionalActions.isEmpty ? .4 : .6),
                    ),
                    child: action,
                  ),
                ],
              );
            },
          ),
          ...children,
        ],
      ),
    );
  }
}

/// Follow-up status only. The original FollowUpdatesWidget owns its State.
class HomeFollowUpdatesRow extends StatelessWidget {
  const HomeFollowUpdatesRow({
    super.key,
    required this.configured,
    required this.count,
    required this.onView,
    required this.title,
    required this.status,
    required this.actionLabel,
  });
  final bool configured;
  final int count;
  final VoidCallback onView;
  final String title, status, actionLabel;
  @override
  Widget build(BuildContext context) => HomeToolRow(
    title: title,
    icon: Icons.notifications_none_rounded,
    actionLabel: actionLabel,
    onAction: onView,
    highlight: true,
    summary: Text(status),
  );
}

/// Sync controls wrap independently so error and retry paths survive large text.
class HomeSyncSection extends StatelessWidget {
  const HomeSyncSection({
    super.key,
    required this.title,
    required this.uploadLabel,
    required this.downloadLabel,
    required this.onUpload,
    required this.onDownload,
    this.busy = false,
    this.errorLabel,
    this.onError,
  });
  final String title, uploadLabel, downloadLabel;
  final VoidCallback onUpload, onDownload;
  final bool busy;
  final String? errorLabel;
  final VoidCallback? onError;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: UiSpace.s6,
      vertical: UiSpace.s2,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.sync,
              size: 22,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: UiSpace.s3),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        if (!busy)
          Wrap(
            alignment: WrapAlignment.end,
            spacing: UiSpace.s2,
            children: [
              if (errorLabel != null && onError != null)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: onError,
                  icon: const Icon(Icons.error_outline),
                  label: Text(errorLabel!),
                ),
              IconButton(
                tooltip: uploadLabel,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: onUpload,
                icon: const Icon(Icons.cloud_upload_outlined),
              ),
              IconButton(
                tooltip: downloadLabel,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: onDownload,
                icon: const Icon(Icons.cloud_download_outlined),
              ),
            ],
          ),
      ],
    ),
  );
}

/// Editorial tool card. Real counts/actions are supplied by the owner Widget.
class HomeLibraryTool extends StatelessWidget {
  const HomeLibraryTool({
    super.key,
    required this.title,
    required this.icon,
    required this.actionLabel,
    required this.onAction,
    this.count,
    this.detail,
  });
  final String title, actionLabel;
  final IconData icon;
  final VoidCallback onAction;
  final int? count;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(UiRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: scheme.primary),
            const SizedBox(height: UiSpace.s3),
            Text(title, style: theme.textTheme.titleSmall),
            if (detail != null) Text(detail!, style: theme.textTheme.bodySmall),
            Row(
              children: [
                if (count != null)
                  Text('$count', style: theme.textTheme.bodyMedium),
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      child: Text(actionLabel, textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Two library entries, with full-width statistics below rather than squeezed
/// into a narrow card. Large text naturally falls back to one column.
class HomeLibraryTools extends StatelessWidget {
  const HomeLibraryTools({
    super.key,
    required this.source,
    required this.favorites,
    this.statistics,
  });
  final Widget source, favorites;
  final Widget? statistics;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(16) >= 24) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [source, const SizedBox(height: 12), favorites],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: source),
                const SizedBox(width: 12),
                Expanded(child: favorites),
              ],
            );
          },
        ),
        if (statistics != null) ...[const SizedBox(height: 16), statistics!],
      ],
    ),
  );
}

/// Pure segmented statistic control; the existing State owns selection/scroll.
class HomeFavoriteTypeButton extends StatelessWidget {
  const HomeFavoriteTypeButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        constraints: const BoxConstraints(minWidth: 96, minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 0.6,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        duration: const Duration(milliseconds: 200),
        child: Center(widthFactor: 1, child: Text(label)),
      ),
    ),
  );
}
