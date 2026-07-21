// Placeholder Firebase options — replace by running:
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// See assets/docs/firebase-setup.md for details.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'placeholder-web-key',
    appId: '1:000000000000:web:placeholder',
    messagingSenderId: '000000000000',
    projectId: 'shikaku-game-placeholder',
    authDomain: 'shikaku-game-placeholder.firebaseapp.com',
    storageBucket: 'shikaku-game-placeholder.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'placeholder-android-key',
    appId: '1:000000000000:android:placeholder',
    messagingSenderId: '000000000000',
    projectId: 'shikaku-game-placeholder',
    storageBucket: 'shikaku-game-placeholder.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'placeholder-ios-key',
    appId: '1:000000000000:ios:placeholder',
    messagingSenderId: '000000000000',
    projectId: 'shikaku-game-placeholder',
    storageBucket: 'shikaku-game-placeholder.appspot.com',
    iosBundleId: 'com.example.shikakuGame',
  );
}
