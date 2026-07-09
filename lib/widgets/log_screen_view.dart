import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../firebase/analytics_service.dart';

/// Fires a one-shot analytics event when its subtree is first shown, then just
/// renders [child]. Wrap a screen body in this to log a `view_*` event on open
/// without turning the screen into a StatefulWidget.
///
/// The [AnalyticsApi] is looked up as nullable, so screens still work in
/// contexts without an analytics provider (e.g. widget tests).
class LogScreenView extends StatefulWidget {
  const LogScreenView({super.key, required this.log, required this.child});

  /// Called once, after the first frame, with the resolved analytics backend.
  final void Function(AnalyticsApi analytics) log;
  final Widget child;

  @override
  State<LogScreenView> createState() => _LogScreenViewState();
}

class _LogScreenViewState extends State<LogScreenView> {
  @override
  void initState() {
    super.initState();
    final analytics = context.read<AnalyticsApi?>();
    if (analytics != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.log(analytics);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
