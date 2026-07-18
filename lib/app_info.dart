/// App release metadata. Keep in sync with [pubspec.yaml] `version:` when tagging builds.
abstract final class AppInfo {
  static const version = '1.0.1';
  static const build = 2;
  /// Short label for which feature branch or release track produced this build.
  static const buildLabel = 'difficulty-system-v2';

  static String get display => 'v$version ($build) · $buildLabel';
}
