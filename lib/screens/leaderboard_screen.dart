import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/player.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final playerAsync = ref.watch(currentPlayerProvider);
    final user = FirebaseAuth.instance.currentUser;

    // Compute user's rank from leaderboard list
    int? userRank;
    final leaderboardPlayers = leaderboardAsync.whenOrNull(
          data: (players) => players,
        ) ??
        [];
    for (int i = 0; i < leaderboardPlayers.length; i++) {
      if (leaderboardPlayers[i].uid == user?.uid) {
        userRank = i + 1;
        break;
      }
    }

    final playerStats = playerAsync.whenOrNull(
          data: (player) => player?.stats,
        );

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Leaderboard', style: AppTypography.h1(color: colors.ink)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // Leaderboard header — shows actual user stats
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _HeaderStat(
                      label: 'Rank',
                      value: userRank != null ? '#$userRank' : '#--',
                      color: colors.coral,
                    ),
                    _HeaderStat(
                      label: 'Win Rate',
                      value: _winRateLabel(playerStats),
                      color: colors.gold,
                    ),
                    _HeaderStat(
                      label: 'Rating',
                      value: '${playerStats?.rating ?? 1000}',
                      color: colors.teal,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Top Players',
                style: AppTypography.h1(color: colors.ink),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: leaderboardAsync.when(
                  loading: () => Center(
                    child: CircularProgressIndicator(color: colors.coral),
                  ),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (players) {
                    if (players.isEmpty) {
                      return Center(
                        child: Text(
                          'No players yet',
                          style: AppTypography.body(
                            color: colors.inkSubtle,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        final player = players[index];
                        final isCurrentUser = user?.uid == player.uid;
                        return _LeaderboardTile(
                          rank: index + 1,
                          player: player,
                          isCurrentUser: isCurrentUser,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _winRateLabel(PlayerStats? stats) {
  if (stats == null) return '--%';
  final total = stats.wins + stats.losses + stats.draws;
  if (total == 0) return '--%';
  return '${((stats.wins / total) * 100).round()}%';
}

class _HeaderStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeaderStat({
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
        Text(label, style: AppTypography.caption(
          color: colors.inkSubtle,
        )),
      ],
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final Player player;
  final bool isCurrentUser;

  const _LeaderboardTile({
    required this.rank,
    required this.player,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final stats = player.stats;
    final totalGames = stats.wins + stats.losses + stats.draws;
    final winRate = totalGames > 0
        ? ((stats.wins / totalGames) * 100).round()
        : 0;

    // Medal icons for top 3
    String rankText = '#$rank';
    if (rank == 1) {
      rankText = '🥇';
    } else if (rank == 2) {
      rankText = '🥈';
    } else if (rank == 3) {
      rankText = '🥉';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser ? colors.coralLight : colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(color: colors.coral, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 36,
            child: rank <= 3
                ? Text(rankText, style: const TextStyle(fontSize: 20))
                : Text(
                    rankText,
                    style: AppTypography.body(
                      color: rank <= 10 ? colors.gold : colors.inkSubtle,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          // Avatar
          CircleAvatar(
            radius: 16,
            backgroundColor: isCurrentUser ? colors.coral : colors.teal,
            child: Text(
              player.displayName.isNotEmpty
                  ? player.displayName[0].toUpperCase()
                  : '?',
              style: GoogleFonts.hankenGrotesk(
                color: colors.background,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + win rate
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.displayName,
                  style: AppTypography.body(
                    color: isCurrentUser ? colors.coral : colors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$winRate% Win Rate · $totalGames Games',
                  style: AppTypography.caption(
                    color: colors.inkSubtle,
                  ),
                ),
              ],
            ),
          ),
          // Streak
          if (stats.streak >= 2)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '🔥${stats.streak}',
                style: GoogleFonts.hankenGrotesk(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.gold,
                ),
              ),
            ),
          // Rating
          Text(
            '${stats.rating}',
            style: AppTypography.timer(color: colors.ink),
          ),
        ],
      ),
    );
  }
}
