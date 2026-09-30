// lib/features/splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../auth/screens/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Realistic Eye Checkup Photo Background (matching ApVisionCare.App)
          Image.asset(
            'assets/images/real_eye_checkup.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFFF1F5F9),
            ),
          ).animate().fadeIn(duration: 1000.ms),

          // Gradient overlay to make text readable (exact match)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.7),
                    Colors.white,
                    Colors.white,
                  ],
                  stops: const [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 1000.ms),

          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Spacer(),

                  // Logos Row: APGOV emblem + small_ap_map
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Image.asset(
                          'assets/images/APGOV.png',
                          height: 55,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.local_hospital_rounded,
                            color: AppColors.primary,
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Flexible(
                        child: Image.asset(
                          'assets/images/small_ap_map.png',
                          height: 55,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 200.ms, duration: 600.ms),

                  const SizedBox(height: 16),

                  // App Name (RichText)
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.notoSans(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      children: const [
                        TextSpan(
                          text: 'AP ',
                          style: TextStyle(color: AppColors.error), // brand-red
                        ),
                        TextSpan(
                          text: 'VISION CARE',
                          style: TextStyle(color: AppColors.primary), // brand-blue
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 600.ms)
                      .slideY(begin: 0.3, curve: Curves.easeOut),

                  const SizedBox(height: 8),

                  // Tagline
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Staff Portal',
                        style: GoogleFonts.notoSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        ' • Eye Care for Every Citizen',
                        style: GoogleFonts.notoSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 500.ms, duration: 600.ms),

                  const SizedBox(height: 28),

                  // Government Branding
                  Text(
                    'Govt. of Andhra Pradesh',
                    style: GoogleFonts.notoSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ).animate().fadeIn(delay: 800.ms, duration: 600.ms),

                  const SizedBox(height: 24),

                  // Circular Progress Indicator
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ).animate().fadeIn(delay: 800.ms, duration: 600.ms),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
