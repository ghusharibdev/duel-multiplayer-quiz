import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/game_provider.dart';
import '../services/open_trivia_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/primary_button.dart';

import 'matchmaking_screen.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key});

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  int? _selectedCategoryId;
  String _selectedCategoryName = 'Any Category';
  int? _selectedDifficulty;

  static const List<_DifficultyOption> _difficulties = [
    _DifficultyOption(label: 'Any', value: null, icon: Icons.all_inclusive_rounded),
    _DifficultyOption(label: 'Easy', value: 1, icon: Icons.sentiment_satisfied_rounded),
    _DifficultyOption(label: 'Medium', value: 2, icon: Icons.sentiment_neutral_rounded),
    _DifficultyOption(label: 'Hard', value: 3, icon: Icons.sentiment_dissatisfied_rounded),
  ];

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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose Category',
                style: AppTypography.display(color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick a topic or leave it random',
                style: AppTypography.body(
                  color: AppColors.ink.withValues(alpha: 0.5),
                ),
              ),

              const SizedBox(height: 24),

              // Difficulty chips
              Text(
                'Difficulty',
                style: AppTypography.h1(color: AppColors.ink),
              ),
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
                          border: isSelected
                              ? null
                              : Border.all(
                                  color: AppColors.ink.withValues(alpha: 0.1),
                                ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              d.icon,
                              size: 16,
                              color: isSelected ? AppColors.cream : AppColors.ink,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              d.label,
                              style: AppTypography.body(
                                color: isSelected ? AppColors.cream : AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Categories
              Text(
                'Topic',
                style: AppTypography.h1(color: AppColors.ink),
              ),
              const SizedBox(height: 12),

              // Use Wrap so all 25 categories are visible
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CategoryTile(
                    label: 'Any',
                    icon: Icons.shuffle_rounded,
                    isSelected: _selectedCategoryId == null,
                    onTap: () => setState(() {
                      _selectedCategoryId = null;
                      _selectedCategoryName = 'Any Category';
                    }),
                  ),
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

              const SizedBox(height: 12),                  // Start button
                  PrimaryButton(
                    label: 'Find Match',
                    onPressed: () {
                      // Save preferences
                      ref.read(matchPreferencesProvider.notifier).update(
                        categoryId: _selectedCategoryId,
                        difficulty: _selectedDifficulty,
                        categoryName: _selectedCategoryName,
                      );

                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MatchmakingScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(int id) {
    switch (id) {
      case 9:
        return Icons.quiz_rounded;
      case 10:
      case 11:
      case 12:
      case 13:
      case 14:
      case 15:
      case 16:
      case 29:
      case 31:
      case 32:
        return Icons.movie_rounded;
      case 17:
      case 18:
      case 19:
      case 27:
      case 30:
        return Icons.science_rounded;
      case 20:
        return Icons.auto_stories_rounded;
      case 21:
        return Icons.sports_soccer_rounded;
      case 22:
        return Icons.public_rounded;
      case 23:
        return Icons.history_edu_rounded;
      case 24:
        return Icons.account_balance_rounded;
      case 25:
        return Icons.palette_rounded;
      case 26:
        return Icons.star_rounded;
      case 28:
        return Icons.directions_car_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

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
          border: Border.all(
            color: isSelected ? AppColors.coral : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.coral : AppColors.ink.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: AppTypography.caption(
                  color: isSelected ? AppColors.coral : AppColors.ink,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
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

  const _DifficultyOption({
    required this.label,
    required this.value,
    required this.icon,
  });
}
