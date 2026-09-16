import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/primary_button.dart';
import '../widgets/secondary_button.dart';
import 'auth_screen.dart';
import 'category_screen.dart';
import 'leaderboard_screen.dart';
import 'settings_screen.dart';
import 'room_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    final playerAsync = ref.watch(currentPlayerProvider);
    final matchHistory = ref.watch(matchHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: userAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.coral),
          ),
          error: (e, s) => const Center(child: Text('Error')),
          data: (user) {
            final isAnonymous = user?.isAnonymous ?? true;
            final displayName = user?.displayName?.isNotEmpty == true
                ? user!.displayName!
                : (user?.email?.split('@').first ?? 'Guest');
            final initials = isAnonymous
                ? 'G'
                : (displayName.isNotEmpty
                    ? displayName[0].toUpperCase()
                    : '?');

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── Top bar: profile icon + settings ───
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        // Profile avatar
                        GestureDetector(
                          onTap: () {
                            if (isAnonymous) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const AuthScreen()),
                              );
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => const SettingsScreen()),
                              );
                            }
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isAnonymous
                                  ? AppColors.stone
                                  : AppColors.coral,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isAnonymous
                                    ? AppColors.ink.withValues(alpha: 0.1)
                                    : AppColors.coral,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: isAnonymous
                                  ? Icon(
                                      Icons.person_outline_rounded,
                                      size: 22,
                                      color:
                                          AppColors.ink.withValues(alpha: 0.4),
                                    )
                                  : Text(
                                      initials,
                                      style: const TextStyle(
                                        color: AppColors.cream,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Greeting
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAnonymous
                                    ? 'Guest Player'
                                    : 'Hi, $displayName',
                                style: AppTypography.h1(
                                  color: AppColors.ink,
                                ),
                              ),
                              if (isAnonymous)
                                Text(
                                  'Tap avatar to sign in',
                                  style: AppTypography.caption(
                                    color:
                                        AppColors.ink.withValues(alpha: 0.4),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Settings icon
                        IconButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen()),
                            );
                          },
                          icon: const Icon(
                            Icons.settings_rounded,
                            color: AppColors.ink,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // App title
                  Text(
                    'DUEL',
                    style:
                        AppTypography.scoreDisplay(color: AppColors.coral),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Real-Time Trivia',
                    style: AppTypography.body(
                      color: AppColors.ink.withValues(alpha: 0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Stats summary
                  playerAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, s) => const SizedBox.shrink(),
                    data: (player) {
                      final stats = player?.stats;
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.stone,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatItem(
                              label: 'Wins',
                              value: '${stats?.wins ?? 0}',
                              color: AppColors.coral,
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: AppColors.ink.withValues(alpha: 0.1),
                            ),
                            _StatItem(
                              label: 'Losses',
                              value: '${stats?.losses ?? 0}',
                              color: AppColors.teal,
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: AppColors.ink.withValues(alpha: 0.1),
                            ),
                            _StatItem(
                              label: 'Streak',
                              value: '${stats?.streak ?? 0}',
                              color: AppColors.gold,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // Play button
                  PrimaryButton(
                    label: 'Play',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CategoryScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Play with Friends button
                  SecondaryButton(
                    label: 'Play with Friends',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RoomScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Leaderboard & Settings row
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Leaderboard',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LeaderboardScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SecondaryButton(
                          label: 'Settings',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Match history
                  Text(
                    'Recent Matches',
                    style: AppTypography.h1(color: AppColors.ink),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    flex: 3,
                    child: matchHistory.when(
                      loading: () => const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.coral),
                      ),
                      error: (e, s) =>
                          const Center(child: Text('Error loading matches')),
                      data: (matches) {
                        if (matches.isEmpty) {
                          return Center(
                            child: Text(
                              'No matches yet',
                              style: AppTypography.body(
                                color: AppColors.ink.withValues(alpha: 0.4),
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: matches.length,
                          itemBuilder: (context, index) {
                            final match = matches[index];
                            final isPlayer1 =
                                match['isPlayer1'] ?? true;
                            final p1Score = match['player1Score'] ?? 0;
                            final p2Score = match['player2Score'] ?? 0;
                            final myScore =
                                isPlayer1 ? p1Score : p2Score;
                            final oppScore =
                                isPlayer1 ? p2Score : p1Score;
                            final won = myScore > oppScore;
                            final drew = myScore == oppScore;
                            final opponentName = isPlayer1
                                ? (match['player2Name'] ?? 'Opponent')
                                : (match['player1Name'] ?? 'Opponent');

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.stone,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: won
                                          ? AppColors.gold
                                          : drew
                                              ? AppColors.stone
                                              : AppColors.teal,
                                      borderRadius:
                                          BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'vs $opponentName',
                                          style: AppTypography.body(
                                            color: AppColors.ink,
                                          ),
                                        ),
                                        Text(
                                          won
                                              ? 'Won'
                                              : drew
                                                  ? 'Draw'
                                                  : 'Lost',
                                          style: AppTypography.caption(
                                            color: won
                                                ? AppColors.gold
                                                : drew
                                                    ? AppColors.ink
                                                        .withValues(
                                                            alpha: 0.5)
                                                    : AppColors.teal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '$myScore - $oppScore',
                                    style: AppTypography.timer(
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppTypography.display(color: color)),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.caption(
            color: AppColors.ink.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
