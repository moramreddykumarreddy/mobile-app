import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';

class PatientQrScannerScreen extends StatefulWidget {
  const PatientQrScannerScreen({super.key});

  /// Convenient helper to open the QR scanner and return the scanned MRN
  static Future<String?> scan(BuildContext context) async {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const PatientQrScannerScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  /// Parses raw QR scan content to extract MRN number
  static String extractMrnFromRaw(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    // 1. Check if payload is JSON
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final candidate = decoded['mrn'] ??
            decoded['patient_mrn'] ??
            decoded['patientMrn'] ??
            decoded['uhid'] ??
            decoded['patient_id'] ??
            decoded['patientId'] ??
            decoded['id'];
        if (candidate != null && candidate.toString().trim().isNotEmpty) {
          return candidate.toString().trim();
        }
      }
    } catch (_) {
      // Not JSON, continue
    }

    // 2. Check for URL parameters (e.g. https://...?mrn=1000027)
    try {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        if (uri.queryParameters.containsKey('mrn')) {
          final q = uri.queryParameters['mrn']!;
          if (q.trim().isNotEmpty) return q.trim();
        }
        if (uri.queryParameters.containsKey('patient_mrn')) {
          final q = uri.queryParameters['patient_mrn']!;
          if (q.trim().isNotEmpty) return q.trim();
        }
      }
    } catch (_) {}

    // 3. Regex match for "MRN: 1000027", "MRN-1000027", "MRN 1000027"
    final match = RegExp(
      r'(?:mrn|uhid)\s*[:=\-]?\s*([A-Za-z0-9]+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }

    // 4. Default: return plain trimmed string
    return trimmed;
  }

  @override
  State<PatientQrScannerScreen> createState() => _PatientQrScannerScreenState();
}

class _PatientQrScannerScreenState extends State<PatientQrScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _animController;
  bool _isProcessing = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      autoStart: true,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.trim().isEmpty) continue;

      final mrn = PatientQrScannerScreen.extractMrnFromRaw(raw);
      if (mrn.isNotEmpty) {
        setState(() => _isProcessing = true);
        try {
          await _controller.stop();
        } catch (_) {}

        if (!mounted) return;
        Navigator.of(context).pop(mrn);
        break;
      }
    }
  }

  void _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      setState(() => _isTorchOn = !_isTorchOn);
    } catch (_) {}
  }

  void _switchCamera() async {
    try {
      await _controller.switchCamera();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const scanAreaSize = 260.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Viewfinder
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              fit: BoxFit.cover,
              onDetect: _onDetect,
              errorBuilder: (context, error) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.camera_alt_outlined,
                          color: Colors.white54,
                          size: 56,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Camera Access Required',
                          style: GoogleFonts.notoSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please grant camera permission in your device settings to scan patient QR codes.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSans(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size(120, 42),
                          ),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Translucent Cutout Overlay
          Positioned.fill(
            child: _ScannerOverlay(scanAreaSize: scanAreaSize),
          ),

          // 3. Animated Laser Scanning Line
          Center(
            child: SizedBox(
              width: scanAreaSize - 20,
              height: scanAreaSize - 20,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Align(
                    alignment: Alignment(0, (_animController.value * 2) - 1),
                    child: Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.accent,
                            Colors.white,
                            AppColors.accent,
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 1.5,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 4. Header Bar with Back Button & Instructions
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.black.withOpacity(0.55),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan Patient QR',
                            style: GoogleFonts.notoSans(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Align the patient QR code inside frame',
                            style: GoogleFonts.notoSans(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Bottom Controls (Torch & Camera Switch)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      label: _isTorchOn ? 'Flash On' : 'Flash Off',
                      isActive: _isTorchOn,
                      onTap: _toggleTorch,
                    ),
                    _buildControlButton(
                      icon: Icons.flip_camera_ios_rounded,
                      label: 'Flip',
                      isActive: false,
                      onTap: _switchCamera,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 6. Processing Indicator
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.65),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.accent),
                      const SizedBox(height: 16),
                      Text(
                        'Patient QR Detected!',
                        style: GoogleFonts.notoSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isActive ? AppColors.accent : Colors.black.withOpacity(0.55),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppColors.accent : Colors.white24,
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : Colors.white70,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.notoSans(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter that creates the darkened cutout box and cyan corner brackets
class _ScannerOverlay extends StatelessWidget {
  final double scanAreaSize;

  const _ScannerOverlay({required this.scanAreaSize});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScannerOverlayPainter(scanAreaSize: scanAreaSize),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  final double scanAreaSize;

  _ScannerOverlayPainter({required this.scanAreaSize});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: scanAreaSize,
      height: scanAreaSize,
    );

    // 1. Draw darkened semi-transparent background around the square cutout
    final backgroundPaint = Paint()..color = Colors.black.withOpacity(0.65);
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(backgroundPath, backgroundPaint);

    // 2. Draw Corner Brackets in Accent color
    final cornerPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const cornerLength = 26.0;
    final r = rect.left;
    final t = rect.top;
    final b = rect.bottom;
    final right = rect.right;

    // Top-Left
    canvas.drawLine(Offset(r, t + cornerLength), Offset(r, t + 12), cornerPaint);
    canvas.drawArc(
      Rect.fromLTWH(r, t, 24, 24),
      3.14159,
      1.5708,
      false,
      cornerPaint,
    );
    canvas.drawLine(Offset(r + 12, t), Offset(r + cornerLength, t), cornerPaint);

    // Top-Right
    canvas.drawLine(Offset(right - cornerLength, t), Offset(right - 12, t), cornerPaint);
    canvas.drawArc(
      Rect.fromLTWH(right - 24, t, 24, 24),
      -1.5708,
      1.5708,
      false,
      cornerPaint,
    );
    canvas.drawLine(Offset(right, t + 12), Offset(right, t + cornerLength), cornerPaint);

    // Bottom-Left
    canvas.drawLine(Offset(r, b - cornerLength), Offset(r, b - 12), cornerPaint);
    canvas.drawArc(
      Rect.fromLTWH(r, b - 24, 24, 24),
      1.5708,
      1.5708,
      false,
      cornerPaint,
    );
    canvas.drawLine(Offset(r + 12, b), Offset(r + cornerLength, b), cornerPaint);

    // Bottom-Right
    canvas.drawLine(Offset(right - cornerLength, b), Offset(right - 12, b), cornerPaint);
    canvas.drawArc(
      Rect.fromLTWH(right - 24, b - 24, 24, 24),
      0,
      1.5708,
      false,
      cornerPaint,
    );
    canvas.drawLine(Offset(right, b - 12), Offset(right, b - cornerLength), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) =>
      oldDelegate.scanAreaSize != scanAreaSize;
}
