import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A card that turns around its vertical axis, following a horizontal drag.
///
/// Releasing past half a turn, or flinging, completes the flip; anything less
/// springs back. Dragging again flips it back to the front.
class FlipCard extends StatefulWidget {
  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    this.onFlip,
  });

  static const flipDuration = Duration(milliseconds: 250);
  static const flingVelocity = 700.0;

  final Widget front;
  final Widget back;

  /// Called after each completed flip, with true when the back is now showing.
  final ValueChanged<bool>? onFlip;

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _angle = AnimationController.unbounded(
    vsync: this,
  );
  bool _showingBack = false;
  double _width = 1;

  double get _restingAngle => _showingBack ? math.pi : 0;

  @override
  void dispose() {
    _angle.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) => _angle.stop();

  void _onDragUpdate(DragUpdateDetails details) {
    final angle = _angle.value + details.delta.dx / _width * math.pi;
    _angle.value = angle.clamp(
      _restingAngle - math.pi,
      _restingAngle + math.pi,
    );
  }

  void _onDragEnd(DragEndDetails details) {
    final turned = _angle.value - _restingAngle;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final flung =
        velocity.abs() > FlipCard.flingVelocity && velocity.sign == turned.sign;

    if (turned != 0 && (turned.abs() > math.pi / 2 || flung)) {
      _angle
          .animateTo(
            _restingAngle + turned.sign * math.pi,
            duration: FlipCard.flipDuration,
            curve: Curves.easeOut,
          )
          .orCancel
          .then((_) => _completeFlip(), onError: (Object _) {});
    } else {
      _angle.animateTo(
        _restingAngle,
        duration: FlipCard.flipDuration,
        curve: Curves.easeOut,
      );
    }
  }

  void _completeFlip() {
    setState(() => _showingBack = !_showingBack);
    _angle.value = _restingAngle;
    widget.onFlip?.call(_showingBack);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        _width = width.isFinite && width > 0 ? width : 1;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: AnimatedBuilder(
            animation: _angle,
            builder: (context, _) {
              final angle = _angle.value;
              final backVisible = math.cos(angle) < 0;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(angle),
                child: backVisible
                    // Turn the back once more so its content isn't mirrored.
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(math.pi),
                        child: widget.back,
                      )
                    : widget.front,
              );
            },
          ),
        );
      },
    );
  }
}
