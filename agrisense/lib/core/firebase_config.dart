class FirebaseConfig {
  static const String databaseUrl = String.fromEnvironment(
    'FIREBASE_RTDB_URL',
    defaultValue:
        'https://agrisense-3eba5-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  static const String apiKey = String.fromEnvironment(
    'FIREBASE_API_KEY',
    defaultValue: 'AIzaSyCdXw00WR8x2TYnse4NJAs2O2_pQ0QYA0c',
  );

  static const String demoKitId = 'agrisense-demo-kit';
  static const String cloudSensorAddress = 'cloud://sensor';
  static const String cloudCameraAddress = 'cloud://camera';
}
