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
        final removeAdsProduct = purchases.productFor(StoreSkus.removeAds);
        final price = removeAdsProduct?.price ?? '\$4.99';

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
              if (settings.isAdFree)
                _card(
                  colors,
                  child: Row(
                    children: [
                      Icon(Icons.verified_outlined, color: colors.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'You have the ad-free version. Thanks for your support!',
                          style: TextStyle(color: colors.headerText),
                        ),
                      ),
                    ],
                  ),
                )
              else
                _productTile(
                  context,
                  colors: colors,
                  title: 'Remove ads',
                  subtitle: 'No more interstitials between puzzles',
                  price: price,
                  onBuy: () => _buy(context, StoreSkus.removeAds, price),
                ),
              const SizedBox(height: 12),
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
