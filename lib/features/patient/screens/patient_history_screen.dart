// lib/features/patient/screens/patient_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/mobile_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/staff_app_bar.dart';
import '../../../core/widgets/staff_app_drawer.dart';
import '../../../core/widgets/staff_bottom_nav_bar.dart';
import '../../../core/widgets/patient_qr_scanner_dialog.dart';

class PatientHistoryScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final int menuId;
  final int moduleId;
  final String actionCode;

  const PatientHistoryScreen({
    super.key,
    this.onOpenDrawer,
    this.menuId = 231,
    this.moduleId = 36,
    this.actionCode = 'VIEW',
  });

  @override
  State<PatientHistoryScreen> createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen> {
  final _mrnController = TextEditingController();
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _visits = [];
  int _selectedVisitIndex = 0;

  @override
  void dispose() {
    _mrnController.dispose();
    super.dispose();
  }

  Future<void> _scanPatientQr() async {
    final scannedMrn = await PatientQrScannerScreen.scan(context);
    if (!mounted || scannedMrn == null || scannedMrn.trim().isEmpty) return;
    _searchHistory(scannedMrn.trim());
  }

  Future<void> _searchHistory([String? queryOverride]) async {
    final query = (queryOverride ?? _mrnController.text).trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please enter a valid Patient MRN to search.',
            style: GoogleFonts.notoSans(fontSize: 13),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (queryOverride != null) {
      _mrnController.text = queryOverride;
    }

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _errorMessage = null;
      _visits = [];
      _selectedVisitIndex = 0;
    });

    try {
      final res = await MobileApiService().fetchPatientHistory(
        query,
        menuId: widget.menuId,
        moduleId: widget.moduleId,
        actionCode: widget.actionCode,
      );

      debugPrint('[PatientHistoryScreen] API response: $res');

      if (!mounted) return;

      final success = res['success'] == true;
      final rawData = res['data'];

      List<Map<String, dynamic>> list = [];
      if (rawData is List) {
        list = rawData
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      setState(() {
        _isLoading = false;
        _mrnController.clear();
        if (success && list.isNotEmpty) {
          _visits = list;
          _errorMessage = null;
        } else {
          _visits = [];
          final msg = res['message']?.toString();
          _errorMessage = (msg != null && msg.trim().isNotEmpty)
              ? msg.trim()
              : 'No patient clinical history records found for MRN "$query".';
        }
      });
    } catch (e) {
      debugPrint('[PatientHistoryScreen] Error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _mrnController.clear();
          _visits = [];
          _errorMessage = 'An error occurred while loading history: $e';
        });
      }
    }
  }

  // Extract patient demographics from visits
  Map<String, dynamic>? get _patientProfile {
    if (_visits.isEmpty) return null;
    for (final v in _visits) {
      if (v['patient_info'] is Map) {
        return Map<String, dynamic>.from(v['patient_info'] as Map);
      }
    }
    return null;
  }

  Map<String, dynamic>? get _selectedVisit {
    if (_visits.isEmpty) return null;
    if (_selectedVisitIndex < 0 || _selectedVisitIndex >= _visits.length) {
      return _visits.first;
    }
    return _visits[_selectedVisitIndex];
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      final year = dt.year;
      return '$day $month $year';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = _patientProfile;
    final visit = _selectedVisit;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: const StaffAppDrawer(currentRoute: '/portal/patient-history'),
      bottomNavigationBar: const StaffBottomNavBar(currentRoute: '/portal/patient-history'),
      appBar: StaffAppBar(onOpenDrawer: widget.onOpenDrawer),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history_edu_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient Clinical History',
                        style: GoogleFonts.notoSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Search by Patient MRN only',
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // MRN Search Input Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  const Icon(Icons.badge_outlined, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _mrnController,
                      keyboardType: TextInputType.text,
                      style: GoogleFonts.notoSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter Patient MRN (e.g. 1000027)',
                        hintStyle: GoogleFonts.notoSans(
                          color: const Color(0xFF94A3B8),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _searchHistory(),
                    ),
                  ),
                  if (_mrnController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
                      onPressed: () {
                        _mrnController.clear();
                        setState(() {});
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 22, color: AppColors.primary),
                    tooltip: 'Scan Patient QR',
                    onPressed: _isLoading ? null : _scanPatientQr,
                  ),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _searchHistory(),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search_rounded, size: 18),
                    label: Text(
                      'Search',
                      style: GoogleFonts.notoSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // State 1: Loading
            if (_isLoading)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Fetching Clinical History...',
                      style: GoogleFonts.notoSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Searching patient clinical records...',
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              )

            // State 2: No Records Found / Error from Response
            else if (_hasSearched && (_visits.isEmpty || _errorMessage != null))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEA580C).withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF7ED),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_search_rounded,
                        size: 30,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No Records Found',
                      style: GoogleFonts.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF9A3412),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _errorMessage ?? 'No patient clinical history records found for this MRN.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSans(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'Tip: Verify that the MRN was entered correctly (e.g. 1000027).',
                        style: GoogleFonts.notoSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              )

            // State 3: Initial Screen Prompt (before search)
            else if (!_hasSearched)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.manage_search_rounded,
                        size: 32,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Search Patient Clinical History',
                      style: GoogleFonts.notoSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter an MRN above to retrieve the patient\'s past encounters, clinical vitals, diagnoses, refraction, and prescriptions.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSans(
                        fontSize: 12.5,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              )

            // State 4: Data Loaded Successfully
            else if (_visits.isNotEmpty) ...[
              // 1. Patient Demographics Banner Card
              if (patient != null) _buildPatientHeroCard(patient),

              const SizedBox(height: 18),

              // 2. Encounter Carousel / Pill Stepper
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CLINICAL ENCOUNTERS (${_visits.length})',
                    style: GoogleFonts.notoSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF475569),
                      letterSpacing: 0.6,
                    ),
                  ),
                  Text(
                    'Tap to view encounter details',
                    style: GoogleFonts.notoSans(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              SizedBox(
                height: 54,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _visits.length,
                  itemBuilder: (context, idx) {
                    final v = _visits[idx];
                    final isSelected = _selectedVisitIndex == idx;
                    final isFinal = (v['status']?.toString().toUpperCase() == 'FINAL');
                    final dateStr = v['letterhead']?['issued_date']?.toString() ??
                        _formatDate(v['finalised_on']?.toString() ?? v['entry_date']?.toString());
                    final rxNo = v['rx_no']?.toString() ?? 'Visit #${idx + 1}';

                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedVisitIndex = idx);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF002B49) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF002B49)
                                : const Color(0xFFCBD5E1),
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF002B49).withOpacity(0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isFinal
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFF59E0B),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  dateStr,
                                  style: GoogleFonts.notoSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  isFinal ? rxNo : 'DRAFT',
                                  style: GoogleFonts.notoSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? const Color(0xFF93C5FD)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              // 3. Selected Encounter Details
              if (visit != null) ...[
                _buildEncounterHeaderCard(visit),
                const SizedBox(height: 12),

                // Vitals Section
                if (visit['vitals'] is Map && (visit['vitals'] as Map).isNotEmpty)
                  _buildVitalsCard(Map<String, dynamic>.from(visit['vitals'] as Map)),

                const SizedBox(height: 12),

                // Chief Complaints Section
                if (visit['chief_complaints'] is Map &&
                    (visit['chief_complaints'] as Map).isNotEmpty)
                  _buildChiefComplaintsCard(
                      Map<String, dynamic>.from(visit['chief_complaints'] as Map)),

                const SizedBox(height: 12),

                // Diagnosis Section
                if (visit['diagnosis'] is List && (visit['diagnosis'] as List).isNotEmpty)
                  _buildDiagnosisCard(visit['diagnosis'] as List),

                const SizedBox(height: 12),

                // Glasses Advised Section
                if (visit['glasses_advised'] is Map &&
                    (visit['glasses_advised'] as Map).isNotEmpty)
                  _buildGlassesAdvisedCard(
                      Map<String, dynamic>.from(visit['glasses_advised'] as Map)),

                const SizedBox(height: 12),

                // Management & Referral Section
                if (visit['management'] is Map && (visit['management'] as Map).isNotEmpty)
                  _buildManagementCard(
                      Map<String, dynamic>.from(visit['management'] as Map)),

                const SizedBox(height: 12),

                // Medical & Ocular History Section
                if (visit['history'] is Map && (visit['history'] as Map).isNotEmpty)
                  _buildHistoryCard(Map<String, dynamic>.from(visit['history'] as Map)),

                const SizedBox(height: 12),

                // Doctor Notes & Digital Signature
                _buildSignatureCard(visit),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // A. Patient Hero Card
  Widget _buildPatientHeroCard(Map<String, dynamic> p) {
    final name = p['patient_name']?.toString() ?? 'Patient';
    final age = p['age']?.toString() ?? '—';
    final gender = p['gender']?.toString() ?? '—';
    final mobile = p['mobile']?.toString() ?? '—';
    final uhid = p['uhid']?.toString() ?? '—';
    final abha = p['abha_number']?.toString();
    final abhaVerified = p['abha_verified'] == true;

    // Address
    String addressStr = 'Andhra Pradesh';
    if (p['address'] is Map) {
      final addr = p['address'] as Map;
      final parts = [
        addr['line1'],
        addr['city'],
        addr['district'],
        addr['state'],
        addr['pincode'],
      ].where((e) => e != null && e.toString().trim().isNotEmpty).toList();
      if (parts.isNotEmpty) {
        addressStr = parts.join(', ');
      }
    }

    // Initials
    final initials = name.trim().split(' ').length > 1
        ? '${name.trim().split(' ')[0][0]}${name.trim().split(' ')[1][0]}'.toUpperCase()
        : name.substring(0, name.length >= 2 ? 2 : name.length).toUpperCase();

    // Collect condition badges from all visits
    final conditions = <String>[];
    for (final v in _visits) {
      final h = v['history'];
      if (h is Map) {
        if (h['allergy']?['drug_allergy'] == true) {
          final d = h['allergy']?['allergy_details'];
          conditions.add('Allergy: ${d ?? 'Yes'}');
        }
        if (h['systemic_history']?['diabetes'] == true) {
          final yrs = h['systemic_history']?['dm_since_years'];
          conditions.add(yrs != null ? 'Diabetic ${yrs}y' : 'Diabetic');
        }
        if (h['systemic_history']?['hypertension'] == true) {
          final yrs = h['systemic_history']?['htn_since_years'];
          conditions.add(yrs != null ? 'Hypertensive ${yrs}y' : 'Hypertensive');
        }
        if (h['ocular_history']?['ocular_trauma'] == true) {
          final t = h['ocular_history']?['trauma_details'];
          conditions.add('Trauma: ${t ?? 'Ocular'}');
        }
      }
    }
    final uniqueConditions = conditions.toSet().toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF002B49), Color(0xFF001B30)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF002B49).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF0284C7),
                child: Text(
                  initials,
                  style: GoogleFonts.notoSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.notoSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$age Yrs · $gender · +91 $mobile',
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.75),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                ),
                child: Text(
                  'MRN: ${p['mrn'] ?? _mrnController.text}',
                  style: GoogleFonts.notoSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF38BDF8),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 10),

          // UHID & ABHA
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.fingerprint_rounded, size: 14, color: Colors.white60),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'UHID: $uhid',
                        style: GoogleFonts.notoSans(fontSize: 11, color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (abha != null && abha.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      abhaVerified ? Icons.verified_rounded : Icons.credit_card_rounded,
                      size: 14,
                      color: abhaVerified ? const Color(0xFF4ADE80) : Colors.white60,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'ABHA: $abha',
                      style: GoogleFonts.notoSans(
                        fontSize: 11,
                        color: abhaVerified ? const Color(0xFF4ADE80) : Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          const SizedBox(height: 6),

          // Location
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Colors.white60),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  addressStr,
                  style: GoogleFonts.notoSans(fontSize: 11, color: Colors.white70),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // Conditions Badges
          if (uniqueConditions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: uniqueConditions.map((cond) {
                final isAllergy = cond.toLowerCase().contains('allergy');
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isAllergy
                        ? const Color(0xFFEF4444).withOpacity(0.2)
                        : const Color(0xFFF59E0B).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isAllergy
                          ? const Color(0xFFEF4444).withOpacity(0.4)
                          : const Color(0xFFF59E0B).withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    cond,
                    style: GoogleFonts.notoSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: isAllergy ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // B. Encounter Header & Letterhead Card
  Widget _buildEncounterHeaderCard(Map<String, dynamic> v) {
    final status = (v['status']?.toString() ?? 'FINAL').toUpperCase();
    final isFinal = status == 'FINAL';
    final rxNo = v['rx_no']?.toString();

    final lh = v['letterhead'] is Map ? v['letterhead'] as Map : {};
    final campName = lh['camp_name']?.toString() ?? v['camp_name']?.toString() ?? 'Eye Camp';
    final campAddress = lh['camp_address']?.toString() ?? '';
    final issuedDate = lh['issued_date']?.toString() ?? _formatDate(v['finalised_on']?.toString());
    final issuedTime = lh['issued_time']?.toString() ?? '';
    final clinicName = lh['clinic_name']?.toString() ?? 'Andhra Pradesh Vision Care';

    return _buildSectionCard(
      title: 'Encounter Overview & Letterhead',
      icon: Icons.assignment_outlined,
      iconColor: AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clinicName,
                      style: GoogleFonts.notoSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      campName,
                      style: GoogleFonts.notoSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isFinal ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isFinal ? const Color(0xFF86EFAC) : const Color(0xFFFDE68A),
                  ),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.notoSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isFinal ? const Color(0xFF15803D) : const Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),

          if (campAddress.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              campAddress,
              style: GoogleFonts.notoSans(fontSize: 11.5, color: const Color(0xFF64748B)),
            ),
          ],

          const Divider(height: 18),

          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              if (rxNo != null && rxNo.isNotEmpty) _infoTile('Rx Number', rxNo),
              _infoTile('Issued Date', '$issuedDate ${issuedTime.isNotEmpty ? "· $issuedTime" : ""}'),
            ],
          ),
        ],
      ),
    );
  }

  // C. Vitals Card
  Widget _buildVitalsCard(Map<String, dynamic> vitals) {
    final systolic = vitals['bp_systolic'];
    final diastolic = vitals['bp_diastolic'];
    final bp = (systolic != null && diastolic != null) ? '$systolic/$diastolic' : '—';
    final pulse = vitals['pulse_bpm']?.toString() ?? '—';
    final height = vitals['height_cm']?.toString() ?? '—';
    final weight = vitals['weight_kg']?.toString() ?? '—';
    final bmi = vitals['bmi']?.toString() ?? '—';
    final spo2 = vitals['spo2_pct']?.toString() ?? '—';
    final temp = vitals['temperature_f'] != null
        ? '${vitals['temperature_f']}°F'
        : vitals['temperature_c'] != null
            ? '${vitals['temperature_c']}°C'
            : '—';
    final recordedBy = vitals['recorded_by_name']?.toString() ?? 'Attending Staff';
    final recordedAt = _formatDate(vitals['recorded_at']?.toString());

    return _buildSectionCard(
      title: 'Clinical Vitals',
      icon: Icons.favorite_border_rounded,
      iconColor: const Color(0xFFE11D48),
      subtitle: 'Recorded by $recordedBy ($recordedAt)',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _vitalBadge('BP', bp, 'mmHg', Icons.monitor_heart_outlined, const Color(0xFFEF4444))),
              const SizedBox(width: 8),
              Expanded(child: _vitalBadge('Pulse', pulse, 'bpm', Icons.speed_rounded, const Color(0xFFF97316))),
              const SizedBox(width: 8),
              Expanded(child: _vitalBadge('SpO2', spo2, '%', Icons.air_rounded, const Color(0xFF06B6D4))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _vitalBadge('Height', height, 'cm', Icons.height_rounded, const Color(0xFF3B82F6))),
              const SizedBox(width: 8),
              Expanded(child: _vitalBadge('Weight', weight, 'kg', Icons.fitness_center_rounded, const Color(0xFF8B5CF6))),
              const SizedBox(width: 8),
              Expanded(child: _vitalBadge('BMI', bmi, 'kg/m²', Icons.accessibility_new_rounded, const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(child: _vitalBadge('Temp', temp, '', Icons.thermostat_rounded, const Color(0xFFEC4899))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vitalBadge(String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.notoSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.notoSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          if (unit.isNotEmpty)
            Text(
              unit,
              style: GoogleFonts.notoSans(
                fontSize: 9,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  // D. Chief Complaints Card
  Widget _buildChiefComplaintsCard(Map<String, dynamic> cc) {
    final complaintText = cc['complaint_text']?.toString() ??
        cc['primary_complaint_snomed_description']?.toString() ??
        'None reported';
    final onset = cc['onset']?.toString();
    final durVal = cc['duration_value']?.toString();
    final durUnit = cc['duration_unit']?.toString();
    final durationStr = (durVal != null && durUnit != null) ? '$durVal $durUnit' : null;

    // Active symptom flags
    final symptoms = <String>[];
    if (cc['symptom_flags'] is Map) {
      final flags = cc['symptom_flags'] as Map;
      flags.forEach((key, val) {
        if (val == 1 || val == true) {
          final clean = key.toString().replaceAll('_', ' ').toUpperCase();
          symptoms.add(clean);
        }
      });
    }

    return _buildSectionCard(
      title: 'Chief Complaints',
      icon: Icons.healing_outlined,
      iconColor: const Color(0xFFEA580C),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.record_voice_over_outlined, size: 18, color: Color(0xFFEA580C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  complaintText,
                  style: GoogleFonts.notoSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          if (onset != null || durationStr != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Text(
                [
                  if (onset != null) 'Onset: $onset',
                  if (durationStr != null) 'Duration: $durationStr',
                ].join(' · '),
                style: GoogleFonts.notoSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
          ],
          if (symptoms.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'ACTIVE SYMPTOM FLAGS',
              style: GoogleFonts.notoSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: symptoms.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    s,
                    style: GoogleFonts.notoSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // E. Diagnosis Card
  Widget _buildDiagnosisCard(List diagList) {
    return _buildSectionCard(
      title: 'Clinical Diagnosis (${diagList.length})',
      icon: Icons.local_hospital_outlined,
      iconColor: const Color(0xFF0284C7),
      child: Column(
        children: diagList.map((d) {
          final diag = d is Map ? d : {};
          final type = diag['type']?.toString() ?? 'PRIMARY';
          final isPrimary = type.toUpperCase() == 'PRIMARY';
          final icd10Code = diag['icd10_code']?.toString() ?? '';
          final icd10Desc = diag['icd10_desc']?.toString() ?? 'Diagnosis';
          final severity = diag['severity']?.toString();
          final laterality = diag['laterality']?.toString();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPrimary ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isPrimary ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPrimary ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    type,
                    style: GoogleFonts.notoSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        icd10Desc,
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (icd10Code.isNotEmpty) 'ICD-10: $icd10Code',
                          if (severity != null) 'Severity: $severity',
                          if (laterality != null) 'Laterality: $laterality',
                        ].join(' · '),
                        style: GoogleFonts.notoSans(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // F. Glasses Advised Card
  Widget _buildGlassesAdvisedCard(Map<String, dynamic> ga) {
    final rxType = ga['prescription_type']?.toString() ?? ga['lens_type']?.toString() ?? 'Glasses';
    final frame = ga['frame_type']?.toString() ?? 'Plastic';
    final scheme = ga['scheme_name']?.toString();
    final isFreeScheme = ga['free_glasses_scheme'] == true;

    final re = ga['re'] is Map ? ga['re'] as Map : {};
    final le = ga['le'] is Map ? ga['le'] as Map : {};

    return _buildSectionCard(
      title: 'Refraction & Glasses Advised',
      icon: Icons.visibility_outlined,
      iconColor: const Color(0xFF16A34A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Type: $rxType ($frame)',
                  style: GoogleFonts.notoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              if (scheme != null && scheme.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Text(
                    isFreeScheme ? '$scheme (Free)' : scheme,
                    style: GoogleFonts.notoSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Power Table
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    _tableCell('EYE', isHeader: true),
                    _tableCell('SPH', isHeader: true),
                    _tableCell('CYL', isHeader: true),
                    _tableCell('AXIS', isHeader: true),
                    _tableCell('ADD', isHeader: true),
                  ],
                ),
                const Divider(height: 12),
                Row(
                  children: [
                    _tableCell('RE', isBold: true, color: const Color(0xFF0284C7)),
                    _tableCell(re['sph']?.toString() ?? '0.00'),
                    _tableCell(re['cyl']?.toString() ?? '0.00'),
                    _tableCell('${re['axis'] ?? 0}°'),
                    _tableCell(re['add'] != null ? '+${re['add']}' : '—'),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _tableCell('LE', isBold: true, color: const Color(0xFF16A34A)),
                    _tableCell(le['sph']?.toString() ?? '0.00'),
                    _tableCell(le['cyl']?.toString() ?? '0.00'),
                    _tableCell('${le['axis'] ?? 0}°'),
                    _tableCell(le['add'] != null ? '+${le['add']}' : '—'),
                  ],
                ),
              ],
            ),
          ),

          if (ga['pd_distance'] != null || ga['pd_near'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Pupillary Distance: Distance: ${ga['pd_distance'] ?? '—'}mm · Near: ${ga['pd_near'] ?? '—'}mm',
              style: GoogleFonts.notoSans(fontSize: 11, color: const Color(0xFF64748B)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false, bool isBold = false, Color? color}) {
    return Expanded(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.notoSans(
          fontSize: isHeader ? 10 : 12,
          fontWeight: isHeader ? FontWeight.w800 : (isBold ? FontWeight.w800 : FontWeight.w600),
          color: color ?? (isHeader ? const Color(0xFF64748B) : const Color(0xFF0F172A)),
        ),
      ),
    );
  }

  // G. Management & Referral Card
  Widget _buildManagementCard(Map<String, dynamic> mgmt) {
    final outcome = mgmt['outcome']?.toString() ?? 'Routine';
    final isReferral = mgmt['referral_required'] == true;
    final hospital = mgmt['referral_hospital_name']?.toString();
    final dept = mgmt['referral_department_name']?.toString();
    final urgency = mgmt['referral_urgency']?.toString();
    final notes = mgmt['referral_notes']?.toString();
    final followUp = mgmt['follow_up_notes']?.toString();
    final followUpWeeks = mgmt['follow_up_weeks']?.toString();
    final referredBy = mgmt['referral_by']?.toString();

    return _buildSectionCard(
      title: 'Management & Referral',
      icon: Icons.alt_route_rounded,
      iconColor: const Color(0xFF9333EA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Outcome: $outcome',
                  style: GoogleFonts.notoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              if (urgency != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    urgency,
                    style: GoogleFonts.notoSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFB91C1C),
                    ),
                  ),
                ),
            ],
          ),

          if (isReferral && hospital != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF5FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE9D5FF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Referred to: $hospital ${dept != null ? "($dept)" : ""}',
                    style: GoogleFonts.notoSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6B21A8),
                    ),
                  ),
                  if (notes != null && notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Notes: $notes',
                      style: GoogleFonts.notoSans(
                        fontSize: 11.5,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                  if (referredBy != null && referredBy.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Referred by: $referredBy',
                      style: GoogleFonts.notoSans(
                        fontSize: 11,
                        color: const Color(0xFF7C3AED),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          if (followUp != null || followUpWeeks != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.event_repeat_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    [
                      ?followUp,
                      if (followUpWeeks != null) '($followUpWeeks weeks)',
                    ].join(' '),
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // H. Medical & Ocular History Card
  Widget _buildHistoryCard(Map<String, dynamic> h) {
    final ocular = h['ocular_history'] is Map ? h['ocular_history'] as Map : {};
    final systemic = h['systemic_history'] is Map ? h['systemic_history'] as Map : {};
    final allergy = h['allergy'] is Map ? h['allergy'] as Map : {};

    final list = <String>[];
    if (allergy['drug_allergy'] == true) {
      list.add('Drug Allergy: ${allergy['allergy_details'] ?? 'Yes'}');
    }
    if (ocular['ocular_trauma'] == true) {
      list.add('Ocular Trauma: ${ocular['trauma_details'] ?? 'Reported'}');
    }
    if (ocular['glasses_worn'] == true) list.add('Glasses Worn: Yes');
    if (ocular['previous_surgery'] == true) list.add('Prior Ocular Surgery: Yes');

    if (systemic['diabetes'] == true) list.add('Diabetes: Yes');
    if (systemic['hypertension'] == true) list.add('Hypertension: Yes');
    if (systemic['cardiac'] == true) list.add('Cardiac History: Yes');
    if (systemic['renal'] == true) list.add('Renal History: Yes');
    if (systemic['thyroid'] == true) list.add('Thyroid History: Yes');

    if (list.isEmpty) return const SizedBox.shrink();

    return _buildSectionCard(
      title: 'Medical & Ocular History',
      icon: Icons.history_rounded,
      iconColor: const Color(0xFF64748B),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF0284C7)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.notoSans(fontSize: 12, color: const Color(0xFF334155)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // I. Signature & Doctor Notes Card
  Widget _buildSignatureCard(Map<String, dynamic> v) {
    final sig = v['signature'] is Map ? v['signature'] as Map : {};
    final docNotes = v['doctor_notes'] is Map ? v['doctor_notes'] as Map : {};

    final hpi = docNotes['history_of_present_illness']?.toString();
    final clinicalFindings = docNotes['clinical_findings']?.toString();
    final treatmentPlan = docNotes['treatment_plan']?.toString();

    final docName = sig['doctor_name']?.toString() ?? 'Attending Doctor';
    final docQual = sig['qualification']?.toString() ?? 'Medical Officer';
    final regNo = sig['registration_no']?.toString();
    final signedOn = _formatDate(sig['signed_on']?.toString());
    final verifyUrl = sig['verification_url']?.toString();

    return _buildSectionCard(
      title: 'Doctor Notes & Signature',
      icon: Icons.draw_rounded,
      iconColor: const Color(0xFF0D9488),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hpi != null && hpi.isNotEmpty) ...[
            Text(
              'HISTORY OF PRESENT ILLNESS',
              style: GoogleFonts.notoSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hpi,
              style: GoogleFonts.notoSans(fontSize: 12.5, color: const Color(0xFF0F172A)),
            ),
            const Divider(height: 16),
          ],

          if (clinicalFindings != null && clinicalFindings.isNotEmpty) ...[
            Text(
              'CLINICAL FINDINGS',
              style: GoogleFonts.notoSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              clinicalFindings,
              style: GoogleFonts.notoSans(fontSize: 12.5, color: const Color(0xFF0F172A)),
            ),
            const Divider(height: 16),
          ],

          if (treatmentPlan != null && treatmentPlan.isNotEmpty) ...[
            Text(
              'TREATMENT PLAN',
              style: GoogleFonts.notoSans(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              treatmentPlan,
              style: GoogleFonts.notoSans(fontSize: 12.5, color: const Color(0xFF0F172A)),
            ),
            const Divider(height: 16),
          ],

          // Signature Box
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      docName,
                      style: GoogleFonts.notoSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      [
                        docQual,
                        if (regNo != null && regNo.isNotEmpty) 'Reg: $regNo',
                      ].join(' · '),
                      style: GoogleFonts.notoSans(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      'Signed on: $signedOn',
                      style: GoogleFonts.notoSans(
                        fontSize: 10.5,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF16A34A)),
                    const SizedBox(width: 4),
                    Text(
                      'Digitally Signed',
                      style: GoogleFonts.notoSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (verifyUrl != null && verifyUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: verifyUrl));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Verification URL copied to clipboard: $verifyUrl'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      verifyUrl,
                      style: GoogleFonts.notoSans(
                        fontSize: 11,
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.copy_rounded, size: 12, color: AppColors.primary),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Section Card Container Helper
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.notoSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.notoSans(fontSize: 11, color: const Color(0xFF94A3B8)),
            ),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.notoSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.notoSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}
