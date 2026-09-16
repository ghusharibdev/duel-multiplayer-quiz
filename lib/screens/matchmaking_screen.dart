import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/secondary_button.dart';
import 'match_screen.dart';

class MatchmakingScreen extends ConsumerStatefulWidget {
  const MatchmakingScreen({super.key});

  @override
  ConsumerState<MatchmakingScreen> createState() =>
      _MatchmakingScreenState();
}

class _MatchmakingScreenState extends ConsumerState<MatchmakingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _dotAnimation;
  Timer? _pulseTimer;
  bool _showingNearby = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _dotAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(gameServiceProvider).startMatchmaking();
    });

    // Pulse the "looking for players" indicator
    _pulseTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _showingNearby = !_showingNearby);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentMatchProvider, (previous, next) {
      final match = next.value;
      if (match != null && match.status.name == 'active' && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MatchScreen(matchId: match.id),
          ),
        );
      }
    });

    final waitingPlayers = ref.watch(waitingPlayersProvider);
    final prefs = ref.watch(matchPreferencesProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 1),

              // Radar/search animation
              AnimatedBuilder(
                animation: _dotAnimation,
                builder: (context, child) {
                  final dotCount = (_dotAnimation.value * 3).toInt() + 1;
                  final dots = List.filled(dotCount, '.').join();
                  return Text(
                    'Finding an opponent$dots',
                    style: AppTypography.h1(color: AppColors.ink),
                    textAlign: TextAlign.center,
                  );
                },
              ),

              const SizedBox(height: 8),

              // Category/difficulty badge
              if (prefs.categoryName != 'Any' ||
                  prefs.difficulty != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    [
                      if (prefs.categoryName != 'Any')
                        prefs.categoryName,
                      if (prefs.difficulty != null)
                        _difficultyLabel(prefs.difficulty!),
                    ].join(' · '),
                    style: AppTypography.caption(color: AppColors.coral),
                  ),
                ),

              const SizedBox(height: 24),

              // Radar circle
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer pulse rings
                    AnimatedOpacity(
                      opacity: _showingNearby ? 0.3 : 0.1,
                      duration: const Duration(milliseconds: 800),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.coral.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    AnimatedOpacity(
                      opacity: _showingNearby ? 0.5 : 0.2,
                      duration: const Duration(milliseconds: 800),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.coral.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    // Center icon
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.stone,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.coral.withValues(alpha: 0.4),
                          width: 2.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.radar_rounded,
                        size: 26,
                        color: AppColors.coral,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Nearby / waiting players
              waitingPlayers.when(
                loading: () => const SizedBox(height: 40),
                error: (_, _) => const SizedBox(height: 40),
                data: (players) {
                  if (players.isEmpty) {
                    return Column(
                      children: [
                        Icon(
                          Icons.wifi_find_rounded,
                          size: 32,
                          color: AppColors.ink.withValues(alpha: 0.2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scanning for nearby players...',
                          style: AppTypography.caption(
                            color: AppColors.ink.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${players.length} player${players.length == 1 ? '' : 's'} looking for a match',
                            style: AppTypography.caption(
                              color: AppColors.ink.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: players.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final p = players[index];
                            return _NearbyPlayerCard(
                              name: p.name,
                              category: p.categoryName ?? 'Any',
                              difficulty: p.difficultyName ?? 'Any',
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),

              const Spacer(flex: 2),

              Text(
                'Tap Cancel to go back',
                style: AppTypography.caption(
                  color: AppColors.ink.withValues(alpha: 0.4),
                ),
              ),

              const SizedBox(height: 16),

              SecondaryButton(
                label: 'Cancel',
                onPressed: () async {
                  await ref.read(gameServiceProvider).cancelMatchmaking();
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  String _difficultyLabel(int d) {
    switch (d) {
      case 1:
        return 'Easy';
      case 2:
        return 'Medium';
      case 3:
        return 'Hard';
      default:
        return 'Any';
    }
  }
}

class _NearbyPlayerCard extends StatelessWidget {
  final String name;
  final String category;
  final String difficulty;

  const _NearbyPlayerCard({
    required this.name,
    required this.category,
    required this.difficulty,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.stone,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.teal.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.teal.withValues(alpha: 0.2),
            child: Text(
              name[0].toUpperCase(),
              style: const TextStyle(
                color: AppColors.teal,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: AppTypography.caption(color: AppColors.ink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // Online indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Online',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.green.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
