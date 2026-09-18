import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'home_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _soundEnabled = true;
  bool _notificationsEnabled = false;
  bool _loadingNotifications = true;

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
  }

  Future<void> _checkNotificationStatus() async {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    setState(() {
      _notificationsEnabled =
          settings.authorizationStatus == AuthorizationStatus.authorized;
      _loadingNotifications = false;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      setState(() {
        _notificationsEnabled =
            settings.authorizationStatus == AuthorizationStatus.authorized;
      });
    } else {
      setState(() => _notificationsEnabled = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'To fully disable, turn off notifications in device settings',
            ),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(authStateProvider);
    final colors = AppColors.of(context);
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Settings', style: AppTypography.h1(color: colors.ink)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // Account section
              userAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const SizedBox.shrink(),
                data: (user) {
                  final isAnonymous = user?.isAnonymous ?? true;
                  final email = user?.email;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isAnonymous
                                  ? colors.border
                                  : colors.coral,
                              child: Text(
                                isAnonymous
                                    ? 'G'
                                    : (email != null && email.isNotEmpty
                                        ? email[0].toUpperCase()
                                        : '?'),
                                style: GoogleFonts.hankenGrotesk(
                                  color: isAnonymous
                                      ? colors.inkSubtle
                                      : colors.onAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isAnonymous
                                        ? 'Guest Account'
                                        : email ?? 'Account',
                                    style: AppTypography.body(
                                      color: colors.ink,
                                    ),
                                  ),
                                  Text(
                                    isAnonymous
                                        ? 'Sign in to save your stats'
                                        : 'Signed in',
                                    style: AppTypography.caption(
                                      color: colors.inkSubtle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),

              // Theme toggle
              _SettingsTile(
                icon: themeMode == ThemeMode.dark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                title: 'Appearance',
                trailing: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_rounded, size: 18),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_rounded, size: 18),
                    ),
                  ],
                  selected: {themeMode},
                  onSelectionChanged: (modes) {
                    ref.read(themeProvider.notifier).setThemeMode(modes.first);
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return colors.coral;
                      }
                      return colors.surfaceVariant;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return colors.onAccent;
                      }
                      return colors.inkSubtle;
                    }),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Sound toggle
              _SettingsTile(
                icon: Icons.volume_up_rounded,
                title: 'Sound Effects',
                trailing: Switch(
                  value: _soundEnabled,
                  onChanged: (value) {
                    setState(() => _soundEnabled = value);
                  },
                  activeThumbColor: colors.coral,
                ),
              ),

              const SizedBox(height: 8),

              // Notifications toggle
              _SettingsTile(
                icon: Icons.notifications_rounded,
                title: 'Notifications',
                trailing: _loadingNotifications
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.inkSubtle,
                        ),
                      )
                    : Switch(
                        value: _notificationsEnabled,
                        onChanged: _toggleNotifications,
                        activeThumbColor: colors.coral,
                      ),
              ),

              const SizedBox(height: 8),

              // About
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'About',
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colors.ink,
                ),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Duel',
                    applicationVersion: '1.0.0',
                    applicationIcon: Icon(
                      Icons.sports_esports_rounded,
                      color: colors.coral,
                      size: 48,
                    ),
                    children: [
                      Text(
                        'A real-time 1v1 trivia duel app built with Flutter and Firebase.',
                        style: AppTypography.body(color: colors.ink),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 32),

              // Sign out button
              TextButton(
                onPressed: () async {
                  final authService = ref.read(authProvider);
                  await authService.signOut();
                  if (context.mounted) {
                    // Reset the entire nav stack to home screen
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (_) => const HomeScreen(),
                      ),
                      (route) => false,
                    );
                  }
                },
                child: Text(
                  'Sign Out',
                  style: AppTypography.body(color: colors.coral),
                ),
              ),

              const SizedBox(height: 8),

              // App version
              Text(
                'Duel v1.0.0',
                style: AppTypography.caption(color: colors.inkFaint),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: colors.ink, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: AppTypography.body(color: colors.ink),
              ),
            ),
            ?trailing
          ],
        ),
      ),
    );
  }
}
