import 'package:flutter/material.dart';

const double kWebMaxContentWidth = 900.0;

/// Constrains [child] to [maxWidth] and centers it horizontally on wide screens
/// (e.g. web / desktop). On narrow screens the child fills the available width
/// unchanged. Wrap the Scaffold `body:` value with this widget.
class WebWrapper extends StatelessWidget {
  const WebWrapper({
    super.key,
    required this.child,
    this.maxWidth = kWebMaxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxWidth) return child;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: maxWidth, child: child),
        );
      },
    );
  }
}
