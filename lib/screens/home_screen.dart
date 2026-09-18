import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
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

  static const int _inlineMatchLimit = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final userAsync = ref.watch(authStateProvider);
    final playerAsync = ref.watch(currentPlayerProvider);
    final matchHistory = ref.watch(matchHistoryProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: userAsync.when(
          loading: () => Center(
            child: CircularProgressIndicator(color: colors.coral),
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
                                  ? colors.surface
                                  : colors.coral,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isAnonymous
                                    ? colors.border
                                    : colors.coral,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: isAnonymous
                                  ? Icon(
                                      Icons.person_outline_rounded,
                                      size: 22,
                                      color: colors.inkSubtle,
                                    )
                                  : Text(
                                      initials,
                                      style: GoogleFonts.hankenGrotesk(
                                        color: colors.background,
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
                                style: AppTypography.h1(color: colors.ink),
                              ),
                              if (isAnonymous)
                                Text(
                                  'Tap avatar to sign in',
                                  style: AppTypography.caption(
                                    color: colors.inkSubtle,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Theme toggle
                        IconButton(
                          onPressed: () {
                            ref.read(themeProvider.notifier).toggle();
                          },
                          icon: Icon(
                            Theme.of(context).brightness == Brightness.dark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            color: colors.ink,
                            size: 24,
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
                          icon: Icon(
                            Icons.settings_rounded,
                            color: colors.ink,
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
                    style: AppTypography.scoreDisplay(color: colors.coral),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Real-Time Trivia',
                    style: AppTypography.body(color: colors.inkSubtle),
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
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatItem(
                              label: 'Wins',
                              value: '${stats?.wins ?? 0}',
                              color: colors.coral,
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: colors.border,
                            ),
                            _StatItem(
                              label: 'Losses',
                              value: '${stats?.losses ?? 0}',
                              color: colors.teal,
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: colors.border,
                            ),
                            _StatItem(
                              label: 'Streak',
                              value: '${stats?.streak ?? 0}',
                              color: colors.gold,
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

                  // Match history header
                  Row(
                    children: [
                      Text(
                        'Recent Matches',
                        style: AppTypography.h1(color: colors.ink),
                      ),
                      const Spacer(),
                      matchHistory.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (matches) {
                          if (matches.length <= _inlineMatchLimit) {
                            return const SizedBox.shrink();
                          }
                          return GestureDetector(
                            onTap: () => _showAllMatchesSheet(context, ref, colors),
                            child: Text(
                              'View All (${matches.length})',
                              style: AppTypography.caption(
                                color: colors.coral,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Inline match history (max 5)
                  Expanded(
                    flex: 3,
                    child: RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(currentPlayerProvider);
                        ref.invalidate(matchHistoryProvider);
                      },
                      color: colors.coral,
                      child: matchHistory.when(
                        loading: () => Center(
                          child: CircularProgressIndicator(color: colors.coral),
                        ),
                        error: (e, s) =>
                            const Center(child: Text('Error loading matches')),
                        data: (matches) {
                          if (matches.isEmpty) {
                            return Center(
                              child: Text(
                                'No matches yet',
                                style: AppTypography.body(
                                  color: colors.inkSubtle,
                                ),
                              ),
                            );
                          }
                          final displayCount = matches.length > _inlineMatchLimit
                              ? _inlineMatchLimit
                              : matches.length;
                          return ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: displayCount,
                            itemBuilder: (context, index) {
                              return _MatchTile(match: matches[index]);
                            },
                          );
                        },
                      ),
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

  void _showAllMatchesSheet(
      BuildContext context, WidgetRef ref, AppColors colors) {
    final matchHistoryAsync = ref.read(matchHistoryProvider);
    final matches = matchHistoryAsync.whenOrNull(
          data: (data) => data,
        ) ??
        [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'All Matches (${matches.length})',
                  style: AppTypography.h1(color: colors.ink),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      return _MatchTile(match: matches[index]);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
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
    final colors = AppColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppTypography.display(color: color)),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.caption(
            color: colors.inkSubtle,
          ),
        ),
      ],
    );
  }
}

class _MatchTile extends StatelessWidget {
  final Map<String, dynamic> match;

  const _MatchTile({required this.match});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isPlayer1 = match['isPlayer1'] ?? true;
    final p1Score = match['player1Score'] ?? 0;
    final p2Score = match['player2Score'] ?? 0;
    final myScore = isPlayer1 ? p1Score : p2Score;
    final oppScore = isPlayer1 ? p2Score : p1Score;
    final won = myScore > oppScore;
    final drew = myScore == oppScore;
    final opponentName = isPlayer1
        ? (match['player2Name'] ?? 'Opponent')
        : (match['player1Name'] ?? 'Opponent');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 40,
            decoration: BoxDecoration(
              color: won ? colors.gold : drew ? colors.surface : colors.teal,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'vs $opponentName',
                  style: AppTypography.body(color: colors.ink),
                ),
                Text(
                  won ? 'Won' : drew ? 'Draw' : 'Lost',
                  style: AppTypography.caption(
                    color: won
                        ? colors.gold
                        : drew
                            ? colors.ink.withValues(alpha: 0.5)
                            : colors.teal,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$myScore - $oppScore',
            style: AppTypography.timer(color: colors.ink),
          ),
        ],
      ),
    );
  }
}
