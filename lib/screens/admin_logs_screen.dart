import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../firebase/admin_logs_service.dart';
import '../viewmodels/admin_logs_viewmodel.dart';
import '../viewmodels/view_state.dart';
import '../widgets/widgets.dart';

/// Admin Logs screen: the mirrored Analytics/Crashlytics feed (see design
/// §5.4 — real events still go to Firebase Analytics/Crashlytics; this is a
/// live, queryable mirror for instant in-app viewing).
class AdminLogsScreen extends StatelessWidget {
  const AdminLogsScreen({super.key, this.viewModel});

  /// Injected for tests/previews; production builds the Firestore-backed view
  /// model.
  final AdminLogsViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminLogsViewModel>(
      create: (_) =>
          (viewModel ?? AdminLogsViewModel(AdminLogsService()))..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Logs')),
        body: Consumer<AdminLogsViewModel>(
          builder: (context, vm, _) => _buildBody(context, vm),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AdminLogsViewModel vm) {
    switch (vm.state) {
      case ViewState.idle:
      case ViewState.loading:
        return const LoadingView(message: 'Loading logs…');
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return const EmptyView(message: 'No events recorded yet.');
      case ViewState.success:
        return ListView.separated(
          itemCount: vm.events.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final e = vm.events[i];
            return ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: const Icon(Icons.event_note_outlined, size: 20),
              title: Text(e.name),
              subtitle: Text('${_shortUid(e.uid)} · ${_time(e.timestamp)}'),
            );
          },
        );
    }
  }

  /// Compact `MM-dd HH:mm` (the full ISO string is far too long for a list row).
  static String _time(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
  }

  static String _shortUid(String uid) =>
      uid.length <= 6 ? uid : uid.substring(0, 6);
}
