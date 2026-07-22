# Firebase Analytics setup

The app ships with placeholder Firebase config so it builds without your project.
Replace it before release:

1. Create a Firebase project at https://console.firebase.google.com
2. Add an Android app with package `com.example.shikaku_game` (or your final applicationId)
3. Download `google-services.json` into `android/app/`
4. Run `flutterfire configure` to regenerate `lib/firebase_options.dart`
5. Enable **Analytics** in the Firebase console

## Metabase dashboards

1. Link Firebase to **BigQuery** (Analytics → BigQuery linking)
2. Connect Metabase to the BigQuery export dataset
3. Build funnels from events such as `game_started`, `puzzle_completed`, `purchase_completed`
