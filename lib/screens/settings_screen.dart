import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../providers/auth_provider.dart';
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
      // Request permission
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
      // Open app settings since we can't programmatically disable
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

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title:
            Text('Settings', style: AppTypography.h1(color: AppColors.ink)),
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
                          color: AppColors.stone,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            // Profile circle
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isAnonymous
                                  ? AppColors.ink.withValues(alpha: 0.1)
                                  : AppColors.coral,
                              child: Text(
                                isAnonymous
                                    ? 'G'
                                    : (email != null && email.isNotEmpty
                                        ? email[0].toUpperCase()
                                        : '?'),
                                style: TextStyle(
                                  color: isAnonymous
                                      ? AppColors.ink.withValues(alpha: 0.4)
                                      : AppColors.cream,
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
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  Text(
                                    isAnonymous
                                        ? 'Sign in to save your stats'
                                        : 'Signed in',
                                    style: AppTypography.caption(
                                      color: AppColors.ink
                                          .withValues(alpha: 0.4),
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

              // Sound toggle
              _SettingsTile(
                icon: Icons.volume_up_rounded,
                title: 'Sound Effects',
                trailing: Switch(
                  value: _soundEnabled,
                  onChanged: (value) {
                    setState(() => _soundEnabled = value);
                  },
                  activeThumbColor: AppColors.coral,
                ),
              ),

              const SizedBox(height: 8),

              // Notifications toggle
              _SettingsTile(
                icon: Icons.notifications_rounded,
                title: 'Notifications',
                trailing: _loadingNotifications
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch(
                        value: _notificationsEnabled,
                        onChanged: _toggleNotifications,
                        activeThumbColor: AppColors.coral,
                      ),
              ),

              const SizedBox(height: 8),

              // About
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'About',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.ink,
                ),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Duel',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(
                      Icons.sports_esports_rounded,
                      color: AppColors.coral,
                      size: 48,
                    ),
                    children: [
                      Text(
                        'A real-time 1v1 trivia duel app built with Flutter and Firebase.',
                        style: AppTypography.body(color: AppColors.ink),
                      ),
                    ],
                  );
                },
              ),

              const Spacer(),

              // Sign out button
              TextButton(
                onPressed: () async {
                  final authService = ref.read(authProvider);
                  await authService.signOut();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Text(
                  'Sign Out',
                  style: AppTypography.body(color: AppColors.coral),
                ),
              ),

              const SizedBox(height: 8),

              // App version
              Text(
                'Duel v1.0.0',
                style: AppTypography.caption(
                  color: AppColors.ink.withValues(alpha: 0.3),
                ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.stone,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.ink, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: AppTypography.body(color: AppColors.ink),
              ),
            ),
            if (trailing != null) trailing!
          ],
        ),
      ),
    );
  }
}
