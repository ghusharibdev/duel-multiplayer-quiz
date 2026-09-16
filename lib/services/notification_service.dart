import 'dart:convert';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background notifications are handled by the OS
  // No custom processing needed for this app
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize notifications: request permission, configure handlers
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      return;
    }

    // Initialize local notifications for in-app display
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap — could navigate to match
      },
    );

    // Get FCM token and save to player document
    final token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }

    // Listen for token refresh
    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('players')
          .doc(user.uid)
          .update({
        'fcmToken': token,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Token save failure is non-critical
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    // Show local notification when app is in foreground
    _showLocalNotification(
      title: notification.title ?? 'Duel',
      body: notification.body ?? '',
      payload: jsonEncode(message.data),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    // Could navigate to a specific match based on data
    final data = message.data;
    if (data.containsKey('matchId')) {
      // Navigation handled by the app's routing
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'duel_matches',
      'Match Notifications',
      channelDescription: 'Notifications for duel matches',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFE5533D), // AppColors.coral
    );

    const details = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Send a notification to a specific player via their FCM token
  static Future<void> sendToPlayer({
    required String targetUid,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      // Get the target player's FCM token
      final playerDoc = await FirebaseFirestore.instance
          .collection('players')
          .doc(targetUid)
          .get();

      if (!playerDoc.exists) return;

      final fcmToken = playerDoc.data()?['fcmToken'] as String?;
      if (fcmToken == null || fcmToken.isEmpty) return;

      // Store notification in Firestore for delivery
      // (Cloud Function would send via FCM API in production)
      await FirebaseFirestore.instance.collection('notifications').add({
        'to': fcmToken,
        'title': title,
        'body': body,
        'data': data ?? {},
        'createdAt': FieldValue.serverTimestamp(),
        'sent': false,
      });
    } catch (e) {
      // Notification send failure is non-critical
    }
  }

  /// Send match result notification to both players
  static Future<void> sendMatchResult({
    required String player1Uid,
    required String player2Uid,
    required String matchId,
    required bool player1Won,
    required bool isDraw,
  }) async {
    final resultText = isDraw
        ? 'The match ended in a draw!'
        : (player1Won ? 'You won the match!' : 'Your opponent won!');

    await Future.wait([
      sendToPlayer(
        targetUid: player1Uid,
        title: 'Match Complete',
        body: resultText,
        data: {'matchId': matchId, 'type': 'match_result'},
      ),
      sendToPlayer(
        targetUid: player2Uid,
        title: 'Match Complete',
        body: isDraw
            ? 'The match ended in a draw!'
            : (player1Won
                ? 'Your opponent won!'
                : 'You won the match!'),
        data: {'matchId': matchId, 'type': 'match_result'},
      ),
    ]);
  }
}
