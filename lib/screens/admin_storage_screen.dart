import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../firebase/admin_storage_service.dart';
import '../viewmodels/admin_storage_viewmodel.dart';
import '../viewmodels/view_state.dart';
import '../widgets/widgets.dart';

/// Admin Storage screen: browse, download, or delete uploaded PDF reports
/// across every user's `reports/{uid}/…` folder.
class AdminStorageScreen extends StatelessWidget {
  const AdminStorageScreen({super.key, this.viewModel});

  /// Injected for tests/previews; production builds the Cloud-Functions-backed
  /// view model.
  final AdminStorageViewModel? viewModel;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AdminStorageViewModel>(
      create: (_) =>
          (viewModel ?? AdminStorageViewModel(AdminStorageService()))..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Storage')),
        body: Consumer<AdminStorageViewModel>(
          builder: (context, vm, _) => _buildBody(context, vm),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, AdminStorageViewModel vm) {
    switch (vm.state) {
      case ViewState.idle:
      case ViewState.loading:
        return const LoadingView(message: 'Loading reports…');
      case ViewState.error:
        return ErrorView(
          message: vm.errorMessage ?? 'Something went wrong.',
          onRetry: vm.retry,
        );
      case ViewState.empty:
        return const EmptyView(message: 'No reports uploaded yet.');
      case ViewState.success:
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vm.reports.length,
          itemBuilder: (context, i) => _ReportTile(
            report: vm.reports[i],
            vm: vm,
          ),
        );
    }
  }
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report, required this.vm});

  final AdminReportFile report;
  final AdminStorageViewModel vm;

  @override
  Widget build(BuildContext context) {
    final kb = (report.size / 1024).toStringAsFixed(1);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.picture_as_pdf_outlined),
        title: Text(report.path.split('/').last),
        subtitle: Text('${report.uid ?? 'unknown user'} • $kb KB'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) =>
              value == 'download' ? _download(context) : _confirmDelete(context),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'download', child: Text('Download')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Future<void> _download(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await vm.openReport(report.path);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the report.')),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this report?'),
        content: Text(
          '${report.path} will be permanently removed from Storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      final before = vm.errorMessage;
      await vm.delete(report.path);
      if (vm.errorMessage != null && vm.errorMessage != before) {
        messenger.showSnackBar(SnackBar(content: Text(vm.errorMessage!)));
      }
    }
  }
}
