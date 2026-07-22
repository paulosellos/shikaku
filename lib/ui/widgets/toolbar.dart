import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The bottom action bar: eraser, undo, wand, and hint (with charge badges).
class GameToolbar extends StatelessWidget {
  final bool eraseActive;
  final bool canUndo;
  final int hintsAvailable;
  final int wandsAvailable;
  final bool wandOfferAvailable;
  final bool hintOfferAvailable;
  final VoidCallback onEraseToggle;
  final VoidCallback onUndo;
  final VoidCallback onWand;
  final VoidCallback onHint;

  const GameToolbar({
    super.key,
    required this.eraseActive,
    required this.canUndo,
    required this.wandsAvailable,
    required this.hintsAvailable,
    this.wandOfferAvailable = false,
    this.hintOfferAvailable = false,
    required this.onEraseToggle,
    required this.onUndo,
    required this.onWand,
    required this.onHint,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ToolButton(
          icon: Icons.cleaning_services_outlined,
          colors: colors,
          active: eraseActive,
          onTap: onEraseToggle,
        ),
        _ToolButton(
          icon: Icons.undo_rounded,
          colors: colors,
          enabled: canUndo,
          onTap: onUndo,
        ),
        _ToolButton(
          icon: Icons.auto_fix_high_outlined,
          colors: colors,
          enabled: wandsAvailable > 0 || wandOfferAvailable,
          badge: wandsAvailable > 0 ? wandsAvailable : null,
          rewardOffer: wandsAvailable == 0 && wandOfferAvailable,
          onTap: onWand,
        ),
        _ToolButton(
          icon: Icons.lightbulb_outline_rounded,
          colors: colors,
          enabled: hintsAvailable > 0 || hintOfferAvailable,
          badge: hintsAvailable > 0 ? hintsAvailable : null,
          rewardOffer: hintsAvailable == 0 && hintOfferAvailable,
          onTap: onHint,
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final AppColors colors;
  final bool active;
  final bool enabled;
  final int? badge;
  final bool rewardOffer;
  final VoidCallback onTap;

  const _ToolButton({
    required this.icon,
    required this.colors,
    required this.onTap,
    this.active = false,
    this.enabled = true,
    this.badge,
    this.rewardOffer = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = enabled
        ? (active ? colors.accent : colors.toolbarIcon)
        : colors.subtleText.withValues(alpha: 0.4);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            width: 68,
            height: 62,
            decoration: BoxDecoration(
              color: colors.toolbar,
              borderRadius: BorderRadius.circular(16),
              border: active
                  ? Border.all(color: colors.accent, width: 2)
                  : Border.all(color: Colors.black.withValues(alpha: 0.05)),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
        ),
        if (badge != null)
          Positioned(
            top: -8,
            right: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: colors.badge,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: colors.subtleText.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '$badge',
                style: TextStyle(
                  fontFamily: AppTheme.mono,
                  fontSize: 12,
                  color: colors.badgeText,
                ),
              ),
            ),
          ),
        if (rewardOffer)
          Positioned(
            top: -8,
            right: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: colors.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}
