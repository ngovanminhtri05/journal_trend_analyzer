import 'package:flutter/material.dart';

import '../firebase/admin_messaging_service.dart';
import '../viewmodels/admin_send_notification_viewmodel.dart';

/// Admin Send-Notification screen: compose a title + message and broadcast it to
/// every user — the in-app replacement for Firebase Console → Messaging.
class AdminSendNotificationScreen extends StatefulWidget {
  const AdminSendNotificationScreen({super.key, this.viewModel});

  /// Injected for tests; production builds the Cloud-Functions-backed model.
  final AdminSendNotificationViewModel? viewModel;

  @override
  State<AdminSendNotificationScreen> createState() =>
      _AdminSendNotificationScreenState();
}

class _AdminSendNotificationScreenState
    extends State<AdminSendNotificationScreen> {
  late final AdminSendNotificationViewModel _vm =
      widget.viewModel ??
      AdminSendNotificationViewModel(AdminMessagingService());
  late final bool _ownsVm = widget.viewModel == null;

  final _title = TextEditingController();
  final _body = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    if (_ownsVm) _vm.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final messenger = ScaffoldMessenger.of(context);
    await _vm.send(title: _title.text, body: _body.text);
    if (!mounted) return;
    if (_vm.sent) {
      _title.clear();
      _body.clear();
      messenger.showSnackBar(
        const SnackBar(content: Text('Notification sent to all users.')),
      );
    } else if (_vm.errorMessage != null) {
      messenger.showSnackBar(SnackBar(content: Text(_vm.errorMessage!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send notification')),
      body: AnimatedBuilder(
        animation: _vm,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Broadcast a push notification to every user of the app.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              enabled: !_vm.sending,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _body,
              enabled: !_vm.sending,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _vm.sending ? null : _send,
              icon: _vm.sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_vm.sending ? 'Sending…' : 'Send to all users'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
