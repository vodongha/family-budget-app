import 'package:flutter/material.dart';

/// Centres content and caps its width on wide screens (web / tablet / desktop),
/// so a single-column layout doesn't stretch edge-to-edge and become hard to
/// read. On phones it's a no-op (the screen is already narrower than [maxWidth]).
///
/// Wrap a screen's body with this. It keeps the **height tight** (so an inner
/// `ListView` or a `Column` with `Expanded` still gets bounded height and
/// scrolls normally) while constraining and centring the width.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 720,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width =
            constraints.maxWidth < maxWidth ? constraints.maxWidth : maxWidth;
        return Center(
          child: SizedBox(
            width: width,
            // Preserve the incoming (tight) height so scrollables/Expanded work.
            height:
                constraints.maxHeight.isFinite ? constraints.maxHeight : null,
            child: child,
          ),
        );
      },
    );
  }
}
