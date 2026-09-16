import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'theme/app_colors.dart';
import 'providers/storage_service.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;

  await Hive.initFlutter();
  final storageService = StorageService();
  await storageService.init();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await FirebaseAuth.instance.signInAnonymously();

  await _ensurePlayerDocument();

  await NotificationService().init();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const DuelApp(),
    ),
  );
}

Future<void> _ensurePlayerDocument() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  try {
    final doc = await FirebaseFirestore.instance
        .collection('players')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      await FirebaseFirestore.instance.collection('players').doc(user.uid).set({
        'displayName': user.isAnonymous
            ? 'Guest'
            : (user.displayName?.isNotEmpty == true
                ? user.displayName!
                : user.email?.split('@').first ?? 'Player'),
        'email': user.email,
        'isAnonymous': user.isAnonymous,
        'wins': 0,
        'losses': 0,
        'draws': 0,
        'streak': 0,
        'bestStreak': 0,
        'rating': 1000,
        'totalMatches': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } else {
      await FirebaseFirestore.instance
          .collection('players')
          .doc(user.uid)
          .update({
        'lastSeen': FieldValue.serverTimestamp(),
      });
    }
  } catch (e) {
    debugPrint('Failed to ensure player document: $e');
  }
}

ThemeData _buildTheme(AppColors colors, Brightness brightness) {
  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: colors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.coral,
      brightness: brightness,
      primary: colors.coral,
      secondary: colors.teal,
      surface: colors.surface,
      error: colors.coral,
      onPrimary: colors.onAccent,
      onSecondary: colors.onAccent,
      onSurface: colors.ink,
      onError: colors.onAccent,
    ),
    useMaterial3: true,
    splashColor: Colors.transparent,
    highlightColor: colors.surfaceVariant,
    cardColor: colors.card,
    dividerColor: colors.border,
    extensions: [colors],
    appBarTheme: AppBarTheme(
      backgroundColor: colors.background,
      foregroundColor: colors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colors.coral;
        return colors.inkSubtle;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colors.coralDim;
        return colors.surfaceVariant;
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.coral),
      ),
      labelStyle: TextStyle(color: colors.inkSubtle),
      hintStyle: TextStyle(color: colors.inkFaint),
    ),
  );
}

class DuelApp extends ConsumerWidget {
  const DuelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Duel',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(AppColors.light(), Brightness.light),
      darkTheme: _buildTheme(AppColors.dark(), Brightness.dark),
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}
