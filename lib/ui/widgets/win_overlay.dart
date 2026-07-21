import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'mascot.dart';
import 'win_screens/win_screen_variant.dart';

/// Celebratory overlay shown when a puzzle is solved.
class WinOverlay extends StatefulWidget {
  final int solvedLevel;
  final Duration elapsed;
  final WinScreenVariant variant;
  final Future<void> Function() onContinue;

  const WinOverlay({
    super.key,
    required this.solvedLevel,
    required this.elapsed,
    required this.variant,
    required this.onContinue,
  });

  @override
  State<WinOverlay> createState() => _WinOverlayState();
}

class _WinOverlayState extends State<WinOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final copy = widget.variant.copy;
    final headlineColor = widget.variant.headlineColor(colors);
    final nextLevel = widget.solvedLevel + 1;

    return Material(
      color: colors.background.withValues(alpha: 0.96),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Center(
            child: FadeTransition(
              opacity: _anim,
              child: ScaleTransition(
                scale: CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Mascot(size: 150, variant: copy.mascotVariant),
                    const SizedBox(height: 24),
                    Text(
                      copy.headline,
                      style: TextStyle(
                        fontFamily: AppTheme.serif,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w700,
                        fontSize: 40,
                        color: headlineColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      copy.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.serif,
                        fontSize: 18,
                        color: colors.headerText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Completed in ${AppTheme.formatElapsed(widget.elapsed)}',
                      style: AppTheme.monoLabel(colors),
                    ),
                    const SizedBox(height: 36),
                    Text(
                      'Next up: Level $nextLevel',
                      style: AppTheme.monoLabel(colors),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.cell,
                          foregroundColor: colors.headerText,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: widget.onContinue,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Continue',
                                style: AppTheme.monoLabel(colors)
                                    .copyWith(fontSize: 17)),
                            const SizedBox(width: 8),
                            const Icon(Icons.play_arrow_rounded),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
