import 'package:flutter/material.dart' hide ErrorWidgetBuilder;
import 'package:flutter_svg/flutter_svg.dart';

import 'builders.dart';
import 'measure_path_length_canvas.dart';
import 'clipped_path_painter.dart';
import 'pen_renderer/pen_renderer.dart';
import 'svg_provider.dart';

/// A widget that displays a drawing animation of SVG.
class SvgDrawingAnimation extends StatefulWidget {
  const SvgDrawingAnimation(this.svgProvider,
      {super.key,
      this.duration,
      this.speed,
      this.curve = Curves.linear,
      this.repeats = false,
      this.animation,
      this.loadingWidgetBuilder = defaultLoadingWidgetBuilder,
      this.errorWidgetBuilder = defaultErrorWidgetBuilder,
      this.penRenderer,
      this.refresh = false})
      : assert(!(duration == null && speed == null && animation == null),
            'You must set a duration, speed or animation.'),
        assert(
            animation == null && duration != null && speed == null ||
                animation == null && speed != null && duration == null ||
                animation != null && speed == null && duration == null,
            'Only one of duration or speed can be used at a time.');

  /// Provides the SVG to display.
  final SvgProvider svgProvider;

  /// Whether the animation plays once or repeats indefinitely.
  final bool repeats;

  /// The duration over which to animate. Use one of [duration] or [speed].
  final Duration? duration;

  /// The speed at which to animate. Use one of [duration] or [speed].
  final double? speed;

  /// The curve to apply when animating.
  final Curve curve;

  /// The animation.
  final Animation<double>? animation;

  /// A builder that specifies the widget to display to the user while the SVG
  /// is still loading.
  final LoadingWidgetBuilder loadingWidgetBuilder;

  /// A builder that specifies the widget to display to the user if an error
  /// has occurred.
  final ErrorWidgetBuilder errorWidgetBuilder;

  /// Optionally renders the Pen during the drawing animation.
  final PenRenderer? penRenderer;

  /// Refreshes the path length
  final bool refresh;

  /// Computes the total length of paths in SVG.
  static double getPathLengthSum(Drawable drawable) {
    final c = MeasurePathLengthCanvas();
    // TODO: pass proper values to bounds.
    drawable.draw(c, const Rect.fromLTRB(0, 0, 1, 1));
    return c.pathLengthSum;
  }

  @override
  State<SvgDrawingAnimation> createState() => _SvgDrawingAnimationState();
}

class _SvgDrawingAnimationState extends State<SvgDrawingAnimation>
    with SingleTickerProviderStateMixin {
  _SvgDrawingAnimationState();

  bool isInitialized = false;
  Animation<double>? animation;
  AnimationController? controller;
  late double totalPathLength;

  @override
  void initState() {
    animation = widget.animation;
    super.initState();
  }

  @override
  void dispose() {
    if (controller != null) {
      controller!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: widget.svgProvider.resolve(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return widget.loadingWidgetBuilder(context);
          }
          if (snapshot.hasError) {
            return widget.errorWidgetBuilder(
                context, snapshot.error!, snapshot.stackTrace);
          }
          final drawable = snapshot.data!;
          // Compute total length and set up animation;
          if (!isInitialized || widget.refresh) {
            totalPathLength = SvgDrawingAnimation.getPathLengthSum(drawable);
            isInitialized = true;

            if (animation == null) {
              final duration = widget.duration ??
                  Duration(
                      milliseconds: 1000 * totalPathLength ~/ widget.speed!);
              controller = AnimationController(duration: duration, vsync: this);
              animation =
                  CurvedAnimation(parent: controller!, curve: widget.curve);
              if (widget.repeats) {
                controller!.repeat();
              } else {
                controller!.forward();
              }
            }
          }
          return AnimatedBuilder(
              animation: animation!,
              builder: (context, child) {
                return FittedBox(
                    child: SizedBox.fromSize(
                        size: drawable.viewport.viewBox,
                        child: CustomPaint(
                            painter: ClippedPathPainter(snapshot.data!,
                                pathLengthLimit:
                                    animation!.value * totalPathLength,
                                penRenderer: widget.penRenderer))));
              });
        });
  }
}
