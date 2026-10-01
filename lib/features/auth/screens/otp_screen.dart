// lib/features/auth/screens/otp_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/auth_api_service.dart';
import '../../../core/services/session_menu_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../camps/screens/camps_screen.dart';
import '../../camps/screens/live_camp_screen.dart';

class OtpScreen extends StatefulWidget {
  final String username;
  final String password;
  final String? maskedEmail;

  const OtpScreen({
    super.key,
    required this.username,
    required this.password,
    this.maskedEmail,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const int _otpLength = 6;
  static const int _initialTimerSeconds = 60;

  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  final AuthApiService _authService = AuthApiService();

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  int _timerSeconds = _initialTimerSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    setState(() => _timerSeconds = _initialTimerSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final fn in _focusNodes) {
      fn.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text.trim()).join();

  void _onDigitChanged(int index, String value) {
    setState(() => _errorMessage = null);

    if (value.length > 1) {
      // Handled paste event or multiple characters
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < _otpLength && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      final nextIndex = digits.length < _otpLength ? digits.length : _otpLength - 1;
      _focusNodes[nextIndex].requestFocus();
      if (digits.length >= _otpLength) {
        _handleVerify();
      }
      return;
    }

    if (value.isNotEmpty) {
      if (index < _otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_otpCode.length == _otpLength) {
          _handleVerify();
        }
      }
    }
  }

  void _onKeyDown(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _focusNodes[index - 1].requestFocus();
        _controllers[index - 1].clear();
      }
    }
  }

  Future<void> _handleVerify() async {
    final otp = _otpCode;
    if (otp.length < _otpLength) {
      setState(() {
        _errorMessage = 'Please enter all 6 digits of the OTP.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final result = await _authService.verifyLoginOtp(
      username: widget.username,
      password: widget.password,
      otp: otp,
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (result.success) {
      final uid = result.data != null
          ? SessionMenuService.pickUserId(result.data!)
          : null;
      SessionMenuService().setUser(
        username: widget.username,
        userId: uid,
      );

      // Fetch dynamic menus immediately
      final menus = await SessionMenuService().loadMenus();
      final dashMenu = SessionMenuService().dashboardMenu;
      final firstMenu = menus.isNotEmpty ? menus.first : null;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Authentication successful! Welcome to Staff Portal.',
                  style: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Open Dashboard module menu first if present, otherwise fallback to firstMenu (e.g. Camps)
      Widget initialScreen;
      if (dashMenu != null) {
        initialScreen = LiveCampScreen(
          menuId: dashMenu.menuId,
          moduleId: dashMenu.moduleId,
          actionCode: 'VIEW',
        );
      } else {
        initialScreen = CampsScreen(
          menuId: firstMenu?.menuId ?? 214,
          moduleId: firstMenu?.moduleId ?? 24,
          actionCode: 'VIEW',
        );
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => initialScreen),
        (route) => false,
      );
    } else {
      // Verification failed -> show error and clear OTP inputs
      setState(() {
        _errorMessage = result.message;
      });

      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result.message,
                  style: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleResendOtp() async {
    if (_timerSeconds > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    final result = await _authService.resendLoginOtp(
      username: widget.username,
      password: widget.password,
    );

    if (!mounted) return;
    setState(() => _isResending = false);

    if (result.success) {
      _startTimer();
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.mark_email_read_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'A new OTP code has been sent successfully.',
                  style: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _errorMessage = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayDestination = widget.maskedEmail?.isNotEmpty == true
        ? widget.maskedEmail!
        : widget.username;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // Background Gradient & Abstract Decorative Circles
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFE2E8F0), Color(0xFFF8FAFC)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
            ),
          ),
          Positioned(
            top: -120,
            right: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -180,
            left: -120,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0D9488).withOpacity(0.06),
              ),
            ),
          ),

          // Blur effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: const SizedBox(),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top App Bar with Back Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.arrow_back_rounded,
                            color: Color(0xFF1E293B),
                            size: 20,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Brand Logo Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/APGOV.png',
                                height: 50,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.local_hospital_rounded,
                                      color: AppColors.primary,
                                      size: 28,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: GoogleFonts.notoSans(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                      children: const [
                                        TextSpan(
                                          text: 'AP ',
                                          style: TextStyle(color: Color(0xFFEF4444)),
                                        ),
                                        TextSpan(
                                          text: 'VISION CARE',
                                          style: TextStyle(color: Color(0xFF1E293B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'Two-Factor Verification',
                                    style: GoogleFonts.notoSans(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2),

                          const SizedBox(height: 28),

                          // Main OTP Verification Card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1E293B).withOpacity(0.06),
                                  blurRadius: 32,
                                  offset: const Offset(0, 16),
                                ),
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.8),
                                  blurRadius: 0,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Key / Shield Icon
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.mark_email_unread_rounded,
                                    color: AppColors.primary,
                                    size: 32,
                                  ),
                                ).animate().scale(delay: 200.ms, duration: 400.ms),

                                const SizedBox(height: 18),

                                Text(
                                  'Enter Verification Code',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.notoSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ).animate().fadeIn(delay: 250.ms),

                                const SizedBox(height: 8),

                                Text(
                                  'A 6-digit one-time password (OTP) was sent to',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.notoSans(
                                    fontSize: 13,
                                    color: const Color(0xFF64748B),
                                  ),
                                ).animate().fadeIn(delay: 300.ms),

                                const SizedBox(height: 4),

                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    displayDestination,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.notoSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ).animate().fadeIn(delay: 350.ms),

                                const SizedBox(height: 28),

                                // Error Banner
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.errorLight,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline_rounded,
                                          color: AppColors.error,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: GoogleFonts.notoSans(
                                              fontSize: 12,
                                              color: const Color(0xFF991B1B),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ).animate().shake(duration: 400.ms),
                                  const SizedBox(height: 20),
                                ],

                                // 6 OTP Digit Input Boxes
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: List.generate(_otpLength, (index) {
                                    return SizedBox(
                                      width: 44,
                                      height: 54,
                                      child: RawKeyboardListener(
                                        focusNode: FocusNode(),
                                        onKey: (event) => _onKeyDown(index, event),
                                        child: TextFormField(
                                          controller: _controllers[index],
                                          focusNode: _focusNodes[index],
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          maxLength: 1,
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                          ],
                                          style: GoogleFonts.notoSans(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF004990),
                                          ),
                                          decoration: InputDecoration(
                                            counterText: '',
                                            filled: true,
                                            fillColor: const Color(0xFFF8FAFC),
                                            contentPadding: EdgeInsets.zero,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: Color(0xFFCBD5E1),
                                                width: 1.5,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: _controllers[index].text.isNotEmpty
                                                    ? AppColors.primary
                                                    : const Color(0xFFE2E8F0),
                                                width: 1.5,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(
                                                color: AppColors.primary,
                                                width: 2.0,
                                              ),
                                            ),
                                          ),
                                          onChanged: (val) => _onDigitChanged(index, val),
                                        ),
                                      ),
                                    );
                                  }),
                                ).animate().fadeIn(delay: 400.ms),

                                const SizedBox(height: 28),

                                // Verify & Sign In Button
                                GestureDetector(
                                  onTap: _isVerifying ? null : _handleVerify,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF004990), Color(0xFF003366)],
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF004990).withOpacity(0.35),
                                          blurRadius: 18,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: _isVerifying
                                        ? const Center(
                                            child: SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2.5,
                                              ),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.verified_user_rounded,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                'Verify & Sign In',
                                                style: GoogleFonts.notoSans(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ).animate().fadeIn(delay: 450.ms),

                                const SizedBox(height: 24),

                                // Resend Timer / Action
                                if (_timerSeconds > 0)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.timer_outlined,
                                        size: 16,
                                        color: Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Resend code in 00:${_timerSeconds.toString().padLeft(2, '0')}',
                                        style: GoogleFonts.notoSans(
                                          fontSize: 13,
                                          color: const Color(0xFF64748B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Didn't receive the code?",
                                        style: GoogleFonts.notoSans(
                                          fontSize: 13,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      _isResending
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors.primary,
                                              ),
                                            )
                                          : TextButton(
                                              onPressed: _handleResendOtp,
                                              style: TextButton.styleFrom(
                                                padding: EdgeInsets.zero,
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                              child: Text(
                                                'Resend OTP',
                                                style: GoogleFonts.notoSans(
                                                  fontSize: 13,
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                    ],
                                  ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                          const SizedBox(height: 24),

                          // Back to Login link
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 16,
                              color: Color(0xFF64748B),
                            ),
                            label: Text(
                              'Back to Login',
                              style: GoogleFonts.notoSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ).animate().fadeIn(delay: 500.ms),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
