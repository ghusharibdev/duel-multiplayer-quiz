import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../models/match.dart';
import '../providers/game_provider.dart';
import '../services/open_trivia_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/primary_button.dart';
import '../widgets/secondary_button.dart';
import 'match_screen.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  final _codeController = TextEditingController();
  bool _isCreating = false;
  bool _isJoining = false;
  String? _createdCode;
  String? _createdMatchId;
  String? _error;

  // Category / difficulty state
  int? _selectedCategoryId;
  String _selectedCategoryName = 'Any Category';
  int? _selectedDifficulty;
  StreamSubscription? _matchSub;

  static const List<_DifficultyOption> _difficulties = [
    _DifficultyOption(label: 'Any', value: null, icon: Icons.all_inclusive_rounded),
    _DifficultyOption(label: 'Easy', value: 1, icon: Icons.sentiment_satisfied_rounded),
    _DifficultyOption(label: 'Medium', value: 2, icon: Icons.sentiment_neutral_rounded),
    _DifficultyOption(label: 'Hard', value: 3, icon: Icons.sentiment_dissatisfied_rounded),
  ];

  @override
  void dispose() {
    _codeController.dispose();
    _matchSub?.cancel();
    super.dispose();
  }

  Future<void> _createRoom() async {
    setState(() {
      _isCreating = true;
      _error = null;
    });

    try {
      final prefs = MatchPreferences(
        categoryId: _selectedCategoryId,
        difficulty: _selectedDifficulty,
        categoryName: _selectedCategoryName,
      );

      final code = await ref.read(roomServiceProvider).createRoom(prefs);

      // Get the match doc we just created
      final snapshot = await FirebaseFirestore.instance
          .collection('matches')
          .where('roomCode', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) throw Exception('Failed to create room');

      final matchId = snapshot.docs.first.id;

      setState(() {
        _createdCode = code;
        _createdMatchId = matchId;
        _isCreating = false;
      });

      // KEY FIX: Listen directly to this match document for status changes
      _matchSub?.cancel();
      _matchSub = matchDocStream(matchId).listen((match) {
        if (match != null && match.status == MatchStatus.active && mounted) {
          // Opponent joined — navigate to match
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => MatchScreen(matchId: matchId),
            ),
          );
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isCreating = false;
      });
    }
  }

  Future<void> _joinRoom() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      setState(() => _error = 'Enter a 6-character room code');
      return;
    }

    setState(() {
      _isJoining = true;
      _error = null;
    });

    try {
      final matchId = await ref.read(roomServiceProvider).joinRoom(code);
      if (matchId != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => MatchScreen(matchId: matchId),
          ),
        );
      } else {
        setState(() {
          _error = 'No room found with that code';
          _isJoining = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isJoining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Play with Friends', style: AppTypography.h1(color: AppColors.ink)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _createdCode != null
              ? _buildCodeDisplay()
              : _buildCreateJoin(),
        ),
      ),
    );
  }

  Widget _buildCreateJoin() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),

        // ─── Difficulty ───
        Text('Difficulty', style: AppTypography.h1(color: AppColors.ink)),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _difficulties.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final d = _difficulties[index];
              final isSelected = _selectedDifficulty == d.value;
              return GestureDetector(
                onTap: () => setState(() => _selectedDifficulty = d.value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.coral : AppColors.stone,
                    borderRadius: BorderRadius.circular(22),
                    border: isSelected ? null : Border.all(color: AppColors.ink.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(d.icon, size: 16, color: isSelected ? AppColors.cream : AppColors.ink),
                      const SizedBox(width: 6),
                      Text(d.label, style: AppTypography.body(color: isSelected ? AppColors.cream : AppColors.ink)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 24),

        // ─── Category ───
        Text('Topic', style: AppTypography.h1(color: AppColors.ink)),
        const SizedBox(height: 12),
        // Use Wrap so all 25 categories are visible without fixed height
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // "Any" option
            _CategoryTile(
              label: 'Any',
              icon: Icons.shuffle_rounded,
              isSelected: _selectedCategoryId == null,
              onTap: () => setState(() {
                _selectedCategoryId = null;
                _selectedCategoryName = 'Any Category';
              }),
            ),
            // All categories from API
            for (final entry in OpenTriviaService.categories.entries)
              _CategoryTile(
                label: entry.value,
                icon: _categoryIcon(entry.key),
                isSelected: _selectedCategoryId == entry.key,
                onTap: () => setState(() {
                  _selectedCategoryId = entry.key;
                  _selectedCategoryName = entry.value;
                }),
              ),
          ],
        ),

        const SizedBox(height: 24),

        // ─── Create room ───
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.stone,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Icon(Icons.add_circle_outline_rounded, size: 40, color: AppColors.coral),
              const SizedBox(height: 8),
              Text('Create a Room', style: AppTypography.h1(color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(
                'Get a code to share with your friend',
                style: AppTypography.body(color: AppColors.ink.withValues(alpha: 0.5)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: _isCreating ? 'Creating...' : 'Create Room',
                onPressed: _isCreating ? () {} : _createRoom,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // OR divider
        Row(
          children: [
            Expanded(child: Container(height: 1, color: AppColors.ink.withValues(alpha: 0.1))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('OR', style: AppTypography.caption(color: AppColors.ink.withValues(alpha: 0.4))),
            ),
            Expanded(child: Container(height: 1, color: AppColors.ink.withValues(alpha: 0.1))),
          ],
        ),

        const SizedBox(height: 20),

        // ─── Join room ───
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.stone,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Icon(Icons.input_rounded, size: 40, color: AppColors.teal),
              const SizedBox(height: 8),
              Text('Join a Room', style: AppTypography.h1(color: AppColors.ink)),
              const SizedBox(height: 4),
              Text(
                'Enter the code your friend shared',
                style: AppTypography.body(color: AppColors.ink.withValues(alpha: 0.5)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                style: AppTypography.display(color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'ABC123',
                  hintStyle: AppTypography.display(color: AppColors.ink.withValues(alpha: 0.2)),
                  counterText: '',
                  filled: true,
                  fillColor: AppColors.cream,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.teal),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                label: _isJoining ? 'Joining...' : 'Join Room',
                onPressed: _isJoining ? () {} : _joinRoom,
              ),
            ],
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: AppTypography.body(color: AppColors.coral), textAlign: TextAlign.center),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildCodeDisplay() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Icon(Icons.hourglass_top_rounded, size: 64, color: AppColors.coral.withValues(alpha: 0.6)),
        const SizedBox(height: 24),
        Text('Room Created!', style: AppTypography.display(color: AppColors.ink)),
        const SizedBox(height: 8),
        Text('Share this code with your friend', style: AppTypography.body(color: AppColors.ink.withValues(alpha: 0.5))),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.stone,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.coral.withValues(alpha: 0.3), width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _createdCode!,
                style: AppTypography.timer(color: AppColors.coral).copyWith(letterSpacing: 4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _createdCode!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copied!'), duration: Duration(seconds: 2)),
                  );
                },
                icon: const Icon(Icons.copy_rounded, color: AppColors.coral),
              ),
              IconButton(
                onPressed: () {
                  Share.share(
                    'Join me for a trivia duel! 🎮\n\nEnter this room code in the Duel app:\n\n${_createdCode!}\n\nOpen Duel → Play with Friends → Join Room',
                    subject: 'Duel Room Invite',
                  );
                },
                icon: const Icon(Icons.share_rounded, color: AppColors.teal),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text('Waiting for opponent to join...', style: AppTypography.body(color: AppColors.ink.withValues(alpha: 0.4))),
        const SizedBox(height: 12),
        // Animated waiting indicator
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.coral.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 48),
        SecondaryButton(
          label: 'Cancel',
          onPressed: () {
            _matchSub?.cancel();
            // Delete the waiting room
            if (_createdMatchId != null) {
              FirebaseFirestore.instance
                  .collection('matches')
                  .doc(_createdMatchId)
                  .delete();
            }
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  IconData _categoryIcon(int id) {
    switch (id) {
      case 9: return Icons.quiz_rounded;
      case 10: case 11: case 12: case 13: case 14: case 15: case 16: case 29: case 31: case 32:
        return Icons.movie_rounded;
      case 17: case 18: case 19: case 27: case 30:
        return Icons.science_rounded;
      case 20: return Icons.auto_stories_rounded;
      case 21: return Icons.sports_soccer_rounded;
      case 22: return Icons.public_rounded;
      case 23: return Icons.history_edu_rounded;
      case 24: return Icons.account_balance_rounded;
      case 25: return Icons.palette_rounded;
      case 26: return Icons.star_rounded;
      case 28: return Icons.directions_car_rounded;
      default: return Icons.help_outline_rounded;
    }
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTile({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.coral.withValues(alpha: 0.12) : AppColors.stone,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.coral : Colors.transparent, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? AppColors.coral : AppColors.ink.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, style: AppTypography.caption(color: isSelected ? AppColors.coral : AppColors.ink),
                maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyOption {
  final String label;
  final int? value;
  final IconData icon;
  const _DifficultyOption({required this.label, required this.value, required this.icon});
}
