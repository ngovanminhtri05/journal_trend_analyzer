import 'package:flutter/material.dart';

/// Centers content and caps its width on large screens (tablets, landscape) so
/// lines stay readable, while staying full-width on phones. Wraps each screen's
/// body for consistent layout across sizes.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({super.key, required this.child, this.maxWidth = 720});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
