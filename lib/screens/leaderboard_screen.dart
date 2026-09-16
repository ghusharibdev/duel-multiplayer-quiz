import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../providers/player_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Leaderboard', style: AppTypography.h1(color: AppColors.ink)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),

              // Leaderboard header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.stone,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _HeaderStat(label: 'Rank', value: '#--', color: AppColors.coral),
                    _HeaderStat(label: 'Wins', value: '0', color: AppColors.gold),
                    _HeaderStat(label: 'Rating', value: '1000', color: AppColors.teal),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Top Players',
                style: AppTypography.h1(color: AppColors.ink),
              ),

              const SizedBox(height: 16),

              Expanded(
                child: leaderboardAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.coral),
                  ),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (players) {
                    if (players.isEmpty) {
                      return Center(
                        child: Text(
                          'No players yet',
                          style: AppTypography.body(
                            color: AppColors.ink.withValues(alpha: 0.4),
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
                          name: player.displayName,
                          wins: player.stats.wins,
                          rating: player.stats.rating,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppTypography.display(color: color)),
        const SizedBox(height: 4),
        Text(label, style: AppTypography.caption(
          color: AppColors.ink.withValues(alpha: 0.5),
        )),
      ],
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  final int rank;
  final String name;
  final int wins;
  final int rating;
  final bool isCurrentUser;

  const _LeaderboardTile({
    required this.rank,
    required this.name,
    required this.wins,
    required this.rating,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppColors.coralLight : AppColors.stone,
        borderRadius: BorderRadius.circular(12),
        border: isCurrentUser
            ? Border.all(color: AppColors.coral, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              '#$rank',
              style: AppTypography.body(
                color: rank <= 3 ? AppColors.gold : AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 16,
            backgroundColor: isCurrentUser ? AppColors.coral : AppColors.teal,
            child: Text(
              name[0].toUpperCase(),
              style: const TextStyle(
                color: AppColors.cream,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: AppTypography.body(
                color: isCurrentUser ? AppColors.coral : AppColors.ink,
              ),
            ),
          ),
          Text(
            '$wins wins',
            style: AppTypography.caption(
              color: AppColors.ink.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '$rating',
            style: AppTypography.timer(color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}
