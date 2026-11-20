import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/widgets/glossa_button.dart';
import 'package:glossa_app/core/widgets/glossa_card.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';
import 'package:glossa_app/shared/mock_data/mock_data.dart';

class CharacterSelectionScreen extends ConsumerStatefulWidget {
  final bool isEditing;

  const CharacterSelectionScreen({super.key, this.isEditing = false});

  @override
  ConsumerState<CharacterSelectionScreen> createState() =>
      _CharacterSelectionScreenState();
}

class _CharacterSelectionScreenState
    extends ConsumerState<CharacterSelectionScreen> {
  late int _selectedHero;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(gameStateProvider).user;
    _selectedHero = user.heroIndex;
    _nameController = TextEditingController(text: user.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (widget.isEditing) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.profile);
      }
    } else {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.signup);
      }
    }
  }

  Future<void> _handleSave() async {
    final chosenName = _nameController.text.trim().isEmpty
        ? 'LeBron'
        : _nameController.text.trim();

    try {
      await ref
          .read(gameStateProvider.notifier)
          .selectHero(_selectedHero, chosenName);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
      return;
    }

    if (!mounted) return;
    if (widget.isEditing) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Hero profile updated!')));
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.profile);
      }
    } else {
      context.go(AppRoutes.languageSelect);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: Spacing.sm),
                // Top bar with Back button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: GlossaColors.blueNavy,
                        size: 28,
                      ),
                      onPressed: _handleBack,
                    ),
                    if (widget.isEditing)
                      TextButton(
                        onPressed: _handleBack,
                        child: Text(
                          'Cancel',
                          style: GlossaTypography.labelMedium.copyWith(
                            color: GlossaColors.textSubtle,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  widget.isEditing
                      ? 'Edit your\nhero'
                      : 'Select your\ncharacter',
                  style: GlossaTypography.displayMedium,
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  widget.isEditing ? 'Customize your hero avatar and title.' : 'Complete lessons to level up. Your hero earns\nnew gear as you grow.',
                  style: GlossaTypography.bodyMedium,
                ),
                const SizedBox(height: Spacing.xxxl),
                // Hero cards
                Row(
                  children: heroChoices.map((hero) {
                    final isSelected = _selectedHero == hero.index;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: hero.index == 0 ? Spacing.md : 0,
                          left: hero.index == 1 ? Spacing.md : 0,
                        ),
                        child: GlossaCard(
                          isSelected: isSelected,
                          onTap: () =>
                              setState(() => _selectedHero = hero.index),
                          padding: const EdgeInsets.all(Spacing.lg),
                          child: Column(
                            children: [
                              HeroAvatarLarge(
                                heroIndex: hero.index,
                                level: 1,
                                size: 100,
                                animateIdle: isSelected,
                              ),
                              const SizedBox(height: Spacing.md),
                              Text(
                                hero.label,
                                style: GlossaTypography.headlineMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: Spacing.xxl),
                Text('Character name', style: GlossaTypography.labelMedium),
                const SizedBox(height: Spacing.sm),
                TextFormField(controller: _nameController),
                const SizedBox(height: Spacing.xl),
                // Class info
                Container(
                  padding: const EdgeInsets.all(Spacing.lg),
                  decoration: BoxDecoration(
                    color: GlossaColors.creamPale,
                    borderRadius: BorderRadius.circular(Spacing.cardRadius),
                    border: Border.all(
                      color: GlossaColors.blueNavy,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: GlossaColors.redAction,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Lv 1',
                          style: GlossaTypography.labelSmall.copyWith(
                            color: GlossaColors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Traveler',
                              style: GlossaTypography.headlineSmall,
                            ),
                            Text(
                              'Gear is granted at Lv 3, 5 and 10.',
                              style: GlossaTypography.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Spacing.xxxl),
                GlossaButton(
                  label: widget.isEditing ? 'Save changes' : 'Confirm',
                  onPressed: _handleSave,
                ),
                const SizedBox(height: Spacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
