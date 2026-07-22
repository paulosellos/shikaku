import 'package:flutter/material.dart';

import '../../state/app_scope.dart';
import '../../theme/app_theme.dart';
import 'home_screen.dart';

/// First screen shown on launch. Fades in a splash image matching the
/// device's resolved theme (dark/light), then hands off to [HomeScreen].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const String _darkImageAssetPath = 'assets/images/splash-dark.png';
  static const String _lightImageAssetPath = 'assets/images/splash-light.png';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), _goHome);
  }

  void _goHome() {
    if (!mounted) return;
    AppScope.of(context).analytics.logSplashCompleted();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final imagePath = colors.isDark
        ? SplashScreen._darkImageAssetPath
        : SplashScreen._lightImageAssetPath;

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: FadeTransition(
          opacity: _controller,
          child: GestureDetector(
            onTap: _goHome,
            child: Image.asset(
              imagePath,
              width: MediaQuery.of(context).size.width,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
