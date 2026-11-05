import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Returns whether the user currently allows notifications.
///
/// On iOS the operating system is the source of truth, so use the Firebase
/// Messaging authorization status. permission_handler on iOS only compiles the
/// permission groups enabled through Podfile macros, which makes it a fragile
/// way to read the notification status.
Future<bool> areNotificationsEnabled() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  final status = await Permission.notification.status;
  return status.isGranted;
}
