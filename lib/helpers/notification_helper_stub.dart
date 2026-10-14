// Stub implementation for non-web platforms and tests
class NotificationHelper {
  static Future<bool> requestPermission() async => true;
  static bool get hasPermission => true;
  static void showNotification(String title, String body) {}
  static void playAlarmSound() {}
}
