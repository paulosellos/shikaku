# In-app purchases setup

Create these products in Google Play Console (Monetize → Products):

| Product ID | Type | Suggested price |
|---|---|---|
| `remove_ads` | One-time (non-consumable) | $4.99 |
| `hints_pack_small` | Consumable | $0.99 |
| `wands_pack_small` | Consumable | $0.99 |
| `combo_pack` | Consumable | $1.99 |
| `mega_pack` | Consumable | $3.99 |

## Testing

1. Upload a signed build to an **internal testing** track
2. Add license testers in Play Console
3. Install from Play Store (not sideload) for billing to work
4. Use **Restore purchases** in Settings → Store after buying remove ads

SKU IDs must match [`lib/models/store_product.dart`](../lib/models/store_product.dart).
