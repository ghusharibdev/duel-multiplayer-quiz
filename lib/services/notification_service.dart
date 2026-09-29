import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Device-local notifications for duel events.
///
/// Every event is derived from a Firestore snapshot on this device, so nothing
/// here reaches another player. There is no server push: alerts are only
/// produced while this app's isolate is alive (foreground or background).
class NotificationService with WidgetsBindingObserver {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  /// The service is a process-wide singleton whose state must be re-derived
  /// after a sign-out, a Settings change, or in tests.
  @visibleForTesting
  static void debugReset() {
    _instance._initialized = false;
    _instance._systemEnabled = false;
    _instance._userEnabled = true;
    _instance._appInForeground = true;
    _instance._nextId = 0;
  }

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _boxName = 'notification_prefs';
  static const String _enabledKey = 'enabled';
  static const String _requestedKey = 'permission_requested';
  static const String _matchChannelId = 'duel_matches';
  static const Color _coral = Color(0xFFE5533D);

  late Box _box;
  bool _initialized = false;
  bool _systemEnabled = false;
  bool _userEnabled = true;
  bool _appInForeground = true;
  int _nextId = 0;

  /// True only when an alert would actually be posted: the user wants them,
  /// the OS allows them, and they are not already visible on screen.
  bool get canNotify => _userEnabled && _systemEnabled && !_appInForeground;

  /// What the Settings toggle renders. Never shows "on" when the OS would
  /// silently drop the alert.
  bool get isActive => _userEnabled && _systemEnabled;

  /// Initialise the plugin and resolve permission state.
  ///
  /// On Android the OS prompt is shown once on first launch, because without
  /// POST_NOTIFICATIONS no alert can ever be delivered and the grant stays
  /// revocable. iOS is deliberately not prompted at launch — it can only ever
  /// ask once, so it is requested from the Settings toggle instead.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_duel'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    _box = await Hive.openBox(_boxName);
    _userEnabled = _box.get(_enabledKey, defaultValue: true);
    _systemEnabled = await areNotificationsEnabled() ?? false;

    if (!_userEnabled) return;

    if (!_systemEnabled && !_box.get(_requestedKey, defaultValue: false)) {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _box.put(_requestedKey, true);
        await requestPermission();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
  }

  @visibleForTesting
  void debugSetForeground(bool value) => _appInForeground = value;

  /// Whether the OS currently allows this app to post notifications.
  /// Returns null when the platform cannot report a status (e.g. web).
  Future<bool?> areNotificationsEnabled() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) return await android.areNotificationsEnabled();

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final options = await ios.checkPermissions();
        return options?.isEnabled;
      }
    } catch (e) {
      debugPrint('[NotificationService] Permission check failed: $e');
    }
    return null;
  }

  /// Prompt for OS permission and adopt the answer as the user's preference.
  Future<bool> requestPermission() async {
    bool? granted;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        granted = await android.requestNotificationsPermission();
      } else {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        granted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }
    } catch (e) {
      debugPrint('[NotificationService] Permission request failed: $e');
    }

    await _box.put(_requestedKey, true);
    if (granted != null) _systemEnabled = granted;
    await setEnabled(granted ?? true);
    return granted ?? false;
  }

  /// Persist the user's preference. Turning off clears anything already shown;
  /// the OS grant itself can only be changed in system settings.
  Future<void> setEnabled(bool value) async {
    _userEnabled = value;
    await _box.put(_enabledKey, value);
    if (!value) await _plugin.cancelAll();
  }

  /// Re-read the OS grant. Used when the user returns from system settings.
  Future<void> refreshPermissionState() async {
    _systemEnabled = await areNotificationsEnabled() ?? _systemEnabled;
  }

  /// Open the system notification settings for this app.
  Future<void> openSystemSettings() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.openAppNotificationSettings();
    } catch (e) {
      debugPrint('[NotificationService] Opening system settings failed: $e');
    }
  }

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

  Future<void> _show({
    required String title,
    required String body,
    Map<String, String> payload = const {},
  }) async {
    // Skips alerts the user can already see on screen, or that the OS would
    // drop anyway.
    if (!canNotify) return;

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
            icon: 'ic_stat_duel',
            color: _coral,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        payload: payload.entries.map((e) => '${e.key}=${e.value}').join('&'),
      );
    } catch (e) {
      debugPrint('[NotificationService] Failed to show notification: $e');
    }
  }
}
