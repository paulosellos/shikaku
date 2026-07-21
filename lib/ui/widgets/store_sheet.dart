import 'package:flutter/material.dart';

import '../../models/store_product.dart';
import '../../services/analytics_service.dart';
import '../../services/purchase_service.dart';
import '../../state/settings_controller.dart';
import '../../theme/app_theme.dart';

/// In-app store sheet for remove-ads and bundles.
class StoreSheet extends StatelessWidget {
  final SettingsController settings;
  final PurchaseService purchases;
  final AnalyticsService analytics;

  const StoreSheet({
    super.key,
    required this.settings,
    required this.purchases,
    required this.analytics,
  });

  static Future<void> show(
    BuildContext context, {
    required SettingsController settings,
    required PurchaseService purchases,
    required AnalyticsService analytics,
    String source = 'settings',
  }) {
    analytics.logStoreOpened(source);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StoreSheet(
        settings: settings,
        purchases: purchases,
        analytics: analytics,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AnimatedBuilder(
      animation: Listenable.merge([settings, purchases]),
      builder: (context, _) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.close, color: colors.headerText),
                  ),
                  Expanded(
                    child: Center(
                      child: Text('Store', style: AppTheme.title(colors)),
                    ),
                  ),
                  const SizedBox(width: 24),
                ],
              ),
              const SizedBox(height: 20),
              if (!settings.isAdFree) ...[
                _productTile(
                  context,
                  colors: colors,
                  title: 'Remove ads',
                  subtitle: 'No more interstitials between puzzles',
                  price: purchases.priceFor(StoreSkus.removeAds) ?? '\$4.99',
                  onBuy: () => _buy(
                    context,
                    StoreSkus.removeAds,
                    purchases.priceFor(StoreSkus.removeAds) ?? '\$4.99',
                  ),
                ),
                const SizedBox(height: 16),
              ] else
                _card(
                  colors,
                  child: Row(
                    children: [
                      Icon(Icons.verified_outlined, color: colors.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ad-free unlocked — thanks for your support!',
                          style: TextStyle(color: colors.headerText),
                        ),
                      ),
                    ],
                  ),
                ),
              Text('Power-up bundles',
                  style: AppTheme.title(colors).copyWith(fontSize: 18)),
              const SizedBox(height: 10),
              for (final sku in StoreSkus.consumables)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _bundleTile(context, colors, sku),
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _restore(context),
                child: Text('Restore purchases',
                    style: TextStyle(color: colors.subtleText)),
              ),
              if (purchases.lastError != null) ...[
                const SizedBox(height: 8),
                Text(
                  purchases.lastError!,
                  style: TextStyle(color: colors.accent, fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _buy(BuildContext context, String sku, String price) async {
    await analytics.logPurchaseStarted(sku: sku, price: price);
    final started = await purchases.buy(sku);
    if (!started && context.mounted) {
      await analytics.logPurchaseFailed(
        sku: sku,
        errorCode: purchases.lastError,
      );
    }
  }

  Future<void> _restore(BuildContext context) async {
    final before = settings.isAdFree;
    await purchases.restorePurchases();
    if (!context.mounted) return;
    await analytics.logRestorePurchases(
      restoredCount: settings.isAdFree && !before ? 1 : 0,
    );
  }

  Widget _bundleTile(BuildContext context, AppColors colors, String sku) {
    final grant = BundleGrant.bySku[sku]!;
    final title = switch (sku) {
      StoreSkus.hintsPackSmall => '10 hints',
      StoreSkus.wandsPackSmall => '3 wands',
      StoreSkus.comboPack => 'Combo pack',
      StoreSkus.megaPack => 'Mega pack',
      _ => sku,
    };
    final subtitle = switch (sku) {
      StoreSkus.comboPack => '+${grant.hints} hints, +${grant.wands} wands',
      StoreSkus.megaPack => '+${grant.hints} hints, +${grant.wands} wands',
      StoreSkus.hintsPackSmall => 'Saved to your wallet across puzzles',
      StoreSkus.wandsPackSmall => 'Saved to your wallet across puzzles',
      _ => '',
    };
    final price = purchases.priceFor(sku) ?? '—';
    return _productTile(
      context,
      colors: colors,
      title: title,
      subtitle: subtitle,
      price: price,
      onBuy: () => _buy(context, sku, price),
    );
  }

  Widget _productTile(
    BuildContext context, {
    required AppColors colors,
    required String title,
    required String subtitle,
    required String price,
    required VoidCallback onBuy,
  }) {
    return _card(
      colors,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: colors.headerText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(color: colors.subtleText, fontSize: 13)),
              ],
            ),
          ),
          FilledButton(
            onPressed: purchases.isAvailable ? onBuy : null,
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
            ),
            child: Text(price),
          ),
        ],
      ),
    );
  }

  Widget _card(AppColors colors, {required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.cell.withValues(alpha: colors.isDark ? 0.5 : 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: child,
      );
}
