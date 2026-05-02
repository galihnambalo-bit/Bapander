import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../utils/supabase_config.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message: ${message.notification?.title}');
}

class NotificationService {
  static const String _oneSignalAppId = '256088f4-4a3c-4636-a036-968379c7e406';

  static Future<void> initialize() async {
    try {
      await OneSignal.shared.setAppId(_oneSignalAppId);
      await OneSignal.shared.promptUserForPushNotificationPermission();
      OneSignal.shared.setNotificationWillShowInForegroundHandler((event) {
        event.complete(event.notification);
      });
      OneSignal.shared.setNotificationOpenedHandler((result) {
        print('OneSignal notification clicked: ${result.notification.title}');
      });
    } catch (e) {
      print('OneSignal error: $e');
    }

    try {
      final fcm = FirebaseMessaging.instance;
      await fcm.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen((message) {
        print('FCM message: ${message.notification?.title}');
      });
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        print('FCM opened app via notification: ${message.notification?.title}');
      });
    } catch (e) {
      print('FCM error: $e');
    }
  }

  static Future<void> setUserId(String userId) async {
    try {
      await OneSignal.shared.setExternalUserId(userId);
      print('OneSignal set external user id: $userId');
    } catch (e) {
      print('OneSignal setExternalUserId error: $e');
    }
  }

  static Future<void> logout() async {
    try {
      await OneSignal.shared.removeExternalUserId();
    } catch (e) {
      print('OneSignal removeExternalUserId error: $e');
    }
  }

  static Future<void> sendPushNotification({
    required String toUserId,
    required String title,
    required String body,
  }) async {
    try {
      await SupabaseConfig.client.functions.invoke('send-notification', body: {
        'to_user_id': toUserId,
        'title': title,
        'body': body,
      });
    } catch (e) {
      print('Send notification error: $e');
    }
  }
}
