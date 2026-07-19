import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Which celebratory win screen to show after a solve.
enum WinScreenVariant {
  flawless,
  speed,
  steady,
  closeCall,
}

/// Headline, subtitle, and visual tweaks for a win variant.
@immutable
class WinScreenCopy {
  final String headline;
  final String subtitle;
  final int mascotVariant;

  const WinScreenCopy({
    required this.headline,
    required this.subtitle,
    required this.mascotVariant,
  });
}

extension WinScreenVariantCopy on WinScreenVariant {
  WinScreenCopy get copy => switch (this) {
        WinScreenVariant.flawless => const WinScreenCopy(
            headline: 'Flawless!',
            subtitle: 'You trusted your logic and it paid off perfectly.',
            mascotVariant: 0,
          ),
        WinScreenVariant.speed => const WinScreenCopy(
            headline: 'Lightning fast!',
            subtitle: 'Quick thinking and clean lines — impressive pace.',
            mascotVariant: 1,
          ),
        WinScreenVariant.steady => const WinScreenCopy(
            headline: 'Sharp thinking!',
            subtitle: 'A little guidance, but the finish was all you.',
            mascotVariant: 2,
          ),
        WinScreenVariant.closeCall => const WinScreenCopy(
            headline: 'You made it!',
            subtitle: 'Tough one — you stuck with it and got there.',
            mascotVariant: 3,
          ),
      };

  /// Accent tint for the headline, rotated per variant.
  Color headlineColor(AppColors colors) => switch (this) {
        WinScreenVariant.flawless => colors.accent,
        WinScreenVariant.speed => const Color(0xFFE8B84A),
        WinScreenVariant.steady => const Color(0xFF6BA3D6),
        WinScreenVariant.closeCall => const Color(0xFF9B8FD4),
      };
}
