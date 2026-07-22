import 'package:flutter/material.dart';

import '../../models/store_product.dart';
import '../../services/analytics_service.dart';
import '../../services/ads_service.dart';
import '../../services/purchase_service.dart';
import '../../state/game_controller.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_theme.dart';
import 'store_sheet.dart';

enum PowerUpOfferType { hint, wand }

/// Conversion sheet when hint or wand charges are depleted.
class PowerUpOfferSheet extends StatelessWidget {
  final PowerUpOfferType type;
  final GameController game;
  final SettingsController settings;
  final AdsService ads;
  final PurchaseService purchases;
  final AnalyticsService analytics;

  const PowerUpOfferSheet({
    super.key,
    required this.type,
    required this.game,
    required this.settings,
    required this.ads,
    required this.purchases,
    required this.analytics,
  });

  static Future<void> show(
    BuildContext context, {
    required PowerUpOfferType type,
    required GameController game,
    required SettingsController settings,
    required AdsService ads,
    required PurchaseService purchases,
    required AnalyticsService analytics,
  }) {
    final rewardAmount = type == PowerUpOfferType.hint ? 2 : 1;
    analytics.logRewardedAdOffered(
      type: type.name,
      rewardAmount: rewardAmount,
    );
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PowerUpOfferSheet(
        type: type,
        game: game,
        settings: settings,
        ads: ads,
        purchases: purchases,
        analytics: analytics,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isHint = type == PowerUpOfferType.hint;
    final title = isHint ? 'Out of hint charges' : 'Out of wand charges';
    final packSku =
        isHint ? StoreSkus.hintsPackSmall : StoreSkus.wandsPackSmall;
    final packLabel = isHint ? 'Buy 10 hints' : 'Buy 3 wands';
    final packPrice = purchases.priceFor(packSku) ?? (isHint ? '\$0.99' : '\$0.99');
    final adReward = isHint ? 2 : 1;

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTheme.title(colors)),
          const SizedBox(height: 8),
          Text(
            'Watch a short video or buy a bundle to keep going.',
            style: TextStyle(color: colors.subtleText, height: 1.4),
          ),
          const SizedBox(height: 20),
          if (ads.isRewardedReady)
            FilledButton(
              onPressed: () => _watchAd(context),
              style: FilledButton.styleFrom(
                backgroundColor: colors.cell,
                foregroundColor: colors.headerText,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text('Watch ad — +$adReward ${isHint ? 'hints' : 'wand'}'),
            ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: purchases.isAvailable
                ? () => _buyPack(context, packSku, packPrice)
                : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.headerText,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text('$packLabel — $packPrice'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              StoreSheet.show(
                context,
                settings: settings,
                purchases: purchases,
                analytics: analytics,
                source: isHint ? 'hint_offer' : 'wand_offer',
              );
            },
            child: Text('View all bundles',
                style: TextStyle(color: colors.accent)),
          ),
          TextButton(
            onPressed: () {
              analytics.logRewardedAdDismissed(type.name);
              Navigator.of(context).pop();
            },
            child:
                Text('Not now', style: TextStyle(color: colors.subtleText)),
          ),
        ],
      ),
    );
  }

  Future<void> _watchAd(BuildContext context) async {
    final rewardAmount = type == PowerUpOfferType.hint ? 2 : 1;
    final earned = await ads.showRewardedAd();
    if (!context.mounted) return;
    if (earned) {
      if (type == PowerUpOfferType.hint) {
        game.addHintCharges(rewardAmount);
      } else {
        game.addWandCharges(rewardAmount);
      }
      await analytics.logRewardedAdCompleted(
        type: type.name,
        rewardAmount: rewardAmount,
      );
      Navigator.of(context).pop();
    } else {
      await analytics.logRewardedAdDismissed(type.name);
    }
  }

  Future<void> _buyPack(
    BuildContext context,
    String sku,
    String price,
  ) async {
    await analytics.logPurchaseStarted(sku: sku, price: price);
    final started = await purchases.buy(sku);
    if (!started && context.mounted) {
      await analytics.logPurchaseFailed(
        sku: sku,
        errorCode: purchases.lastError,
      );
    }
  }
}
