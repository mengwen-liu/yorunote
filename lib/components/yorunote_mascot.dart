import 'package:flutter/material.dart';

/// Shared branding for the Windows caption and the Android home page.
class YorunoteMascot extends StatefulWidget {
  const YorunoteMascot({super.key, this.width = 28, this.height = 28});

  final double width;
  final double height;

  static const animatedAsset = 'assets/brand/yorunote_mascot.gif';
  static const staticAsset = 'assets/app_icon.png';

  @override
  State<YorunoteMascot> createState() => _YorunoteMascotState();
}

class _YorunoteMascotState extends State<YorunoteMascot>
    with WidgetsBindingObserver {
  late bool _active;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    _active = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_active != active) {
      setState(() => _active = active);
    }
  }

  @override
  Widget build(BuildContext context) {
    final animate = _active && !MediaQuery.disableAnimationsOf(context);
    final decodeSize = (28 * MediaQuery.devicePixelRatioOf(context)).ceil();
    return Tooltip(
      message: 'Yorunote',
      excludeFromSemantics: true,
      child: Semantics(
        label: 'Yorunote',
        image: true,
        excludeSemantics: true,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Center(
            child: RepaintBoundary(
              child: Image.asset(
                animate
                    ? YorunoteMascot.animatedAsset
                    : YorunoteMascot.staticAsset,
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                cacheWidth: decodeSize,
                cacheHeight: decodeSize,
                gaplessPlayback: true,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
