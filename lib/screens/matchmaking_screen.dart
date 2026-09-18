import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/match.dart';
import '../providers/game_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/secondary_button.dart';
import 'countdown_screen.dart';

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
  bool _navigated = false;
  String? _matchId;
  bool _foundOpponent = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _startSearch();
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

  Future<void> _startSearch() async {
    if (!mounted) return;
    try {
      final matchId = await ref.read(gameServiceProvider).startMatchmaking();
      if (mounted && matchId != null) {
        setState(() => _matchId = matchId);
      }
    } catch (e) {
      debugPrint('[MatchmakingScreen] startMatchmaking error: $e');
      if (mounted) {
        setState(() {
          _matchId = null;
        });
      }
    }
  }

  void _onOpponentFound(String matchId) {
    if (_navigated || !mounted) return;
    _navigated = true;
    _pulseTimer?.cancel();

    setState(() => _foundOpponent = true);

    // Show "Player Found!" for 1.5s, then fetch match and navigate to countdown
    Future.delayed(const Duration(milliseconds: 1500), () async {
      if (!mounted) return;

      // Fetch the match data for the countdown screen
      try {
        final doc = await FirebaseFirestore.instance
            .collection('matches')
            .doc(matchId)
            .get();
        if (!mounted) return;

        if (doc.exists) {
          final match = Match.fromFirestore(doc);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => CountdownScreen(
                matchId: matchId,
                match: match,
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('[MatchmakingScreen] Error fetching match: $e');
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    // PRIMARY: Listen directly to the specific match document.
    if (_matchId != null) {
      ref.listen(matchByIdProvider(_matchId!), (previous, next) {
        final match = next.value;
        if (match != null && match.status == MatchStatus.active) {
          _onOpponentFound(match.id);
        }
      });

      // Check immediately — the match may already be active before the
      // listener was registered (ref.listen only fires on changes).
      final current = ref.read(matchByIdProvider(_matchId!));
      current.whenOrNull(
        data: (match) {
          if (match != null && match.status == MatchStatus.active) {
            _onOpponentFound(match.id);
          }
        },
      );
    }



    final waitingPlayers = ref.watch(waitingPlayersProvider);
    final prefs = ref.watch(matchPreferencesProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _foundOpponent
              ? _buildFoundUI(colors)
              : _buildSearchingUI(colors, waitingPlayers, prefs),
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

  Widget _buildFoundUI(AppColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated checkmark circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: colors.teal.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: colors.teal, width: 3),
            ),
            child: Icon(
              Icons.check_rounded,
              size: 60,
              color: colors.teal,
            ),
          ).animate().scale(
            duration: 400.ms,
            curve: Curves.easeOutBack,
          ).then(delay: 100.ms).fadeIn(duration: 300.ms),

          const SizedBox(height: 32),

          // Player Found text
          Text(
            'Player Found!',
            style: AppTypography.display(color: colors.teal),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

          const SizedBox(height: 12),

          // Get ready text
          Text(
            'Get ready to duel...',
            style: AppTypography.body(color: colors.inkSubtle),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

          const SizedBox(height: 48),

          // Animated loading dots
          _LoadingDots(color: colors.teal),
        ],
      ),
    );
  }

  Widget _buildSearchingUI(
    AppColors colors,
    AsyncValue<List<WaitingPlayer>> waitingPlayers,
    MatchPreferences prefs,
  ) {
    return Column(
      children: [
        const Spacer(flex: 1),

        // Searching animation
        AnimatedBuilder(
          animation: _dotAnimation,
          builder: (context, child) {
            final dotCount = (_dotAnimation.value * 3).toInt() + 1;
            final dots = List.filled(dotCount, '.').join();
            return Text(
              'Finding an opponent$dots',
              style: AppTypography.h1(color: colors.ink),
              textAlign: TextAlign.center,
            );
          },
        ),

        const SizedBox(height: 8),

        // Category/difficulty badge
        if (prefs.categoryName != 'Any' || prefs.difficulty != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colors.coral.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              [
                if (prefs.categoryName != 'Any') prefs.categoryName,
                if (prefs.difficulty != null) _difficultyLabel(prefs.difficulty!),
              ].join(' · '),
              style: AppTypography.caption(color: colors.coral),
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
              AnimatedOpacity(
                opacity: _showingNearby ? 0.3 : 0.1,
                duration: const Duration(milliseconds: 800),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.coral.withValues(alpha: 0.2),
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
                      color: colors.coral.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
              ),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: colors.card,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.coral.withValues(alpha: 0.4),
                    width: 2.5,
                  ),
                ),
                child: Icon(
                  Icons.radar_rounded,
                  size: 26,
                  color: colors.coral,
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
                  Icon(Icons.wifi_find_rounded, size: 32, color: colors.inkFaint),
                  const SizedBox(height: 8),
                  Text(
                    'Scanning for nearby players...',
                    style: AppTypography.caption(color: colors.inkSubtle),
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
                      style: AppTypography.caption(color: colors.inkSubtle),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: players.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
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
          style: AppTypography.caption(color: colors.inkSubtle),
        ),

        const SizedBox(height: 16),

        SecondaryButton(
          label: 'Cancel',
          onPressed: () async {
            final nav = Navigator.of(context);
            await ref.read(gameServiceProvider).cancelMatchmaking();
            if (context.mounted) nav.pop();
          },
        ),

        const SizedBox(height: 32),
      ],
    );
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
    final colors = AppColors.of(context);
    return Container(
      width: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.teal.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.teal.withValues(alpha: 0.2),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.hankenGrotesk(
                color: colors.teal,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: AppTypography.caption(color: colors.ink),
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
                style: GoogleFonts.hankenGrotesk(
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

class _LoadingDots extends StatefulWidget {
  final Color color;

  const _LoadingDots({required this.color});

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _dotsAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    _dotsAnimation = IntTween(begin: 0, end: 3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dotsAnimation,
      builder: (context, child) {
        final dots = '.' * (_dotsAnimation.value % 4);
        return Text(
            dots,
            style: AppTypography.h1(color: widget.color),
          );
      },
    );
  }
}
