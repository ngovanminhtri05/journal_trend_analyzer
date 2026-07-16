import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../firebase/analytics_service.dart';
import '../firebase/auth_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'home_shell.dart';
import 'login_screen.dart';

/// Routes between [LoginScreen] and [HomeShell] based on auth state (Lab 03
/// task 2.3).
///
/// Owns the [AuthViewModel] (kept alive above the branch so the subscription to
/// `authStateChanges` outlives tab changes). An [AuthApi] can be injected for
/// tests/previews; in production it defaults to [AuthService], which resolves
/// `FirebaseAuth.instance` lazily — so this widget must only be mounted after
/// `Firebase.initializeApp` has run.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.auth});

  /// Optional injected auth backend (tests/previews). Null → real [AuthService].
  final AuthApi? auth;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AuthViewModel(
        auth ?? AuthService(),
        analytics: context.read<AnalyticsApi?>(),
      ),
      child: Consumer<AuthViewModel>(
        builder: (context, vm, _) {
          switch (vm.status) {
            case AuthStatus.unknown:
              return const _SplashScreen();
            case AuthStatus.signedOut:
              return const LoginScreen();
            case AuthStatus.signedIn:
              return const HomeShell();
          }
        },
      ),
    );
  }
}

/// Brief splash shown before the first auth event resolves.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
