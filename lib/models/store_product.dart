/// Google Play product IDs. Create matching products in Play Console.
abstract final class StoreSkus {
  static const removeAds = 'remove_ads';
  static const hintsPackSmall = 'hints_pack_small';
  static const wandsPackSmall = 'wands_pack_small';
  static const comboPack = 'combo_pack';
  static const megaPack = 'mega_pack';

  static const nonConsumables = [removeAds];
  static const consumables = [
    hintsPackSmall,
    wandsPackSmall,
    comboPack,
    megaPack,
  ];
  static const all = [...nonConsumables, ...consumables];
}

/// Grants for consumable bundles (used in phase 3 wallet).
class BundleGrant {
  final int hints;
  final int wands;

  const BundleGrant({this.hints = 0, this.wands = 0});

  static const Map<String, BundleGrant> bySku = {
    StoreSkus.hintsPackSmall: BundleGrant(hints: 10),
    StoreSkus.wandsPackSmall: BundleGrant(wands: 3),
    StoreSkus.comboPack: BundleGrant(hints: 10, wands: 3),
    StoreSkus.megaPack: BundleGrant(hints: 25, wands: 8),
  };
}
