import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

/// Keeps inherited dependencies out of PhotoView's image-loading state.
///
/// The pinned PhotoView resets its loading flag in didChangeDependencies,
/// even when its image stream has already delivered a frame. Reading Theme
/// or MediaQuery in its loadingBuilder can therefore leave a decoded image
/// behind a spinner after the window size or theme changes.
class ReaderImageLoading extends StatelessWidget {
  const ReaderImageLoading({required this.event, super.key});

  final ImageChunkEvent? event;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PhotoView.customChild(
      childSize: MediaQuery.sizeOf(context),
      initialScale: PhotoViewComputedScale.contained,
      minScale: PhotoViewComputedScale.contained * 1.0,
      maxScale: PhotoViewComputedScale.covered * 10.0,
      backgroundDecoration: BoxDecoration(color: colors.surface),
      child: Center(
        child: SizedBox(
          width: 20.0,
          height: 20.0,
          child: CircularProgressIndicator(
            backgroundColor: colors.surfaceContainerHigh,
            value: event == null || event!.expectedTotalBytes == null
                ? null
                : event!.cumulativeBytesLoaded / event!.expectedTotalBytes!,
          ),
        ),
      ),
    );
  }
}
