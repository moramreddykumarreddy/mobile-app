// lib/features/patient/screens/register_patient_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/mobile_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/staff_app_bar.dart';
import '../../../core/widgets/staff_app_drawer.dart';
import '../../../core/widgets/staff_bottom_nav_bar.dart';
import '../../camps/screens/register_camp_screen.dart';

class RegisterPatientScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final int menuId;
  final int moduleId;
  final String actionCode;

  const RegisterPatientScreen({
    super.key,
    this.onOpenDrawer,
    this.menuId = 180,
    this.moduleId = 29,
    this.actionCode = 'VIEW',
  });

  @override
  State<RegisterPatientScreen> createState() => _RegisterPatientScreenState();
}

class _RegisterPatientScreenState extends State<RegisterPatientScreen> {
  // Mode selection: 'mobile' (default) or 'manual'
  String _registrationMode = 'mobile';

  // ─────────────────────────────────────────────────────────────────────────────
  // 1. MOBILE (ABHA) FLOW STATE
  // ─────────────────────────────────────────────────────────────────────────────
  // Steps: 0 = Enter Mobile, 1 = Select Account & OTP Provider, 2 = Verify OTP, 3 = Success
  int _mobileStep = 0;

  final _mobileNumberController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isSearchingAccounts = false;
  bool _isSendingOtp = false;
  bool _isVerifyingOtp = false;

  String _findTxnId = '';
  List<Map<String, dynamic>> _abhaAccounts = [];
  Map<String, dynamic>? _selectedAccount;
  String _otpProvider = 'aadhaar'; // 'aadhaar' or 'abdm'
  String _otpTxnId = '';
  String _otpMessage = '';
  String _errorBanner = '';
  bool _is409Conflict = false;
  String _profileTokenId = '';
  String _cardBase64 = '';
  bool _isLoadingCard = false;

  // ─────────────────────────────────────────────────────────────────────────────
  // 1B. CREATE ABHA (AADHAAR) STATE
  // ─────────────────────────────────────────────────────────────────────────────
  bool _isCreateAbhaMode = false;
  int _createAbhaStep = 0; // 0 = Aadhaar, 1 = OTP & Mobile, 2 = Address Selection, 3 = Success

  final _createAadhaarController = TextEditingController();
  final _createOtpController = TextEditingController();
  final _createMobileController = TextEditingController();
  final _customAbhaAddressController = TextEditingController();

  bool _isSendingCreateOtp = false;
  bool _isVerifyingCreateOtp = false;
  bool _isSettingAbhaAddress = false;
  List<String> _createAddressSuggestions = [];
  String _selectedAbhaAddress = '';
  bool _useCustomAbhaAddress = false;
  String _createTxnId = '';
  String _createOtpMessage = '';
  Map<String, dynamic>? _createdAbhaData;
  String _searchedMobileNumber = '';
  String _createdMobileNumber = '';

  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. MANUAL REGISTRATION STATE
  // ─────────────────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _manualMobileController = TextEditingController();
  final _idValueController = TextEditingController();
  final _addressController = TextEditingController();
  final _villageController = TextEditingController();
  final _pincodeController = TextEditingController();

  String _gender = 'Male';
  String _district = 'Guntur';
  String _state = 'Andhra Pradesh';
  String _idType = 'AADHAAR';
  bool _isSavingManual = false;
  bool _isLookingUpPincode = false;

  final List<String> _districts = [
    'Anakapalli',
    'Ananthapuramu',
    'Annamayya',
    'Bapatla',
    'Chittoor',
    'Dr. B.R. Ambedkar Konaseema',
    'East Godavari',
    'Eluru',
    'Guntur',
    'Kakinada',
    'Konaseema',
    'Krishna',
    'Kurnool',
    'Nandyal',
    'NTR',
    'Palnadu',
    'Parvathipuram Manyam',
    'Prakasam',
    'Sri Potti Sriramulu Nellore',
    'Sri Sathya Sai',
    'Srikakulam',
    'Tirupati',
    'Visakhapatnam',
    'Vizianagaram',
    'West Godavari',
    'YSR Kadapa',
  ];

  bool get _isMobileActiveInProcess =>
      _isCreateAbhaMode ||
      _isSearchingAccounts ||
      _isSendingOtp ||
      _isVerifyingOtp ||
      _mobileStep > 0;

  bool get _isManualActiveInProcess =>
      _registrationMode == 'manual' &&
      (_isSavingManual ||
          _isLookingUpPincode ||
          _firstNameController.text.trim().isNotEmpty ||
          _lastNameController.text.trim().isNotEmpty ||
          _manualMobileController.text.trim().isNotEmpty ||
          _idValueController.text.trim().isNotEmpty);

  void _resetCreateAbhaFlow() {
    setState(() {
      _registrationMode = 'mobile';
      _isCreateAbhaMode = true;
      _createAbhaStep = 0;
      _isSendingCreateOtp = false;
      _isVerifyingCreateOtp = false;
      _isSettingAbhaAddress = false;
      _createAddressSuggestions = [];
      _selectedAbhaAddress = '';
      _useCustomAbhaAddress = false;
      _customAbhaAddressController.clear();
      _createTxnId = '';
      _createOtpMessage = '';
      _createdAbhaData = null;
      _createdMobileNumber = '';
      _createAadhaarController.clear();
      _createOtpController.clear();
      _createMobileController.clear();
      _errorBanner = '';
    });
  }

  void _resetMobileFlow() {
    setState(() {
      _registrationMode = 'mobile';
      _isCreateAbhaMode = false;
      _createAbhaStep = 0;
      _isSendingCreateOtp = false;
      _isVerifyingCreateOtp = false;
      _isSettingAbhaAddress = false;
      _createAddressSuggestions = [];
      _selectedAbhaAddress = '';
      _useCustomAbhaAddress = false;
      _customAbhaAddressController.clear();
      _createTxnId = '';
      _createOtpMessage = '';
      _createdAbhaData = null;
      _searchedMobileNumber = '';
      _createdMobileNumber = '';
      _createAadhaarController.clear();
      _createOtpController.clear();
      _createMobileController.clear();

      _mobileStep = 0;
      _isSearchingAccounts = false;
      _isSendingOtp = false;
      _isVerifyingOtp = false;
      _findTxnId = '';
      _abhaAccounts = [];
      _selectedAccount = null;
      _otpTxnId = '';
      _otpMessage = '';
      _errorBanner = '';
      _is409Conflict = false;
      _profileTokenId = '';
      _cardBase64 = '';
      _isLoadingCard = false;
      _mobileNumberController.clear();
      _otpController.clear();
    });
  }

  void _resetManualForm() {
    setState(() {
      _firstNameController.clear();
      _lastNameController.clear();
      _ageController.clear();
      _manualMobileController.clear();
      _idValueController.clear();
      _addressController.clear();
      _villageController.clear();
      _pincodeController.clear();
      _gender = 'Male';
      _idType = 'AADHAAR';
      _district = 'Guntur';
      _isSavingManual = false;
      _errorBanner = '';
    });
  }

  @override
  void initState() {
    super.initState();
    _mobileNumberController.addListener(_onFieldChanged);
    _firstNameController.addListener(_onFieldChanged);
    _lastNameController.addListener(_onFieldChanged);
    _ageController.addListener(_onFieldChanged);
    _manualMobileController.addListener(_onFieldChanged);
    _idValueController.addListener(_onFieldChanged);
    _createAadhaarController.addListener(_onFieldChanged);
    _createOtpController.addListener(_onFieldChanged);
    _createMobileController.addListener(_onFieldChanged);
    _customAbhaAddressController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _mobileNumberController.removeListener(_onFieldChanged);
    _firstNameController.removeListener(_onFieldChanged);
    _lastNameController.removeListener(_onFieldChanged);
    _ageController.removeListener(_onFieldChanged);
    _manualMobileController.removeListener(_onFieldChanged);
    _idValueController.removeListener(_onFieldChanged);
    _createAadhaarController.removeListener(_onFieldChanged);
    _createOtpController.removeListener(_onFieldChanged);
    _createMobileController.removeListener(_onFieldChanged);
    _customAbhaAddressController.removeListener(_onFieldChanged);

    _mobileNumberController.dispose();
    _otpController.dispose();
    _cooldownTimer?.cancel();

    _createAadhaarController.dispose();
    _createOtpController.dispose();
    _createMobileController.dispose();
    _customAbhaAddressController.dispose();

    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _manualMobileController.dispose();
    _idValueController.dispose();
    _addressController.dispose();
    _villageController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 30]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldownSeconds = 0);
      } else {
        if (mounted) setState(() => _cooldownSeconds--);
      }
    });
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'P';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MOBILE FLOW API HANDLERS
  // ─────────────────────────────────────────────────────────────────────────────

  /// Step 1: Submit Mobile Number to find accounts
  Future<void> _handleFindAccount() async {
    final raw = _mobileNumberController.text.trim().replaceAll(RegExp(r'\D'), '');
    if (raw.length != 10) {
      setState(() => _errorBanner = 'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isSearchingAccounts = true;
      _errorBanner = '';
    });

    try {
      final res = await MobileApiService().abhaFindAccount(raw);

      // Immediately retain searched number and clear input fields after calling API
      _searchedMobileNumber = raw;
      _mobileNumberController.clear();
      _otpController.clear();

      final isSuccess = res['success'] == true;
      final data = res['data'];

      if (isSuccess && data is Map) {
        final txnId = data['txnId']?.toString() ?? '';
        final rawAccounts = data['accounts'];
        final accounts = rawAccounts is List
            ? List<Map<String, dynamic>>.from(rawAccounts.whereType<Map>())
            : <Map<String, dynamic>>[];

        if (accounts.isEmpty) {
          setState(() {
            _isSearchingAccounts = false;
            _errorBanner =
                'No linked ABHA accounts found for +91 $raw. You can register manually.';
          });
          return;
        }

        // Auto-select first account (prefer unregistered)
        final firstAvailable = accounts.firstWhere(
          (acc) => acc['registered'] != true,
          orElse: () => accounts.first,
        );

        setState(() {
          _isSearchingAccounts = false;
          _findTxnId = txnId;
          _abhaAccounts = accounts;
          _selectedAccount = firstAvailable;
          _otpProvider = 'aadhaar'; // default to Aadhaar OTP
          _mobileStep = 1; // Move to Select Account step
          _errorBanner = '';
        });
      } else {
        setState(() {
          _isSearchingAccounts = false;
          _errorBanner = res['message']?.toString() ??
              'Failed to search ABHA accounts. Please verify the mobile number.';
        });
      }
    } catch (e) {
      debugPrint('Find account error: $e');
      setState(() {
        _mobileNumberController.clear();
        _otpController.clear();
        _isSearchingAccounts = false;
        _errorBanner = 'Connection error. Please try again.';
      });
    }
  }

  /// Step 2: Send OTP
  Future<void> _handleSendOtp() async {
    if (_selectedAccount == null) {
      setState(() => _errorBanner = 'Please select an ABHA account');
      return;
    }
    if (_selectedAccount!['registered'] == true) {
      setState(() => _errorBanner =
          'This ABHA account is already registered in the system.');
      return;
    }

    setState(() {
      _isSendingOtp = true;
      _errorBanner = '';
    });

    try {
      final indexStr = (_selectedAccount!['index'] ?? '').toString();
      final res = await MobileApiService().abhaSendOtp(
        txnId: _findTxnId,
        index: indexStr,
        otpProvider: _otpProvider,
      );

      // Immediately clear OTP field after calling API
      _otpController.clear();

      final isSuccess = res['success'] == true;
      final data = res['data'];

      if (isSuccess && data is Map) {
        final nextTxnId = data['txnId']?.toString() ?? _findTxnId;
        final msg = data['message']?.toString() ?? 'OTP sent successfully';

        setState(() {
          _isSendingOtp = false;
          _otpTxnId = nextTxnId;
          _otpMessage = msg;
          _mobileStep = 2; // Move to Enter OTP step
          _errorBanner = '';
        });
        _startCooldown(30);
      } else {
        setState(() {
          _isSendingOtp = false;
          _errorBanner = res['message']?.toString() ??
              'Failed to send OTP. Please try again.';
        });
      }
    } catch (e) {
      debugPrint('Send OTP error: $e');
      setState(() {
        _otpController.clear();
        _isSendingOtp = false;
        _errorBanner = 'Failed to connect. Please try again.';
      });
    }
  }

  /// Step 3: Verify OTP
  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorBanner = 'Please enter the complete 6-digit OTP');
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _errorBanner = '';
    });

    try {
      final res = await MobileApiService().abhaVerifyOtp(
        txnId: _otpTxnId,
        otp: otp,
      );

      // Immediately clear fields after calling API
      _otpController.clear();
      _mobileNumberController.clear();

      final isSuccess = res['success'] == true;
      final data = res['data'];

      if (isSuccess && data != null) {
        final rawData = data is Map ? data : {};
        final token = rawData['profileTokenId']?.toString() ?? '';
        setState(() {
          _profileTokenId = token;
          _isVerifyingOtp = false;
          _mobileStep = 3; // Move to Success Screen
          _errorBanner = '';
          _is409Conflict = false;
        });
      } else {
        final isConflict = res['statusCode'] == 409 ||
            (res['message'] != null &&
                res['message'].toString().toLowerCase().contains('already registered'));
        setState(() {
          _isVerifyingOtp = false;
          _is409Conflict = isConflict;
          _errorBanner = res['message']?.toString() ??
              'Invalid OTP or verification failed. Please try again.';
        });
      }
    } catch (e) {
      debugPrint('Verify OTP error: $e');
      setState(() {
        _otpController.clear();
        _mobileNumberController.clear();
        _isVerifyingOtp = false;
        _errorBanner = 'Verification failed. Please check connection.';
      });
    }
  }

  /// View ABHA Digital Card in modal dialog
  Future<void> _handleViewCard() async {
    if (_profileTokenId.isEmpty) return;
    if (_cardBase64.isNotEmpty) {
      _showCardDialog(_cardBase64);
      return;
    }
    setState(() => _isLoadingCard = true);
    try {
      final card = await MobileApiService().abhaGetCard(_profileTokenId);
      if (mounted) setState(() => _isLoadingCard = false);
      if (card != null && card.isNotEmpty) {
        if (mounted) {
          setState(() => _cardBase64 = card);
          _showCardDialog(card);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not load ABHA card at this time.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCard = false);
    }
  }

  Future<void> _loadCardBase64(String token) async {
    try {
      final card = await MobileApiService().abhaGetCard(token);
      if (card != null && card.isNotEmpty && mounted) {
        setState(() => _cardBase64 = card);
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CREATE ABHA (VIA AADHAAR) API HANDLERS
  // ─────────────────────────────────────────────────────────────────────────────

  /// Create Step 1: Send OTP to Aadhaar
  /// POST /abha/create/send-otp {"aadhaarNumber": "..."}
  Future<void> _handleCreateSendOtp() async {
    final cleanAadhaar =
        _createAadhaarController.text.trim().replaceAll(RegExp(r'\D'), '');
    if (cleanAadhaar.length != 12) {
      setState(() => _errorBanner =
          'Please enter a valid 12-digit Aadhaar number');
      return;
    }

    setState(() {
      _isSendingCreateOtp = true;
      _errorBanner = '';
    });

    try {
      final res = await MobileApiService().abhaCreateSendOtp(cleanAadhaar);

      // Immediately clear controllers after calling API
      _createAadhaarController.clear();
      _createOtpController.clear();
      _createMobileController.clear();

      final isSuccess = res['success'] == true;
      final data = res['data'];

      if (isSuccess && data is Map) {
        final txnId = data['txnId']?.toString() ??
            (data['data'] is Map ? data['data']['txnId']?.toString() : null) ??
            '';
        final msg = res['message']?.toString() ??
            data['message']?.toString() ??
            'OTP sent to registered mobile for Aadhaar verification.';

        setState(() {
          _isSendingCreateOtp = false;
          _createTxnId = txnId;
          _createOtpMessage = msg;
          _createAbhaStep = 1; // Move to enter OTP & mobile step
          _errorBanner = '';
        });
        _startCooldown(30);
      } else {
        setState(() {
          _isSendingCreateOtp = false;
          _errorBanner = res['message']?.toString() ??
              res['error']?.toString() ??
              'Failed to send Aadhaar OTP. Please check the Aadhaar number.';
        });
      }
    } catch (e) {
      debugPrint('Create Send OTP error: $e');
      setState(() {
        _createAadhaarController.clear();
        _createOtpController.clear();
        _createMobileController.clear();
        _isSendingCreateOtp = false;
        _errorBanner = 'Connection error. Please try again.';
      });
    }
  }

  /// Create Step 2: Verify OTP & Mobile, then fetch Address suggestions
  /// POST /abha/create/verify-otp {"txnId": "...", "otp": "...", "mobileNumber": "..."}
  Future<void> _handleCreateVerifyOtp() async {
    final otp = _createOtpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorBanner = 'Please enter a valid 6-digit OTP');
      return;
    }

    final cleanMobile =
        _createMobileController.text.trim().replaceAll(RegExp(r'\D'), '');
    if (cleanMobile.length != 10) {
      setState(() => _errorBanner =
          'Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isVerifyingCreateOtp = true;
      _errorBanner = '';
    });

    try {
      final res = await MobileApiService().abhaCreateVerifyOtp(
        txnId: _createTxnId,
        otp: otp,
        mobileNumber: cleanMobile,
      );

      // Immediately retain created mobile and clear controllers after calling API
      _createdMobileNumber = cleanMobile;
      _createAadhaarController.clear();
      _createOtpController.clear();
      _createMobileController.clear();

      final isSuccess = res['success'] == true;
      final rawData = res['data'];

      if (isSuccess) {
        final Map<String, dynamic> data =
            rawData is Map ? Map<String, dynamic>.from(rawData) : {};

        // Check if already completed or already exists
        final msg = res['message']?.toString() ?? '';
        final alreadyExists = data['alreadyExists'] == true ||
            res['alreadyExists'] == true ||
            msg.toLowerCase().contains('already exist');

        if (alreadyExists) {
          final token = data['token']?.toString() ??
              data['profileTokenId']?.toString() ??
              '';
          setState(() {
            _isVerifyingCreateOtp = false;
            _createdAbhaData = data;
            _profileTokenId = token;
            _createAbhaStep = 3; // Success screen
            _errorBanner = '';
          });
          if (token.isNotEmpty) {
            _loadCardBase64(token);
          }
          return;
        }

        // Update txnId from verifyOtp response
        final nextTxn = data['txnId']?.toString() ??
            res['txnId']?.toString() ??
            data['transactionId']?.toString() ??
            res['transactionId']?.toString() ??
            _createTxnId;
        _createTxnId = nextTxn;

        // Fetch address suggestions using updated txnId
        final sugRes =
            await MobileApiService().abhaCreateAddressSuggestions(_createTxnId);
        final List<String> suggestions = [];

        final preferred = data['preferredAbhaAddress']?.toString() ??
            data['abhaAddress']?.toString() ??
            '';
        if (preferred.isNotEmpty) {
          suggestions.add(preferred);
        }

        final sugData = sugRes['data'];
        final candidates = [
          sugData is Map ? sugData['abhaAddress'] : null,
          sugRes['abhaAddress'],
          sugData is Map ? sugData['suggestions'] : null,
          sugData is Map ? sugData['addresses'] : null,
          sugRes['suggestions'],
          sugRes['addresses'],
        ];

        for (final c in candidates) {
          if (c is List) {
            for (final item in c) {
              final str = item is String
                  ? item.trim()
                  : (item is Map
                      ? (item['abhaAddress'] ?? item['address'])
                          ?.toString()
                          .trim()
                      : null);
              if (str != null && str.isNotEmpty && !suggestions.contains(str)) {
                suggestions.add(str);
              }
            }
          }
        }

        setState(() {
          _isVerifyingCreateOtp = false;
          _createAddressSuggestions = suggestions;
          _selectedAbhaAddress =
              suggestions.isNotEmpty ? suggestions.first : '';
          _useCustomAbhaAddress = suggestions.isEmpty;
          _customAbhaAddressController.clear();
          _createAbhaStep = 2; // Move to Address Selection Step
          _errorBanner = '';
        });
      } else {
        setState(() {
          _isVerifyingCreateOtp = false;
          _errorBanner = res['message']?.toString() ??
              res['error']?.toString() ??
              'Failed to verify Aadhaar OTP. Please check the code and try again.';
        });
      }
    } catch (e) {
      debugPrint('Create Verify OTP error: $e');
      setState(() {
        _isVerifyingCreateOtp = false;
        _errorBanner = 'Connection error. Please try again.';
      });
    }
  }

  /// Create Step 3: Set chosen ABHA address to create the ABHA account
  /// POST /abha/create/address {"txnId": "...", "abhaAddress": "..."}
  Future<void> _handleCreateSetAddress() async {
    final chosenAddress = _useCustomAbhaAddress
        ? _customAbhaAddressController.text.trim()
        : _selectedAbhaAddress.trim();

    if (chosenAddress.isEmpty) {
      setState(() => _errorBanner = 'Please select or enter an ABHA address');
      return;
    }

    setState(() {
      _isSettingAbhaAddress = true;
      _errorBanner = '';
    });

    try {
      final res = await MobileApiService().abhaCreateSetAddress(
        txnId: _createTxnId,
        abhaAddress: chosenAddress,
      );

      final isSuccess = res['success'] == true;
      final rawData = res['data'];

      if (isSuccess) {
        final Map<String, dynamic> data = rawData is Map
            ? Map<String, dynamic>.from(rawData)
            : Map<String, dynamic>.from(res);

        if (data['abhaAddress'] == null ||
            data['abhaAddress'].toString().isEmpty) {
          data['abhaAddress'] = chosenAddress;
        }

        final token = data['token']?.toString() ??
            data['profileTokenId']?.toString() ??
            '';

        setState(() {
          _isSettingAbhaAddress = false;
          _createdAbhaData = data;
          _profileTokenId = token;
          _createAbhaStep = 3; // Move to Success screen
          _errorBanner = '';
        });

        if (token.isNotEmpty) {
          _loadCardBase64(token);
        }
      } else {
        setState(() {
          _isSettingAbhaAddress = false;
          _errorBanner = res['message']?.toString() ??
              res['error']?.toString() ??
              'Failed to create ABHA account with this address. Please try another address.';
        });
      }
    } catch (e) {
      debugPrint('Create Set Address error: $e');
      setState(() {
        _isSettingAbhaAddress = false;
        _errorBanner = 'Connection error. Please try again.';
      });
    }
  }

  void _showCardDialog(String base64Str) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        actionsPadding: const EdgeInsets.all(12),
        title: Row(
          children: [
            const Icon(Icons.credit_card_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'ABHA Digital Card',
              style: GoogleFonts.notoSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                base64Decode(base64Str.replaceAll(RegExp(r'\s+'), '')),
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // MANUAL REGISTRATION HANDLERS
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _lookupPincode(String pincode) async {
    if (pincode.trim().length != 6) return;
    setState(() => _isLookingUpPincode = true);
    try {
      final res = await MobileApiService().fetchPincodeDetails(pincode.trim());
      if (mounted && res != null) {
        setState(() {
          if (res['state_name'] != null) {
            _state = res['state_name'].toString();
          }
          final districts = res['districts'];
          if (districts is List && districts.isNotEmpty) {
            final first = districts.first;
            final dName = first is Map
                ? (first['district_name'] ?? first['name'])
                : first.toString();
            if (dName != null && dName.toString().isNotEmpty) {
              final match = _districts.firstWhere(
                (d) => d.toLowerCase() == dName.toString().toLowerCase(),
                orElse: () => _district,
              );
              _district = match;
            }
          }
          _isLookingUpPincode = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLookingUpPincode = false);
    }
  }

  Future<void> _submitManualPatient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSavingManual = true);

    final age = int.tryParse(_ageController.text.trim());
    final birthYear =
        age != null ? (DateTime.now().year - age) : DateTime.now().year;
    final dob = '$birthYear-01-01';

    final genderCode =
        _gender == 'Male' ? 'M' : (_gender == 'Female' ? 'F' : 'O');

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final fullName =
        '$firstName ${lastName.isNotEmpty ? lastName : ''}'.trim();
    final mobile = _manualMobileController.text.trim();

    final payload = {
      'first_name': firstName,
      'last_name': lastName,
      'gender': genderCode,
      'dob': dob,
      'mobile': mobile,
      'identifier_type': _idType,
      'identifier_value': _idValueController.text.trim(),
      'address_line1': _addressController.text.trim(),
      'city': _villageController.text.trim(),
      'district': _district,
      'state': _state,
      'pincode': _pincodeController.text.trim(),
    };

    final res = await MobileApiService().registerPatient(
      payload,
      menuId: widget.menuId,
      moduleId: widget.moduleId,
      actionCode: 'ADD',
    );

    if (!mounted) return;
    setState(() => _isSavingManual = false);

    // Immediately clear all fields after calling API
    _firstNameController.clear();
    _lastNameController.clear();
    _ageController.clear();
    _manualMobileController.clear();
    _idValueController.clear();
    _addressController.clear();
    _villageController.clear();
    _pincodeController.clear();

    if (res['success'] != true) {
      final msg = res['message']?.toString() ?? 'Registration failed. Please try again.';
      setState(() => _errorBanner = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final rawData = res['data'];
    final generatedUhid = rawData is Map
        ? (rawData['mrn'] ??
            rawData['uhid'] ??
            rawData['patient_id']?.toString())
        : null;
    final displayUhid = generatedUhid?.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_alt_1_rounded,
                  color: Color(0xFF16A34A), size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Patient Registered!',
              style: GoogleFonts.notoSans(
                  fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '${fullName.isNotEmpty ? fullName : 'Patient'} enrolled successfully.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                  fontSize: 13, color: const Color(0xFF64748B)),
            ),
            if (displayUhid != null && displayUhid.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(
                      'RECORD IDENTIFIER',
                      style: GoogleFonts.notoSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      displayUhid,
                      style: GoogleFonts.notoSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Add Another'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RegisterPatientToCampScreen(
                            initialSearchQuery: displayUhid?.isNotEmpty == true
                                ? displayUhid
                                : (mobile.isNotEmpty ? mobile : null),
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Camp Reg'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD METHOD
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // If one tab is active in process, the other tab is disabled.
    final isMobileActive = _isMobileActiveInProcess;
    final isManualActive = _isManualActiveInProcess;

    final isManualTabDisabled = isMobileActive;
    final isMobileTabDisabled = isManualActive;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const StaffAppDrawer(currentRoute: '/portal/patient/register'),
      bottomNavigationBar:
          const StaffBottomNavBar(currentRoute: '/portal/patient/register'),
      appBar: StaffAppBar(onOpenDrawer: widget.onOpenDrawer),
      body: SafeArea(
        child: Column(
          children: [
            // Top Mode Switcher: With Mobile (ABHA) vs Manual Registration
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  // Tab 1: With Mobile (ABHA)
                  Expanded(
                    child: Opacity(
                      opacity: isMobileTabDisabled ? 0.45 : 1.0,
                      child: InkWell(
                        onTap: isMobileTabDisabled
                            ? () {
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Manual registration is in progress. Complete or reset the form to switch tabs.',
                                    ),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            : () {
                                setState(() {
                                  _registrationMode = 'mobile';
                                  _errorBanner = '';
                                });
                              },
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _registrationMode == 'mobile'
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _registrationMode == 'mobile'
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isMobileTabDisabled
                                    ? Icons.lock_outline_rounded
                                    : Icons.smartphone_rounded,
                                size: 17,
                                color: isMobileTabDisabled
                                    ? const Color(0xFF94A3B8)
                                    : (_registrationMode == 'mobile'
                                        ? AppColors.primary
                                        : const Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'With Mobile (ABHA)',
                                style: GoogleFonts.notoSans(
                                  fontSize: 13,
                                  fontWeight: _registrationMode == 'mobile'
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: isMobileTabDisabled
                                      ? const Color(0xFF94A3B8)
                                      : (_registrationMode == 'mobile'
                                          ? AppColors.primary
                                          : const Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Tab 2: Manual Form
                  Expanded(
                    child: Opacity(
                      opacity: isManualTabDisabled ? 0.45 : 1.0,
                      child: InkWell(
                        onTap: isManualTabDisabled
                            ? () {
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'ABHA Mobile Registration is active. Complete or reset the current process first.',
                                    ),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            : () {
                                setState(() {
                                  _registrationMode = 'manual';
                                  _errorBanner = '';
                                });
                              },
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _registrationMode == 'manual'
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _registrationMode == 'manual'
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.06),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isManualTabDisabled
                                    ? Icons.lock_outline_rounded
                                    : Icons.edit_note_rounded,
                                size: 19,
                                color: isManualTabDisabled
                                    ? const Color(0xFF94A3B8)
                                    : (_registrationMode == 'manual'
                                        ? AppColors.primary
                                        : const Color(0xFF64748B)),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'Manual Form',
                                style: GoogleFonts.notoSans(
                                  fontSize: 13,
                                  fontWeight: _registrationMode == 'manual'
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: isManualTabDisabled
                                      ? const Color(0xFF94A3B8)
                                      : (_registrationMode == 'manual'
                                          ? AppColors.primary
                                          : const Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Error banner if any
            if (_errorBanner.isNotEmpty)
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorBanner,
                            style: GoogleFonts.notoSans(
                              fontSize: 12.5,
                              color: const Color(0xFFDC2626),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 16, color: Color(0xFFDC2626)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => setState(() {
                            _errorBanner = '';
                            _is409Conflict = false;
                          }),
                        ),
                      ],
                    ),
                    if (_is409Conflict) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RegisterPatientToCampScreen(
                                initialSearchQuery:
                                    _searchedMobileNumber.isNotEmpty
                                        ? _searchedMobileNumber
                                        : null,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.arrow_forward_rounded,
                            size: 15, color: Color(0xFFDC2626)),
                        label: const Text(
                          'Proceed to Camp Registration',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Content body: Mobile wizard OR Manual form
            Expanded(
              child: _registrationMode == 'mobile'
                  ? _buildMobileFlow()
                  : _buildManualForm(),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // WIZARD FOR MOBILE (ABHA) REGISTRATION
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildMobileFlow() {
    if (_isCreateAbhaMode) {
      return _buildCreateAbhaFlow();
    }

    switch (_mobileStep) {
      case 0:
        return _buildStep0EnterMobile();
      case 1:
        return _buildStep1SelectAccount();
      case 2:
        return _buildStep2VerifyOtp();
      case 3:
        return _buildStep3Success();
      default:
        return _buildStep0EnterMobile();
    }
  }

  Widget _buildCreateAbhaFlow() {
    switch (_createAbhaStep) {
      case 0:
        return _buildCreateStep0Aadhaar();
      case 1:
        return _buildCreateStep1OtpAndMobile();
      case 2:
        return _buildCreateStep2AddressSelection();
      case 3:
        return _buildCreateStep3Success();
      default:
        return _buildCreateStep0Aadhaar();
    }
  }

  // STEP 0: ENTER MOBILE NUMBER
  Widget _buildStep0EnterMobile() {
    final hasNumber = _mobileNumberController.text.trim().isNotEmpty;
    final isValidNumber = _mobileNumberController.text
            .trim()
            .replaceAll(RegExp(r'\D'), '')
            .length ==
        10;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Input Card: Floating White Card for Mobile Lookup
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.phone_iphone_rounded,
                              size: 16, color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SEARCH PATIENT',
                          style: GoogleFonts.notoSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'BY MOBILE',
                        style: GoogleFonts.notoSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Phone Input with Country Pill and Divider
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isValidNumber
                          ? AppColors.primary
                          : const Color(0xFFCBD5E1),
                      width: isValidNumber ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Country Badge
                      Padding(
                        padding: const EdgeInsets.only(left: 12, right: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('🇮🇳',
                                      style: TextStyle(fontSize: 15)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+91',
                                    style: GoogleFonts.notoSans(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              width: 1,
                              height: 24,
                              color: const Color(0xFFCBD5E1),
                            ),
                          ],
                        ),
                      ),

                      // Input Text Field
                      Expanded(
                        child: TextField(
                          controller: _mobileNumberController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          onChanged: (val) => setState(() {}),
                          style: GoogleFonts.notoSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '10-digit mobile',
                            hintStyle: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                              color: const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 4,
                            ),
                          ),
                        ),
                      ),

                      // Clear Button
                      if (hasNumber)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: IconButton(
                            icon: const Icon(Icons.cancel_rounded,
                                size: 19, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              setState(() {
                                _mobileNumberController.clear();
                                _errorBanner = '';
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Helper text
                Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Ensure this number is linked with patient’s ABHA / Aadhaar.',
                        style: GoogleFonts.notoSans(
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Search Button with Gradient and Glow
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isValidNumber && !_isSearchingAccounts
                          ? [const Color(0xFF004990), const Color(0xFF0066CC)]
                          : [const Color(0xFF94A3B8), const Color(0xFFCBD5E1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: isValidNumber && !_isSearchingAccounts
                        ? [
                            BoxShadow(
                              color: const Color(0xFF004990).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: ElevatedButton(
                    onPressed:
                        (_isSearchingAccounts || !isValidNumber)
                            ? null
                            : _handleFindAccount,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSearchingAccounts
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_rounded,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Find Linked ABHA Accounts',
                                style: GoogleFonts.notoSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // OR ENROLL NEW CITIZEN DIVIDER
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    const Icon(Icons.fiber_new_rounded,
                        size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      'OR ENROLL NEW CITIZEN',
                      style: GoogleFonts.notoSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
            ],
          ),
          const SizedBox(height: 18),

          // Standalone Premium Hero Card: Create ABHA (via Aadhaar)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF003875), Color(0xFF005BAC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF004990).withOpacity(0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isCreateAbhaMode = true;
                    _createAbhaStep = 0;
                    _createAadhaarController.clear();
                    _createOtpController.clear();
                    _createMobileController.clear();
                    _errorBanner = '';
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      // Biometric Icon Container
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.fingerprint_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Text info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF38BDF8)
                                        .withOpacity(0.25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'AADHAAR E-KYC',
                                    style: GoogleFonts.notoSans(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFBAE6FD),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '⚡ FAST 2-MIN',
                                  style: GoogleFonts.notoSans(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFFDE047),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Create ABHA (via Aadhaar)',
                              style: GoogleFonts.notoSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Instant enrollment using 12-digit Aadhaar & OTP',
                              style: GoogleFonts.notoSans(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Arrow button
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Trust & Security Footer
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shield_outlined,
                    size: 15, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  'Ayushman Bharat Digital Mission (ABDM) Certified',
                  style: GoogleFonts.notoSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CREATE ABHA (VIA AADHAAR) SCREENS
  // ─────────────────────────────────────────────────────────────────────────────

  // CREATE ABHA STEP 0: Enter Aadhaar Number
  Widget _buildCreateStep0Aadhaar() {
    final cleanAadhaar =
        _createAadhaarController.text.trim().replaceAll(RegExp(r'\D'), '');
    final isValidAadhaar = cleanAadhaar.length == 12;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Navigation & Step Indicator Bar
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _isCreateAbhaMode = false;
                      _createAbhaStep = 0;
                      _errorBanner = '';
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 20, color: Color(0xFF1E293B)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create ABHA (via Aadhaar)',
                      style: GoogleFonts.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Step 1 of 2: Aadhaar e-KYC',
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Text(
                  'STEP 1/3',
                  style: GoogleFonts.notoSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Official UIDAI / ABDM Hero Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF002B5C), Color(0xFF004990)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF004990).withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Official ABDM Registration',
                        style: GoogleFonts.notoSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'A 6-digit OTP will be sent to the mobile linked with this Aadhaar.',
                        style: GoogleFonts.notoSans(
                          fontSize: 11.5,
                          color: Colors.white.withOpacity(0.85),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Aadhaar Input Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Field Header with Counter
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AADHAAR NUMBER',
                      style: GoogleFonts.notoSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    Text(
                      '${cleanAadhaar.length} / 12',
                      style: GoogleFonts.sourceCodePro(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isValidAadhaar
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Aadhaar input container (Clean, direct input field)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isValidAadhaar
                          ? const Color(0xFF16A34A)
                          : (cleanAadhaar.isNotEmpty
                              ? AppColors.primary
                              : const Color(0xFFCBD5E1)),
                      width:
                          (isValidAadhaar || cleanAadhaar.isNotEmpty) ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _createAadhaarController,
                          keyboardType: TextInputType.number,
                          maxLength: 12,
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.2,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: 'Enter 12-digit Aadhaar number',
                            hintStyle: GoogleFonts.notoSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                              color: const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 16,
                            ),
                          ),
                        ),
                      ),
                      if (isValidAadhaar)
                        const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF16A34A),
                            size: 22,
                          ),
                        )
                      else if (cleanAadhaar.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: IconButton(
                            icon: const Icon(Icons.cancel_rounded,
                                size: 19, color: Color(0xFF94A3B8)),
                            onPressed: () {
                              setState(() {
                                _createAadhaarController.clear();
                                _errorBanner = '';
                              });
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Privacy Note
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your Aadhaar number is 256-bit encrypted and only used for ABDM OTP verification. We do not store biometric data.',
                          style: GoogleFonts.notoSans(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Button: Send Aadhaar OTP (APVC signature primary gradient)
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isValidAadhaar && !_isSendingCreateOtp
                          ? [const Color(0xFF004990), const Color(0xFF0066CC)]
                          : [const Color(0xFF94A3B8), const Color(0xFFCBD5E1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: isValidAadhaar && !_isSendingCreateOtp
                        ? [
                            BoxShadow(
                              color: const Color(0xFF004990).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: ElevatedButton(
                    onPressed: (isValidAadhaar && !_isSendingCreateOtp)
                        ? _handleCreateSendOtp
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSendingCreateOtp
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 9),
                              Text(
                                'Send Aadhaar OTP',
                                style: GoogleFonts.notoSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Security / Trust footer
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined,
                    size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Ayushman Bharat Digital Mission (ABDM) Certified',
                    style: GoogleFonts.notoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  // CREATE ABHA STEP 1: Enter OTP and Mobile Number
  Widget _buildCreateStep1OtpAndMobile() {
    final cleanMobile =
        _createMobileController.text.trim().replaceAll(RegExp(r'\D'), '');
    final cleanOtp = _createOtpController.text.trim();
    final isFormValid = cleanOtp.length == 6 && cleanMobile.length == 10;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Navigation & Step Indicator Bar
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _createAbhaStep = 0;
                      _errorBanner = '';
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 20, color: Color(0xFF1E293B)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify Aadhaar OTP',
                      style: GoogleFonts.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Step 2 of 3: OTP & Mobile Link',
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Text(
                  'STEP 2/3',
                  style: GoogleFonts.notoSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // OTP Sent Success Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aadhaar OTP Dispatched',
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _createOtpMessage.isNotEmpty
                            ? _createOtpMessage
                            : 'Enter the 6-digit OTP sent by UIDAI to patient’s Aadhaar-linked mobile.',
                        style: GoogleFonts.notoSans(
                          fontSize: 11.5,
                          color: const Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Main Verification Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Field 1: Enter OTP
                Text(
                  'ENTER 6-DIGIT OTP',
                  style: GoogleFonts.notoSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _createOtpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.sourceCodePro(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 14.0,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '••••••',
                    hintStyle: GoogleFonts.sourceCodePro(
                      fontSize: 22,
                      letterSpacing: 14.0,
                      color: const Color(0xFFCBD5E1),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),

                // Resend Timer Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _cooldownSeconds > 0
                          ? 'Resend OTP in ${_cooldownSeconds}s'
                          : 'Didn’t receive the code?',
                      style: GoogleFonts.notoSans(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    TextButton(
                      onPressed:
                          _cooldownSeconds == 0 && !_isSendingCreateOtp
                              ? _handleCreateSendOtp
                              : null,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Resend OTP',
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _cooldownSeconds == 0
                              ? AppColors.primary
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Field 2: Mobile Number
                Text(
                  'LINKED MOBILE NUMBER',
                  style: GoogleFonts.notoSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cleanMobile.length == 10
                          ? AppColors.primary
                          : const Color(0xFFCBD5E1),
                      width: cleanMobile.length == 10 ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: Text(
                          '+91',
                          style: GoogleFonts.notoSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 22,
                        color: const Color(0xFFCBD5E1),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _createMobileController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          onChanged: (_) => setState(() {}),
                          style: GoogleFonts.notoSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: '10-digit mobile number',
                            hintStyle: GoogleFonts.notoSans(
                              fontSize: 14,
                              color: const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 14, horizontal: 4),
                          ),
                        ),
                      ),
                      if (cleanMobile.length == 10)
                        const Padding(
                          padding: EdgeInsets.only(right: 12),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF16A34A),
                            size: 19,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons: [Back] [Verify OTP & Create ABHA]
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() => _createAbhaStep = 0);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xFFCBD5E1), width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Back',
                            style: GoogleFonts.notoSans(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isFormValid && !_isVerifyingCreateOtp
                                ? [
                                    const Color(0xFF004990),
                                    const Color(0xFF0066CC)
                                  ]
                                : [
                                    const Color(0xFFCBD5E1),
                                    const Color(0xFFE2E8F0)
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isFormValid && !_isVerifyingCreateOtp
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF004990)
                                        .withOpacity(0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: ElevatedButton(
                          onPressed: (isFormValid && !_isVerifyingCreateOtp)
                              ? _handleCreateVerifyOtp
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isVerifyingCreateOtp
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.2,
                                  ),
                                )
                              : Text(
                                  'Verify OTP',
                                  style: GoogleFonts.notoSans(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Security / Trust footer
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined,
                    size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Ayushman Bharat Digital Mission (ABDM) Certified',
                    style: GoogleFonts.notoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  // CREATE ABHA STEP 2: Choose / Create ABHA Address
  Widget _buildCreateStep2AddressSelection() {
    final chosenAddress = _useCustomAbhaAddress
        ? _customAbhaAddressController.text.trim()
        : _selectedAbhaAddress.trim();
    final canSubmit = chosenAddress.isNotEmpty && !_isSettingAbhaAddress;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Navigation & Step Indicator Bar
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSettingAbhaAddress
                      ? null
                      : () {
                          setState(() {
                            _createAbhaStep = 1;
                            _errorBanner = '';
                          });
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        size: 20, color: Color(0xFF1E293B)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose ABHA Address',
                      style: GoogleFonts.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Step 3 of 3: Select or Enter Address',
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Text(
                  'STEP 3/3',
                  style: GoogleFonts.notoSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Official ABDM Hero Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF002B5C), Color(0xFF004990)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF004990).withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.alternate_email_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select ABHA Address',
                        style: GoogleFonts.notoSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Your ABHA address is your unique username for sharing health records across India.',
                        style: GoogleFonts.notoSans(
                          fontSize: 11.5,
                          color: Colors.white.withOpacity(0.85),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Suggestions Section Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SUGGESTED ABHA ADDRESSES',
                  style: GoogleFonts.notoSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 12),

                if (_createAddressSuggestions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      'No automatic suggestions returned. Please enter your preferred ABHA address below.',
                      style: GoogleFonts.notoSans(
                        fontSize: 12.5,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                else
                  ..._createAddressSuggestions.map((addr) {
                    final isSelected =
                        !_useCustomAbhaAddress && _selectedAbhaAddress == addr;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: _isSettingAbhaAddress
                            ? null
                            : () {
                                setState(() {
                                  _useCustomAbhaAddress = false;
                                  _selectedAbhaAddress = addr;
                                  _errorBanner = '';
                                });
                              },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFF0F7FF)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF004990)
                                  : const Color(0xFFE2E8F0),
                              width: isSelected ? 1.8 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: isSelected
                                    ? const Color(0xFF004990)
                                    : const Color(0xFF94A3B8),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  addr,
                                  style: GoogleFonts.notoSans(
                                    fontSize: 13.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? const Color(0xFF002B5C)
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF004990)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Recommended',
                                    style: GoogleFonts.notoSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF004990),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 6),
                const Divider(height: 20),
                const SizedBox(height: 4),

                // Custom ABHA Address Option
                InkWell(
                  onTap: _isSettingAbhaAddress
                      ? null
                      : () {
                          setState(() {
                            _useCustomAbhaAddress = true;
                            _errorBanner = '';
                          });
                        },
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: _useCustomAbhaAddress
                          ? const Color(0xFFF0F7FF)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _useCustomAbhaAddress
                            ? const Color(0xFF004990)
                            : const Color(0xFFE2E8F0),
                        width: _useCustomAbhaAddress ? 1.8 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _useCustomAbhaAddress
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: _useCustomAbhaAddress
                              ? const Color(0xFF004990)
                              : const Color(0xFF94A3B8),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Use my own ABHA address',
                          style: GoogleFonts.notoSans(
                            fontSize: 13.5,
                            fontWeight: _useCustomAbhaAddress
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: _useCustomAbhaAddress
                                ? const Color(0xFF002B5C)
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_useCustomAbhaAddress) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: TextField(
                      controller: _customAbhaAddressController,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.notoSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type your address (e.g. rahul123@abdm)',
                        hintStyle: GoogleFonts.notoSans(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Icon(Icons.alternate_email_rounded,
                            size: 18, color: Color(0xFF64748B)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 14,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 22),

                // Submit Button: Create ABHA Account
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: canSubmit
                        ? const LinearGradient(
                            colors: [Color(0xFF004990), Color(0xFF0066CC)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: canSubmit ? null : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: canSubmit
                        ? [
                            BoxShadow(
                              color: const Color(0xFF004990).withOpacity(0.28),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: ElevatedButton(
                    onPressed: canSubmit ? _handleCreateSetAddress : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSettingAbhaAddress
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  size: 19, color: Colors.white),
                              const SizedBox(width: 8),
                              Text(
                                'Create ABHA Account',
                                style: GoogleFonts.notoSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Security / Trust footer
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined,
                    size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Ayushman Bharat Digital Mission (ABDM) Certified',
                    style: GoogleFonts.notoSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  // CREATE ABHA STEP 3: Success Screen
  Widget _buildCreateStep3Success() {
    final data = _createdAbhaData ?? {};
    final abhaNum = data['ABHANumber']?.toString() ??
        data['abhaNumber']?.toString() ??
        data['healthIdNumber']?.toString() ??
        data['maskedAbhaNumber']?.toString() ??
        (data['data'] is Map ? data['data']['ABHANumber']?.toString() : null) ??
        '';
    final abhaAddress = data['abhaAddress']?.toString() ??
        data['preferredAbhaAddress']?.toString() ??
        _selectedAbhaAddress;
    final name = data['name']?.toString() ??
        '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
    final displayName = name.isNotEmpty ? name : 'ABDM Enrolled Patient';
    final gender = data['gender']?.toString() ?? 'M';
    final mobile = data['mobile']?.toString() ??
        data['mobileNumber']?.toString() ??
        _createdMobileNumber;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Celebration Icon
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFDCFCE7),
              border: Border.all(color: const Color(0xFF86EFAC), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16A34A).withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFF16A34A),
              size: 42,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'ABHA Created Successfully!',
            style: GoogleFonts.notoSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Patient is now enrolled in ABDM and registered in the system.',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 22),

          // Details Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'HEALTH RECORD DETAILS',
                      style: GoogleFonts.notoSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF059669),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Registered',
                            style: GoogleFonts.notoSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF047857),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ABHA Number Highlight Box
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ABHA NUMBER',
                        style: GoogleFonts.notoSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF166534),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        abhaNum,
                        style: GoogleFonts.sourceCodePro(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF14532D),
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Name & Gender
                _summaryRow('Patient Name', displayName, Icons.person_outline),
                const Divider(height: 20),
                _summaryRow(
                  'Gender',
                  gender == 'M' ? 'Male' : (gender == 'F' ? 'Female' : gender),
                  Icons.wc_rounded,
                ),
                const Divider(height: 20),
                _summaryRow(
                  'Registered Mobile',
                  '+91 $mobile',
                  Icons.phone_rounded,
                ),
                if (abhaAddress.isNotEmpty) ...[
                  const Divider(height: 20),
                  _summaryRow(
                    'ABHA Address',
                    abhaAddress,
                    Icons.alternate_email_rounded,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Action 1: Register with Mobile (ABHA) - goes to 1st screen of With Mobile (ABHA)
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF004990), Color(0xFF0066CC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF004990).withOpacity(0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _resetMobileFlow,
              icon: const Icon(Icons.phone_android_rounded,
                  size: 19, color: Colors.white),
              label: Text(
                'Register with Mobile (ABHA)',
                style: GoogleFonts.notoSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Action 2: View Card if available
          if (_profileTokenId.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _handleViewCard,
                icon: const Icon(Icons.credit_card_rounded, size: 18),
                label: Text(
                  'View ABHA Digital Card',
                  style: GoogleFonts.notoSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Action 3: Enroll Another Patient (resets Aadhaar flow for new enrollment)
          TextButton(
            onPressed: _resetCreateAbhaFlow,
            child: Text(
              'Enroll Another Patient',
              style: GoogleFonts.notoSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  // STEP 1: SELECT ACCOUNT & CHOOSE OTP PROVIDER
  Widget _buildStep1SelectAccount() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sleek Header with Circular Frosted Back Button & Mobile Chip
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  color: const Color(0xFF334155),
                  onPressed: _resetMobileFlow,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Linked ABHA Accounts',
                      style: GoogleFonts.notoSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone_rounded,
                            size: 12, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          '+91 ${_searchedMobileNumber.isNotEmpty ? _searchedMobileNumber : '—'}',
                          style: GoogleFonts.notoSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _resetMobileFlow,
                          child: Text(
                            'Change',
                            style: GoogleFonts.notoSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Section subtitle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ACCOUNTS FOUND (${_abhaAccounts.length})',
                style: GoogleFonts.notoSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                'Select an account to proceed',
                style: GoogleFonts.notoSans(
                  fontSize: 11,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Accounts List (Modern Two-Tier Health ID Cards, Zero Overflow!)
          ..._abhaAccounts.map((acc) {
            final isSelected = _selectedAccount == acc;
            final isRegistered = acc['registered'] == true;
            final name = acc['name']?.toString() ?? 'Patient';
            final masked =
                acc['maskedAbhaNumber']?.toString() ?? acc['abhaNumber']?.toString() ?? '—';
            final gender = acc['gender']?.toString() ?? 'M';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFF0F7FF)
                    : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFFE2E8F0),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedAccount = acc);
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TIER 1: Initials Avatar + Name & Gender + Custom Selection Circle
                        Row(
                          children: [
                            // Initials Avatar
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isSelected
                                      ? [
                                          AppColors.primary,
                                          const Color(0xFF1E40AF)
                                        ]
                                      : [
                                          const Color(0xFFE2E8F0),
                                          const Color(0xFFCBD5E1)
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _getInitials(name),
                                style: GoogleFonts.notoSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Name & Gender
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.notoSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(
                                        gender == 'M'
                                            ? Icons.male_rounded
                                            : (gender == 'F'
                                                ? Icons.female_rounded
                                                : Icons.person_rounded),
                                        size: 14,
                                        color: const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        gender == 'M'
                                            ? 'Male'
                                            : (gender == 'F'
                                                ? 'Female'
                                                : gender),
                                        style: GoogleFonts.notoSans(
                                          fontSize: 12,
                                          color: const Color(0xFF64748B),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Custom Selection Check Circle
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : const Color(0xFFCBD5E1),
                                  width: isSelected ? 0 : 2,
                                ),
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check,
                                      size: 15, color: Colors.white)
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // TIER 2: Monospace ABHA Number Chip + Status Badge
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.badge_outlined,
                                        size: 13, color: Color(0xFF64748B)),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        masked,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.sourceCodePro(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF334155),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Status Pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isRegistered
                                    ? const Color(0xFFFFFBEB)
                                    : const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isRegistered
                                      ? const Color(0xFFFDE68A)
                                      : const Color(0xFFA7F3D0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isRegistered
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF059669),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    isRegistered ? 'Registered' : 'Available',
                                    style: GoogleFonts.notoSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isRegistered
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF047857),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 14),

          // IF SELECTED ACCOUNT IS ALREADY REGISTERED -> REFINED RECORD FOUND CARD
          if (_selectedAccount != null &&
              _selectedAccount!['registered'] == true) ...[
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFFDE68A)),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFFD97706),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active Patient Record Found',
                              style: GoogleFonts.notoSans(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Enrolled under ${_selectedAccount!['name']}',
                              style: GoogleFonts.notoSans(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This ABHA health record is already registered in the system. You can proceed directly to Camp Registration to check-in or screen this patient.',
                    style: GoogleFonts.notoSans(
                      fontSize: 12.5,
                      color: const Color(0xFF475569),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFD97706), Color(0xFFB45309)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD97706).withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RegisterPatientToCampScreen(
                              initialSearchQuery:
                                  _searchedMobileNumber.isNotEmpty
                                      ? _searchedMobileNumber
                                      : null,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.arrow_forward_rounded,
                          size: 18, color: Colors.white),
                      label: Text(
                        'Proceed to Camp Registration',
                        style: GoogleFonts.notoSans(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // IF SELECTED ACCOUNT IS AVAILABLE -> CHOOSE VERIFICATION METHOD
            Text(
              'VERIFICATION METHOD',
              style: GoogleFonts.notoSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),

            // Method 1: Aadhaar OTP
            InkWell(
              onTap: () => setState(() => _otpProvider = 'aadhaar'),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _otpProvider == 'aadhaar'
                      ? const Color(0xFFFFFBEB)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _otpProvider == 'aadhaar'
                        ? const Color(0xFFD97706)
                        : const Color(0xFFE2E8F0),
                    width: _otpProvider == 'aadhaar' ? 1.8 : 1,
                  ),
                  boxShadow: _otpProvider == 'aadhaar'
                      ? [
                          BoxShadow(
                            color: const Color(0xFFD97706).withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        color: Color(0xFFD97706),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aadhaar OTP',
                            style: GoogleFonts.notoSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'OTP sent to Aadhaar-linked phone',
                            style: GoogleFonts.notoSans(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Radio<String>(
                      value: 'aadhaar',
                      groupValue: _otpProvider,
                      activeColor: const Color(0xFFD97706),
                      onChanged: (val) {
                        if (val != null) setState(() => _otpProvider = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Method 2: ABHA / Mobile OTP
            InkWell(
              onTap: () => setState(() => _otpProvider = 'abdm'),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _otpProvider == 'abdm'
                      ? const Color(0xFFEFF6FF)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _otpProvider == 'abdm'
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFE2E8F0),
                    width: _otpProvider == 'abdm' ? 1.8 : 1,
                  ),
                  boxShadow: _otpProvider == 'abdm'
                      ? [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDBEAFE),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.smartphone_rounded,
                        color: Color(0xFF2563EB),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ABHA / Mobile OTP',
                            style: GoogleFonts.notoSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'OTP sent to ABHA-registered phone',
                            style: GoogleFonts.notoSans(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Radio<String>(
                      value: 'abdm',
                      groupValue: _otpProvider,
                      activeColor: const Color(0xFF2563EB),
                      onChanged: (val) {
                        if (val != null) setState(() => _otpProvider = val);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Send OTP Button
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF004990), Color(0xFF0066CC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF004990).withOpacity(0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSendingOtp ? null : _handleSendOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSendingOtp
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Send OTP via ${_otpProvider == 'aadhaar' ? 'Aadhaar' : 'ABHA'}',
                            style: GoogleFonts.notoSans(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  // STEP 2: ENTER & VERIFY OTP
  Widget _buildStep2VerifyOtp() {
    final accountName = _selectedAccount?['name'] ?? 'Patient';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Circular Back Button & Title
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  color: const Color(0xFF334155),
                  onPressed: () => setState(() => _mobileStep = 1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify Security OTP',
                      style: GoogleFonts.notoSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Enter the 6-digit code to complete verification',
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Context Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        color: Color(0xFF16A34A),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _otpMessage.isNotEmpty
                            ? _otpMessage
                            : 'OTP sent successfully',
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Target Account',
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      accountName,
                      style: GoogleFonts.notoSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Verification Mode',
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      _otpProvider == 'aadhaar'
                          ? 'Aadhaar Linked Mobile'
                          : 'ABHA Registered Mobile',
                      style: GoogleFonts.notoSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Main OTP Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ENTER 6-DIGIT OTP',
                  style: GoogleFonts.notoSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 12),

                // OTP Input Field
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sourceCodePro(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 18.0,
                    color: const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '------',
                    hintStyle: GoogleFonts.sourceCodePro(
                      fontSize: 26,
                      letterSpacing: 18.0,
                      color: const Color(0xFFCBD5E1),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Resend Timer Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          _cooldownSeconds > 0
                              ? 'Resend OTP in ${_cooldownSeconds}s'
                              : 'Didn’t receive the code?',
                          style: GoogleFonts.notoSans(
                            fontSize: 12.5,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: _cooldownSeconds == 0 && !_isSendingOtp
                          ? _handleSendOtp
                          : null,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Resend OTP',
                        style: GoogleFonts.notoSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _cooldownSeconds == 0
                              ? AppColors.primary
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Verify Button with Glowing Gradient
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF16A34A).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isVerifyingOtp ? null : _handleVerifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isVerifyingOtp
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline_rounded,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Verify OTP & Complete Registration',
                                style: GoogleFonts.notoSans(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  // STEP 3: SUCCESS SCREEN
  Widget _buildStep3Success() {
    final name = _selectedAccount?['name']?.toString() ?? 'Patient';
    final masked = _selectedAccount?['maskedAbhaNumber']?.toString() ?? '—';
    final gender = _selectedAccount?['gender']?.toString() ?? '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Animated Celebration Badge
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16A34A).withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF16A34A),
              size: 54,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Registration Completed!',
            style: GoogleFonts.notoSans(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Patient has been successfully verified & registered via ABHA.',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(
              fontSize: 13,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Patient Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _summaryRow('Patient Name', name, Icons.person_outline),
                const Divider(height: 20),
                _summaryRow(
                    'Mobile Number',
                    '+91 ${_searchedMobileNumber.isNotEmpty ? _searchedMobileNumber : '—'}',
                    Icons.phone_outlined),
                const Divider(height: 20),
                _summaryRow(
                    'Gender',
                    gender == 'M'
                        ? 'Male'
                        : (gender == 'F' ? 'Female' : gender),
                    Icons.badge_outlined),
                const Divider(height: 20),
                _summaryRow('ABHA Number', masked, Icons.credit_card_outlined),
                const Divider(height: 20),
                _summaryRow('ABDM Status', 'Verified & Active',
                    Icons.verified_user_outlined,
                    valueColor: const Color(0xFF16A34A)),
              ],
            ),
          ),
          const SizedBox(height: 26),

          // Action Buttons
          Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF004990), Color(0xFF0066CC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF004990).withOpacity(0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegisterPatientToCampScreen(
                      initialSearchQuery: _searchedMobileNumber.isNotEmpty
                          ? _searchedMobileNumber
                          : null,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.campaign_rounded,
                  size: 20, color: Colors.white),
              label: Text(
                'Register Patient to Camp',
                style: GoogleFonts.notoSans(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (_profileTokenId.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isLoadingCard ? null : _handleViewCard,
                icon: _isLoadingCard
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.credit_card_rounded, size: 19),
                label: Text(
                  _cardBase64.isNotEmpty
                      ? 'View ABHA Digital Card'
                      : 'Fetch & View ABHA Card',
                  style: GoogleFonts.notoSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: _resetMobileFlow,
              child: Text(
                'Register Another Patient',
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _summaryRow(String label, String value, IconData icon,
      {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.notoSans(
            fontSize: 12.5,
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.notoSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 2. MANUAL REGISTRATION FORM
  // ─────────────────────────────────────────────────────────────────────────────
  Widget _buildManualForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Demographic Card
            _formSectionCard(
              title: 'Personal Details',
              icon: Icons.person_outline,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _firstNameController,
                        label: 'First Name *',
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _lastNameController,
                        label: 'Last Name',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _ageController,
                        label: 'Age *',
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final n = int.tryParse(v);
                          if (n == null || n <= 0 || n > 120) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gender *',
                              style: GoogleFonts.notoSans(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _gender,
                                isExpanded: true,
                                items: ['Male', 'Female', 'Other']
                                    .map((g) => DropdownMenuItem(
                                          value: g,
                                          child: Text(g,
                                              style: GoogleFonts.notoSans(
                                                  fontSize: 13)),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _gender = v);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _manualMobileController,
                  label: 'Mobile Number *',
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (v.trim().length != 10) return 'Must be 10 digits';
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Identity & ABHA Card
            _formSectionCard(
              title: 'Identity Verification',
              icon: Icons.badge_outlined,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ID Type *',
                              style: GoogleFonts.notoSans(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _idType,
                                isExpanded: true,
                                items: ['AADHAAR', 'VOTER_ID', 'PAN', 'DRIVING_LICENCE']
                                    .map((t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(t,
                                              style: GoogleFonts.notoSans(
                                                  fontSize: 12)),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _idType = v);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _idValueController,
                        label: 'ID / Aadhaar Value',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Address Card
            _formSectionCard(
              title: 'Address & Location',
              icon: Icons.location_on_outlined,
              children: [
                _buildTextField(
                  controller: _addressController,
                  label: 'House / Street Address',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: _villageController,
                        label: 'City / Village',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          _buildTextField(
                            controller: _pincodeController,
                            label: 'Pincode',
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            onChanged: (val) {
                              if (val.trim().length == 6) {
                                _lookupPincode(val);
                              }
                            },
                          ),
                          if (_isLookingUpPincode)
                            const Positioned(
                              right: 12,
                              top: 32,
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('District',
                              style: GoogleFonts.notoSans(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _district,
                                isExpanded: true,
                                items: _districts
                                    .map((d) => DropdownMenuItem(
                                          value: d,
                                          child: Text(d,
                                              style: GoogleFonts.notoSans(
                                                  fontSize: 12)),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _district = v);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('State',
                              style: GoogleFonts.notoSans(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              _state,
                              style: GoogleFonts.notoSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSavingManual ? null : _submitManualPatient,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSavingManual
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Register Patient',
                        style: GoogleFonts.notoSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            if (_isManualActiveInProcess) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: _isSavingManual ? null : _resetManualForm,
                  icon: const Icon(Icons.refresh_rounded,
                      size: 16, color: Color(0xFF64748B)),
                  label: Text(
                    'Clear & Reset Form',
                    style: GoogleFonts.notoSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _formSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.notoSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          onChanged: onChanged,
          validator: validator,
          style: GoogleFonts.notoSans(fontSize: 13.5),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
