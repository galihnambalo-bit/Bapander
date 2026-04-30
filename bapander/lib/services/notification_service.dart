class NotificationService {
  static const String oneSignalAppId = '256088f4-4a3c-4636-a036-968379c7e406';

  static Future<void> initialize() async {
    // Will be enabled after app is stable
    print('NotificationService: skipped for now');
  }

  static Future<void> setUserId(String userId) async {}
  static Future<void> logout() async {}
}
