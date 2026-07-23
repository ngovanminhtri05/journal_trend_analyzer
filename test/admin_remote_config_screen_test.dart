import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:journal_trend_analyzer/firebase/admin_remote_config_service.dart';
import 'package:journal_trend_analyzer/screens/admin_remote_config_screen.dart';
import 'package:journal_trend_analyzer/viewmodels/admin_remote_config_viewmodel.dart';

/// Fake backing the Remote Config admin screen without Cloud Functions.
class _FakeApi implements AdminRemoteConfigApi {
  _FakeApi(this._params);

  List<RemoteConfigParam> _params;
  String? lastUpdatedKey;
  String? lastUpdatedValue;

  @override
  Future<List<RemoteConfigParam>> getTemplate() async => _params;

  @override
  Future<void> updateParameter({
    required String key,
    required String defaultValue,
  }) async {
    lastUpdatedKey = key;
    lastUpdatedValue = defaultValue;
    _params = [RemoteConfigParam(key: key, defaultValue: defaultValue)];
  }
}

void main() {
  testWidgets('renders each parameter from the loaded template', (tester) async {
    final vm = AdminRemoteConfigViewModel(
      _FakeApi([
        const RemoteConfigParam(key: 'home_page_size', defaultValue: '25'),
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(home: AdminRemoteConfigScreen(viewModel: vm)),
    );
    await tester.pumpAndSettle();

    // A known tunable renders as a friendly labeled stepper, not a raw key.
    expect(find.text('Home feed page size'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
  });

  testWidgets('the stepper calls updateParameter with the stepped value', (
    tester,
  ) async {
    final api = _FakeApi([
      const RemoteConfigParam(key: 'home_page_size', defaultValue: '25'),
    ]);
    final vm = AdminRemoteConfigViewModel(api);

    await tester.pumpWidget(
      MaterialApp(home: AdminRemoteConfigScreen(viewModel: vm)),
    );
    await tester.pumpAndSettle();

    // First "Increase" belongs to home_page_size (step 1 → 26).
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pumpAndSettle();

    expect(api.lastUpdatedKey, 'home_page_size');
    expect(api.lastUpdatedValue, '26');
    expect(find.text('26'), findsOneWidget);
  });
}
