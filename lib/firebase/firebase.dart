/// Firebase layer (MVVM) — thin wrappers around Firebase SDKs.
///
/// Houses the Firebase service classes (Auth, Analytics, Crashlytics, Storage,
/// Messaging, Remote Config). ViewModels depend on these wrappers, never on the
/// Firebase SDKs directly, so the rest of the app stays testable and decoupled.
///
/// Empty until the Firebase phases (PLANS-Lab03 Phase 2/8/9) land; barrel
/// exports are added as each service is implemented.
library;
