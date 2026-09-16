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

  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Sign in anonymously
  await FirebaseAuth.instance.signInAnonymously();

  // Create player document if it doesn't exist
  await _ensurePlayerDocument();

  // Initialize notifications
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
      // Update lastSeen on app open
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

class DuelApp extends StatelessWidget {
  const DuelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Duel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.coral,
          primary: AppColors.coral,
          secondary: AppColors.teal,
          surface: AppColors.stone,
          onPrimary: AppColors.cream,
          onSecondary: AppColors.cream,
          onSurface: AppColors.ink,
        ),
        useMaterial3: true,
        splashColor: Colors.transparent,
        highlightColor: AppColors.stone,
      ),
      home: const HomeScreen(),
    );
  }
}
