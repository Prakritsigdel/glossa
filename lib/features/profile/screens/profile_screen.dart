import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';
import 'package:glossa_app/app/router/app_router.dart';
import 'package:glossa_app/app/theme/glossa_colors.dart';
import 'package:glossa_app/app/theme/glossa_typography.dart';
import 'package:glossa_app/core/constants/spacing.dart';
import 'package:glossa_app/core/widgets/hero_avatar.dart';
import 'package:glossa_app/core/widgets/progress_bar.dart';
import 'package:glossa_app/shared/providers/game_state_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gameStateProvider);
    final user = gs.user;

    final xpProgress = user.xpToNextLevel > 0
        ? (user.xp / user.xpToNextLevel).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: GlossaColors.creamBackground,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.pagePadding,
                  vertical: Spacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hero Profile', style: GlossaTypography.displayMedium),
                    const SizedBox(height: Spacing.lg),

                    // ─── Profile Header Card ──────────────────
                    Container(
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: GlossaColors.white,
                        borderRadius: BorderRadius.circular(Spacing.cardRadius),
                        border: Border.all(
                          color: GlossaColors.blueNavy,
                          width: 2.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: GlossaColors.blueNavy,
                            offset: Offset(0, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              HeroAvatar(
                                heroIndex: user.heroIndex,
                                level: user.level,
                                size: 68,
                                animateIdle: true,
                              ),
                              const SizedBox(width: Spacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.name,
                                      style: GlossaTypography.headlineLarge,
                                    ),
                                    Text(
                                      'Lv ${user.level} ${user.heroClassName}',
                                      style: GlossaTypography.labelMedium
                                          .copyWith(
                                            color: GlossaColors.blueDeep,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: GlossaColors.creamPale,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: GlossaColors.blueNavy,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        'नेपाल भाषा (Newari)',
                                        style: GlossaTypography.labelSmall
                                            .copyWith(
                                              color: GlossaColors.blueNavy,
                                              fontSize: 10,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: GlossaColors.blueNavy,
                                ),
                                onPressed: () => context.push(
                                  '${AppRoutes.characterSelect}?mode=edit',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: Spacing.md),
                          GlossaProgressBar(
                            progress: xpProgress,
                            fillColor: GlossaColors.redAction,
                            height: 10,
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${user.xp} / ${user.xpToNextLevel} XP to Level ${user.level + 1}',
                              style: GlossaTypography.bodySmall.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),

                    // ─── 3 Stats Row ─────────────────────────
                    Row(
                      children: [
                        _buildStatBox(
                          'Words Found',
                          '${user.wordsFound}',
                          Lottie.asset(
                            'assets/animations/Words_Found.json',
                            width: 42,
                            height: 42,
                            repeat: true,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.menu_book_rounded,
                                  size: 36,
                                  color: GlossaColors.blueNavy,
                                ),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        _buildStatBox(
                          'Day Streak',
                          '${user.streak}d',
                          Lottie.asset(
                            'assets/animations/Fire.json',
                            width: 42,
                            height: 42,
                            repeat: true,
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        _buildStatBox(
                          'Lessons',
                          '${user.lessonsCompleted}',
                          Lottie.asset(
                            'assets/animations/Lessons.json',
                            width: 42,
                            height: 42,
                            repeat: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.xl),

                    // ─── Full-body hero preview ────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(Spacing.lg),
                      decoration: BoxDecoration(
                        color: GlossaColors.white,
                        borderRadius: BorderRadius.circular(Spacing.cardRadius),
                        border: Border.all(
                          color: GlossaColors.blueNavy,
                          width: 2.5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: GlossaColors.blueNavy,
                            offset: Offset(0, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Your Hero',
                            style: GlossaTypography.headlineMedium,
                          ),
                          const SizedBox(height: Spacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              HeroAvatarLarge(
                                heroIndex: user.heroIndex,
                                level: user.level,
                                size: 118,
                                animateIdle: true,
                              ),
                              const SizedBox(width: Spacing.md),
                              Expanded(
                                child: Column(
                                  children: [
                                    _buildHeroStat(
                                      'HP',
                                      120,
                                      const Icon(
                                        Icons.favorite_rounded,
                                        size: 16,
                                        color: GlossaColors.redAction,
                                      ),
                                    ),
                                    _buildHeroStat(
                                      'Attack',
                                      24,
                                      const _SwordStatIcon(),
                                    ),
                                    _buildHeroStat(
                                      'Defense',
                                      18,
                                      const Icon(
                                        Icons.shield_rounded,
                                        size: 16,
                                        color: GlossaColors.redAction,
                                      ),
                                    ),
                                    _buildHeroStat(
                                      'Speed',
                                      16,
                                      const Icon(
                                        Icons.directions_run_rounded,
                                        size: 16,
                                        color: GlossaColors.redAction,
                                      ),
                                    ),
                                    _buildHeroStat(
                                      'Magic',
                                      32,
                                      const Icon(
                                        Icons.local_fire_department_rounded,
                                        size: 16,
                                        color: GlossaColors.redAction,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Spacing.xl),

                    // ─── Settings & Navigation Links ──────────
                    Material(
                      color: GlossaColors.white,
                      borderRadius: BorderRadius.circular(Spacing.cardRadius),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            Spacing.cardRadius,
                          ),
                          border: Border.all(
                            color: GlossaColors.blueNavy,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.language_rounded,
                                color: GlossaColors.blueNavy,
                              ),
                              title: Text(
                                'Course: English \u2192 Newari',
                                style: GlossaTypography.labelMedium,
                              ),
                              trailing: const Icon(
                                Icons.lock_rounded,
                                color: GlossaColors.textSubtle,
                                size: 20,
                              ),
                              onTap: null,
                            ),
                            const Divider(height: 1, thickness: 1),
                            ListTile(
                              leading: const Icon(
                                Icons.logout_rounded,
                                color: GlossaColors.redAction,
                              ),
                              title: Text(
                                _isLoggingOut ? 'Logging out...' : 'Log Out',
                                style: GlossaTypography.labelMedium.copyWith(
                                  color: GlossaColors.redAction,
                                ),
                              ),
                              trailing: _isLoggingOut
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: GlossaColors.redAction,
                                      ),
                                    )
                                  : const Icon(Icons.chevron_right_rounded),
                              onTap: _isLoggingOut
                                  ? null
                                  : () async {
                                      setState(() => _isLoggingOut = true);
                                      try {
                                        await ref
                                            .read(gameStateProvider.notifier)
                                            .logOut();
                                        if (context.mounted) {
                                          context.go(AppRoutes.welcome);
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isLoggingOut = false);
                                        }
                                      }
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Spacing.xxl),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Widget icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: Spacing.md,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: GlossaColors.white,
          borderRadius: BorderRadius.circular(Spacing.cardRadius),
          border: Border.all(color: GlossaColors.blueNavy, width: 2),
        ),
        child: Column(
          children: [
            SizedBox(height: 42, child: Center(child: icon)),
            const SizedBox(height: 4),
            Text(
              value,
              style: GlossaTypography.headlineMedium.copyWith(
                color: GlossaColors.blueNavy,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: GlossaTypography.bodySmall.copyWith(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStat(String label, int value, Widget icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 18, height: 18, child: Center(child: icon)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: GlossaTypography.bodySmall.copyWith(
                color: GlossaColors.blueNavy,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$value',
            style: GlossaTypography.labelMedium.copyWith(
              color: GlossaColors.blueNavy,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwordStatIcon extends StatelessWidget {
  const _SwordStatIcon();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 16,
    height: 16,
    child: CustomPaint(painter: _SwordStatPainter()),
  );
}

class _SwordStatPainter extends CustomPainter {
  const _SwordStatPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = GlossaColors.redAction
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = GlossaColors.redAction
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final blade = Path()
      ..moveTo(size.width * 0.88, size.height * 0.08)
      ..lineTo(size.width * 0.58, size.height * 0.67)
      ..lineTo(size.width * 0.34, size.height * 0.43)
      ..close();
    canvas.drawPath(blade, fillPaint);
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.45),
      Offset(size.width * 0.65, size.height * 0.8),
      linePaint..strokeWidth = 2.2,
    );
    canvas.drawLine(
      Offset(size.width * 0.16, size.height * 0.62),
      Offset(size.width * 0.48, size.height * 0.3),
      linePaint..strokeWidth = 2.4,
    );
    canvas.drawLine(
      Offset(size.width * 0.31, size.height * 0.77),
      Offset(size.width * 0.2, size.height * 0.88),
      linePaint..strokeWidth = 2.4,
    );
    canvas.drawCircle(
      Offset(size.width * 0.13, size.height * 0.9),
      size.width * 0.08,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SwordStatPainter oldDelegate) => false;
}
