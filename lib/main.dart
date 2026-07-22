import 'package:flutter/material.dart';

import 'models/store_product.dart';
import 'services/ads_service.dart';
import 'services/analytics_service.dart';
import 'services/purchase_service.dart';
import 'state/app_scope.dart';
import 'state/game_controller.dart';
import 'state/settings_controller.dart';
import 'state/wallet_controller.dart';
import 'theme/app_theme.dart';
import 'ui/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsController();
  await settings.load();
  final wallet = WalletController();
  await wallet.load();
  final analytics = AnalyticsService();
  await analytics.initialize();
  await analytics.logAppOpen();
  await analytics.setAdFree(settings.isAdFree);
  final ads = AdsService();
  await ads.initialize();
  final purchases = PurchaseService();
  final game = GameController(
    settings.levelFor(settings.lastDifficulty),
    difficulty: settings.lastDifficulty,
  )
    ..hapticsEnabled = settings.haptics
    ..wallet = wallet;
  await purchases.initialize(
    onRemoveAdsPurchased: () async {
      settings.setAdFree(true);
      await analytics.setAdFree(true);
      await analytics.logPurchaseCompleted(
        sku: StoreSkus.removeAds,
        price: purchases.priceFor(StoreSkus.removeAds),
      );
    },
    onConsumablePurchased: (sku) async {
      final grant = BundleGrant.bySku[sku];
      if (grant == null) return;
      if (grant.hints > 0) wallet.addHints(grant.hints);
      if (grant.wands > 0) wallet.addWands(grant.wands);
      await analytics.logPurchaseCompleted(
        sku: sku,
        price: purchases.priceFor(sku),
      );
    },
  );
  runApp(ShikakuApp(
    settings: settings,
    wallet: wallet,
    game: game,
    ads: ads,
    analytics: analytics,
    purchases: purchases,
  ));
}

class ShikakuApp extends StatelessWidget {
  final SettingsController settings;
  final WalletController wallet;
  final GameController game;
  final AdsService ads;
  final AnalyticsService analytics;
  final PurchaseService purchases;

  const ShikakuApp({
    super.key,
    required this.settings,
    required this.wallet,
    required this.game,
    required this.ads,
    required this.analytics,
    required this.purchases,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return AppScope(
          settings: settings,
          wallet: wallet,
          game: game,
          ads: ads,
          analytics: analytics,
          purchases: purchases,
          child: MaterialApp(
            title: 'Shikaku',
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: AppTheme.build(Brightness.light),
            darkTheme: AppTheme.build(Brightness.dark),
            home: const SplashScreen(),
          ),
        );
      },
    );
  }
}
