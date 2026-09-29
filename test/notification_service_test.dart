import 'dart:io';

import 'package:duel_multiplayer_quiz/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Records what the service asked the OS to display, and fakes the OS answers
/// the service depends on. Everything else would hit a real MethodChannel.
class FakeNotificationsPlatform extends AndroidFlutterLocalNotificationsPlugin {
  FakeNotificationsPlatform({
    this.systemEnabled = true,
    this.grantsPermission = true,
  });

  bool systemEnabled;
  bool grantsPermission;

  final List<({String? title, String? body, String? payload})> shown = [];
  bool cancelledAll = false;
  int permissionRequests = 0;

  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async =>
      true;

  @override
  Future<bool?> areNotificationsEnabled() async => systemEnabled;

  @override
  Future<bool?> requestNotificationsPermission() async {
    permissionRequests++;
    if (grantsPermission) systemEnabled = true;
    return grantsPermission;
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    AndroidNotificationDetails? notificationDetails,
    String? payload,
  }) async {
    if (!systemEnabled) return; // the OS silently drops it
    shown.add((title: title, body: body, payload: payload));
  }

  @override
  Future<void> cancelAll() async => cancelledAll = true;
}

/// The service is a singleton with process-lifetime state, so each test drives
/// it through a fresh isolate-level reset.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeNotificationsPlatform fake;
  late Directory hiveDir;

  setUp(() async {
    fake = FakeNotificationsPlatform();
    FlutterLocalNotificationsPlatform.instance = fake;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    hiveDir = await Directory.systemTemp.createTemp('duel_notify_test');
    Hive.init(hiveDir.path);
    await Hive.deleteBoxFromDisk('notification_prefs');
    NotificationService.debugReset();
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    NotificationService.debugReset();
    await Hive.close();
    if (hiveDir.existsSync()) hiveDir.deleteSync(recursive: true);
  });

  group('delivery', () {
    test('posts an alert when backgrounded and permitted', () async {
      final service = NotificationService();
      await service.init();
      service.debugSetForeground(false);

      await service.matchStarted(matchId: 'm1', opponentName: 'Ada');

      expect(fake.shown, hasLength(1));
      expect(fake.shown.single.title, 'Match found');
      expect(fake.shown.single.body, 'Ada joined your match');
      expect(fake.shown.single.payload, contains('matchId=m1'));
    });

    test('stays silent in the foreground, where the UI already shows it',
        () async {
      final service = NotificationService();
      await service.init();
      service.debugSetForeground(true);

      await service.matchStarted(matchId: 'm1', opponentName: 'Ada');

      expect(fake.shown, isEmpty);
    });

    test('stays silent when the OS has notifications blocked', () async {
      final service = NotificationService();
      await service.init();
      // init() prompted once and was refused.
      fake.grantsPermission = false;
      await service.requestPermission();
      service.debugSetForeground(false);

      await service.opponentAnswered(matchId: 'm1', opponentName: 'Ada');

      expect(fake.shown, isEmpty);
    });

    test('recovers once permission is granted mid-session', () async {
      final service = NotificationService();
      await service.init();
      fake.grantsPermission = false;
      await service.requestPermission();
      service.debugSetForeground(false);

      await service.matchFinished(
        matchId: 'm1',
        isDraw: false,
        won: true,
        score: 5,
        opponentScore: 2,
      );
      expect(fake.shown, isEmpty);

      // User flips the switch back on and the OS now grants it.
      fake.grantsPermission = true;
      await service.requestPermission();

      await service.matchFinished(
        matchId: 'm2',
        isDraw: false,
        won: true,
        score: 5,
        opponentScore: 2,
      );
      expect(fake.shown, hasLength(1));
    });
  });

  group('content', () {
    test('scores the result from this device perspective', () async {
      final service = NotificationService();
      await service.init();
      service.debugSetForeground(false);

      await service.matchFinished(
        matchId: 'm1',
        isDraw: false,
        won: false,
        score: 2,
        opponentScore: 5,
      );
      await service.matchFinished(
        matchId: 'm2',
        isDraw: true,
        won: false,
        score: 3,
        opponentScore: 3,
      );

      expect(fake.shown[0].title, 'Defeat');
      expect(fake.shown[0].body, 'You lost 2–5');
      expect(fake.shown[1].title, 'Draw');
      expect(fake.shown[1].body, 'Draw 3–3');
    });
  });

  group('permission lifecycle', () {
    test('prompts on first Android launch when not yet granted', () async {
      fake.systemEnabled = false;
      await NotificationService().init();
      expect(fake.permissionRequests, 1);
      expect(NotificationService().isActive, isTrue);
    });

    test('does not re-prompt on later launches', () async {
      fake.systemEnabled = false;
      await NotificationService().init();
      NotificationService.debugReset();
      await NotificationService().init();
      expect(fake.permissionRequests, 1);
    });

    test('does not prompt when permission is already granted', () async {
      await NotificationService().init();
      expect(fake.permissionRequests, 0);
    });

    test('never prompts at launch on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      fake.systemEnabled = false;
      await NotificationService().init();
      expect(fake.permissionRequests, 0);
    });

    test('respects a preference the user turned off', () async {
      final service = NotificationService();
      await service.init();
      await service.setEnabled(false);
      service.debugSetForeground(false);

      await service.matchStarted(matchId: 'm1', opponentName: 'Ada');
      expect(fake.shown, isEmpty);
      expect(fake.cancelledAll, isTrue);
    });

    test('keeps the preference across restarts', () async {
      final service = NotificationService();
      await service.init();
      await service.setEnabled(false);

      NotificationService.debugReset();
      final restarted = NotificationService();
      await restarted.init();
      restarted.debugSetForeground(false);

      expect(restarted.isActive, isFalse);
      await restarted.matchStarted(matchId: 'm1', opponentName: 'Ada');
      expect(fake.shown, isEmpty);
    });
  });
}
