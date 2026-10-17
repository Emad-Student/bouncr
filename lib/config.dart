/// Build-time configuration passed with `--dart-define`.
///
/// Cloud Functions cannot be deployed on the free Spark plan, so during
/// development they run in the Firebase Emulator on the developer's machine
/// while Authentication and Firestore stay in the real cloud project:
///
/// ```
/// adb reverse tcp:5001 tcp:5001
/// flutter run --dart-define=FUNCTIONS_EMULATOR_HOST=127.0.0.1
/// ```
///
/// Without the define the app calls the deployed functions (Blaze plan).
class AppConfig {
  AppConfig._();

  static const functionsRegion = 'europe-central2';
  static const functionsEmulatorHost = String.fromEnvironment('FUNCTIONS_EMULATOR_HOST');
  static const functionsEmulatorPort = 5001;

  static bool get usesFunctionsEmulator => functionsEmulatorHost.isNotEmpty;
}
