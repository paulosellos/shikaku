import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'mascot.dart';

/// Celebratory overlay shown when a puzzle is solved. Lets the player pick the
/// next level via a slider and continue.
class WinOverlay extends StatefulWidget {
  final int solvedLevel;
  final ValueChanged<int> onContinue;

  const WinOverlay({
    super.key,
    required this.solvedLevel,
    required this.onContinue,
  });

  @override
  State<WinOverlay> createState() => _WinOverlayState();
}

class _WinOverlayState extends State<WinOverlay>
    with SingleTickerProviderStateMixin {
  late int _nextLevel = widget.solvedLevel + 1;
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
    final maxLevel = (widget.solvedLevel + 30).toDouble();
    final minLevel = 1.0;

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
                    const Mascot(size: 150),
                    const SizedBox(height: 24),
                    Text(
                      'Flawless!',
                      style: TextStyle(
                        fontFamily: AppTheme.serif,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w700,
                        fontSize: 40,
                        color: colors.accent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You trusted your logic and it paid off perfectly.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.serif,
                        fontSize: 18,
                        color: colors.headerText,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'New game at level $_nextLevel',
                            style: AppTheme.monoLabel(colors),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _nextLevel = minLevel.toInt() +
                                  (DateTime.now().millisecondsSinceEpoch %
                                      maxLevel.toInt());
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colors.cell,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.casino_outlined,
                                color: colors.headerText),
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: colors.accent,
                        thumbColor: colors.accent,
                        inactiveTrackColor: colors.subtleText.withValues(alpha: 0.3),
                      ),
                      child: Slider(
                        min: minLevel,
                        max: maxLevel,
                        value: _nextLevel.toDouble().clamp(minLevel, maxLevel),
                        onChanged: (v) => setState(() => _nextLevel = v.round()),
                      ),
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
                        onPressed: () => widget.onContinue(_nextLevel),
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
