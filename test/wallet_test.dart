import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shikaku_game/state/game_controller.dart';
import 'package:shikaku_game/state/wallet_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('spends per-level hints before wallet hints', () async {
    final wallet = WalletController();
    await wallet.load();
    wallet.addHints(3);

    final game = GameController(1, seed: 42)
      ..hapticsEnabled = false
      ..wallet = wallet;
    game.hintsLeft = 0;

    expect(game.hintsAvailable, 3);
    game.useHint();
    expect(wallet.hints, 2);
    expect(game.hintsAvailable, 2);
  });

  test('spends per-level wands before wallet wands', () async {
    final wallet = WalletController();
    await wallet.load();
    wallet.addWands(2);

    final game = GameController(1, seed: 42)
      ..hapticsEnabled = false
      ..wallet = wallet;
    game.wandsLeft = 0;

    expect(game.wandsAvailable, 2);
    game.useWand();
    expect(wallet.wands, 1);
    expect(game.wandsAvailable, 1);
  });
}
