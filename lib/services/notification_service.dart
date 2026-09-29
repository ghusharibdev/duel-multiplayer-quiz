import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Device-local notifications for duel events.
///
/// Every event is derived from a Firestore snapshot on this device, so nothing
/// here reaches another player. There is no server push: alerts are only
/// produced while this app's isolate is alive (foreground or background).
class NotificationService with WidgetsBindingObserver {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _matchChannelId = 'duel_matches';
  static const Color _coral = Color(0xFFE5533D);

  bool _initialized = false;
  bool _enabled = true;
  bool _appInForeground = true;
  int _nextId = 0;

  /// Initialise the plugin. Permissions are *not* requested here — ask from a
  /// user gesture (see the Settings screen) so the OS prompt is not blocked.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    _enabled = await areNotificationsEnabled() ?? true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
  }

  /// Whether the OS currently allows this app to post notifications.
  /// Returns null when the platform cannot report a status (e.g. web).
  Future<bool?> areNotificationsEnabled() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) return android.areNotificationsEnabled();

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      final options = await ios.checkPermissions();
      return options?.isEnabled;
    }

    return null;
  }

  /// Prompt for permission. Call from a user gesture. Returns the resulting
  /// enabled state, or null if the platform cannot report one.
  Future<bool?> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return android.requestNotificationsPermission();
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return ios.requestPermissions(alert: true, badge: true, sound: true);
    }

    return null;
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  // -------------------------------------------------------------------------
  // Duel events
  // -------------------------------------------------------------------------

  /// An opponent joined a match this device is waiting in.
  Future<void> matchStarted({
    required String matchId,
    required String opponentName,
  }) {
    return _show(
      title: 'Match found',
      body: '$opponentName joined your match',
      payload: {'type': 'match_started', 'matchId': matchId},
    );
  }

  /// The opponent locked in an answer for the current round.
  Future<void> opponentAnswered({
    required String matchId,
    required String opponentName,
  }) {
    return _show(
      title: 'Opponent answered',
      body: '$opponentName just locked in their answer',
      payload: {'type': 'opponent_answered', 'matchId': matchId},
    );
  }

  /// The duel ended. Scored from this device's point of view.
  Future<void> matchFinished({
    required String matchId,
    required bool isDraw,
    required bool won,
    required int score,
    required int opponentScore,
  }) {
    final String body;
    if (isDraw) {
      body = 'Draw $score–$opponentScore';
    } else if (won) {
      body = 'You won $score–$opponentScore';
    } else {
      body = 'You lost $score–$opponentScore';
    }

    return _show(
      title: won ? 'Victory' : (isDraw ? 'Draw' : 'Defeat'),
      body: body,
      payload: {'type': 'match_finished', 'matchId': matchId},
    );
  }

  // -------------------------------------------------------------------------
  // Internals
  // -------------------------------------------------------------------------

  /// Skips notifications the user can already see on screen.
  bool get _suppressed => !_enabled || _appInForeground;

  Future<void> _show({
    required String title,
    required String body,
    Map<String, String> payload = const {},
  }) async {
    if (_suppressed) return;

    try {
      await _plugin.show(
        id: _nextId++,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _matchChannelId,
            'Match notifications',
            channelDescription:
                'Opponent activity and results for your duels',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: _coral,
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        payload: payload.entries.map((e) => '${e.key}=${e.value}').join('&'),
      );
    } catch (e) {
      debugPrint('[NotificationService] Failed to show notification: $e');
    }
  }
}
