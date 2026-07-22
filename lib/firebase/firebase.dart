/// Firebase layer (MVVM) — thin wrappers around Firebase SDKs.
///
/// Houses the Firebase service classes (Auth, Analytics, Crashlytics, Storage,
/// Messaging, Remote Config). ViewModels depend on these wrappers, never on the
/// Firebase SDKs directly, so the rest of the app stays testable and decoupled.
///
/// Exports grow as each Firebase phase (PLANS-Lab03 Phase 2/8/9) lands.
library;

export 'admin_access_service.dart';
export 'admin_logs_mirror.dart';
export 'admin_logs_service.dart';
export 'admin_remote_config_service.dart';
export 'admin_users_service.dart';
export 'analytics_service.dart';
export 'app_user.dart';
export 'auth_service.dart';
export 'crash_reporter_service.dart';
export 'local_notifier.dart';
export 'messaging_service.dart';
export 'remote_config_service.dart';
export 'storage_service.dart';
