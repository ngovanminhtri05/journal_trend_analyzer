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

    expect(find.text('home_page_size'), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
  });

  testWidgets('editing a parameter calls updateParameter with the new value', (
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

    await tester.tap(find.text('home_page_size'));
    await tester.pumpAndSettle();

    // The value field is the second TextField in the edit dialog.
    await tester.enterText(find.byType(TextField).at(1), '50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(api.lastUpdatedKey, 'home_page_size');
    expect(api.lastUpdatedValue, '50');
    expect(find.text('50'), findsOneWidget);
  });
}
