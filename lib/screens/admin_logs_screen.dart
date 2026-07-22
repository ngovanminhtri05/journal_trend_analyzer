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
  const AdminLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminLogsViewModel>(
      create: (_) => AdminLogsViewModel(AdminLogsService())..load(),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Logs'),
            bottom: const TabBar(
              tabs: [Tab(text: 'Events'), Tab(text: 'Crashes')],
            ),
          ),
          body: Consumer<AdminLogsViewModel>(
            builder: (context, vm, _) => _buildBody(context, vm),
          ),
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
        return const EmptyView(message: 'No events or crashes recorded yet.');
      case ViewState.success:
        return TabBarView(
          children: [
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vm.events.length,
              itemBuilder: (context, i) {
                final e = vm.events[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_note_outlined),
                    title: Text(e.name),
                    subtitle: Text('${e.uid} • ${e.timestamp}'),
                  ),
                );
              },
            ),
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vm.crashes.length,
              itemBuilder: (context, i) {
                final c = vm.crashes[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.report_gmailerrorred_outlined),
                    title: Text(c.message),
                    subtitle: Text('${c.uid} • ${c.timestamp}'),
                  ),
                );
              },
            ),
          ],
        );
    }
  }
}
