import 'package:flutter/material.dart';

/// Windows title-bar branding; the native window name remains Yorunote.
class WindowsTitleBrand extends StatefulWidget {
  const WindowsTitleBrand({super.key});

  static const animatedAsset = 'assets/brand/yorunote_mascot.gif';
  static const staticAsset = 'assets/app_icon.png';

  @override
  State<WindowsTitleBrand> createState() => _WindowsTitleBrandState();
}

class _WindowsTitleBrandState extends State<WindowsTitleBrand>
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
          width: 72,
          height: 36,
          child: Center(
            child: Image.asset(
              animate
                  ? WindowsTitleBrand.animatedAsset
                  : WindowsTitleBrand.staticAsset,
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
    );
  }
}
