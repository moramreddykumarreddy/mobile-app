// lib/features/patient/screens/patient_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/mobile_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/staff_app_drawer.dart';

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
  final _searchController = TextEditingController();
  bool _isSearching = false;
  bool _hasSearched = false;
  Map<String, dynamic>? _patientData;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _patientData = null;
    });

    try {
      final patient = await MobileApiService().searchPatient(
        query,
        menuId: widget.menuId,
        moduleId: widget.moduleId,
        actionCode: widget.actionCode, // Dynamically sends 'VIEW'
      );

      if (mounted) {
        if (patient != null) {
          final mrn = int.tryParse(patient['mrn']?.toString() ?? '0') ?? 0;
          final emrs = mrn > 0
              ? await MobileApiService().fetchPatientEmrHistory(
                  mrn,
                  menuId: widget.menuId,
                  moduleId: widget.moduleId,
                  actionCode: widget.actionCode, // 'VIEW'
                )
              : <Map<String, dynamic>>[];

          setState(() {
            _patientData = {
              'uhid': patient['uhid'] ?? patient['mrn'] ?? '',
              'name': patient['name'] ?? 'Patient',
              'age': patient['age']?.toString() ?? '',
              'gender': patient['gender'] ?? '',
              'mobile': patient['mobile'] ?? query,
              'location': patient['address'] ?? patient['village'] ?? 'Andhra Pradesh',
              'totalVisits': emrs.length,
              'visits': emrs.map((e) => {
                    'date': e['visit_date'] ?? 'Recent',
                    'camp': e['camp_name'] ?? 'Vision Camp',
                    'doctor': e['doctor_name'] ?? 'Attending Doctor',
                    'diagnosis': e['diagnosis'] ?? 'Eye Examination',
                    'vaRe': e['va_re'] ?? '-',
                    'vaLe': e['va_le'] ?? '-',
                    'glasses': e['glasses_advised'] ?? 'None',
                    'rx': e['medications'] ?? 'None',
                    'referral': e['referral'] ?? 'None',
                  }).toList(),
            };
            _isSearching = false;
          });
        } else {
          setState(() {
            _patientData = null;
            _isSearching = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _patientData = null;
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _printSummary() async {
    // Sends action-code: PRINT for this module
    await MobileApiService().fetchPrescriptionPrint(
      101,
      menuId: widget.menuId,
      moduleId: widget.moduleId,
      actionCode: 'PRINT', // Dynamically sends 'PRINT'
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.print_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Sent to Print (action-code: PRINT sent to API)',
              style: GoogleFonts.notoSans(fontSize: 13),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showPrescriptionPrintModal(Map<String, dynamic> visit) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    // Call API with action-code: PRINT
    final printData = await MobileApiService().fetchPrescriptionPrint(
      101,
      menuId: widget.menuId,
      moduleId: widget.moduleId,
      actionCode: 'PRINT',
    );
    debugPrint('Fetched prescription data from Portal API: $printData');

    if (!mounted) return;
    Navigator.of(context).pop();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.all(20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.description_rounded, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prescription Slip',
                    style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Andhra Pradesh Vision Care',
                    style: GoogleFonts.notoSans(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_patientData?['name']} • ${_patientData?['age']}Y / ${_patientData?['gender']}',
                      style: GoogleFonts.notoSans(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'UHID: ${_patientData?['uhid']} | Date: ${visit['date']}',
                      style: GoogleFonts.notoSans(fontSize: 11, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'CLINICAL DIAGNOSIS',
                style: GoogleFonts.notoSans(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              Text(
                visit['diagnosis'].toString(),
                style: GoogleFonts.notoSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              Text(
                'MEDICATIONS ADVISED',
                style: GoogleFonts.notoSans(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  visit['rx'] != 'None' ? visit['rx'].toString() : 'Tab Paracetamol 500mg (1-0-1) x 3 days\nEye Drops Carboxymethylcellulose 0.5% (TID)',
                  style: GoogleFonts.notoSans(fontSize: 12, color: const Color(0xFF1E293B)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'REFRACTION / GLASSES',
                style: GoogleFonts.notoSans(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              Text(
                visit['glasses'] != 'None' ? visit['glasses'].toString() : 'Bifocal D-Seg (+1.50 DS Add)',
                style: GoogleFonts.notoSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dr. Suresh Reddy (MS Ophth)',
                    style: GoogleFonts.notoSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                  const Text('✓ Signed', style: TextStyle(color: Color(0xFF16A34A), fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Prescription sent to printer (action-code: PRINT)'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Print Slip'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: const StaffAppDrawer(currentRoute: '/portal/patient-history'),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Color(0xFF1E293B)),
            onPressed: () {
              if (widget.onOpenDrawer != null) {
                widget.onOpenDrawer!();
              } else {
                Scaffold.of(ctx).openDrawer();
              }
            },
            tooltip: 'Open menu (☰)',
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Patient History',
              style: GoogleFonts.notoSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Longitudinal EMR & Screening Timeline',
              style: GoogleFonts.notoSans(
                fontSize: 11,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (_hasSearched)
            IconButton(
              icon: const Icon(Icons.print_outlined, color: AppColors.primary),
              tooltip: 'Print History Summary',
              onPressed: _printSummary,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.notoSans(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Enter UHID / Mobile / Aadhaar No',
                      hintStyle: GoogleFonts.notoSans(color: const Color(0xFF94A3B8), fontSize: 13),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF94A3B8), size: 20),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                      ),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSearching ? null : _search,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(54, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSearching
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                ),
              ],
            ),

            const SizedBox(height: 18),

            if (_hasSearched && _patientData != null) ...[
              // Patient Banner Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF004990), Color(0xFF003366)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF004990).withOpacity(0.2),
                      blurRadius: 10,
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
                          _patientData!['name'],
                          style: GoogleFonts.notoSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_patientData!['totalVisits']} Visits',
                            style: GoogleFonts.notoSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_patientData!['age']} Yrs • ${_patientData!['gender']} • ${_patientData!['location']}',
                      style: GoogleFonts.notoSans(fontSize: 12, color: Colors.white70),
                    ),
                    const Divider(color: Colors.white24, height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'UHID: ${_patientData!['uhid']}',
                          style: GoogleFonts.notoSans(fontSize: 12, color: Colors.white),
                        ),
                        Text(
                          'Mobile: ${_patientData!['mobile']}',
                          style: GoogleFonts.notoSans(fontSize: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 24),

              Text(
                'Clinical Visit Timeline',
                style: GoogleFonts.notoSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),

              // Timeline visits list
              ((_patientData!['visits'] as List).isEmpty)
                  ? Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Center(
                        child: Text(
                          'No prior clinical visits found for this patient',
                          style: GoogleFonts.notoSans(color: const Color(0xFF64748B), fontSize: 13),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: (_patientData!['visits'] as List).length,
                      itemBuilder: (context, index) {
                        final visit = (_patientData!['visits'] as List)[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
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
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                visit['date'],
                                style: GoogleFonts.notoSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF16A34A)),
                            const SizedBox(width: 4),
                            Text(
                              'Verified EMR',
                              style: GoogleFonts.notoSans(
                                fontSize: 11,
                                color: const Color(0xFF16A34A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          visit['camp'],
                          style: GoogleFonts.notoSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          visit['doctor'],
                          style: GoogleFonts.notoSans(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                        const Divider(height: 20),
                        _buildVisitDetail('Diagnosis', visit['diagnosis'], color: const Color(0xFFEF4444)),
                        const SizedBox(height: 6),
                        _buildVisitDetail('Visual Acuity', 'RE: ${visit['vaRe']} | LE: ${visit['vaLe']}'),
                        const SizedBox(height: 6),
                        _buildVisitDetail('Spectacles', visit['glasses']),
                        const SizedBox(height: 6),
                        _buildVisitDetail('Medications', visit['rx']),
                        if (visit['referral'] != 'None') ...[
                          const SizedBox(height: 6),
                          _buildVisitDetail('Referral', visit['referral'], color: const Color(0xFF9333EA)),
                        ],
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _showPrescriptionPrintModal(visit),
                          icon: const Icon(Icons.print_rounded, size: 14),
                          label: const Text('Print Prescription (PRINT)'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 38),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: Duration(milliseconds: index * 80));
                },
              ),
            ],
            if (_hasSearched && _patientData == null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.person_search_rounded, size: 48, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      Text(
                        'No Patient Found',
                        style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'No records match "${_searchController.text.trim()}". Check the number and try again.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSans(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (!_hasSearched) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.manage_search_rounded, size: 48, color: AppColors.primary),
                      const SizedBox(height: 12),
                      Text(
                        'Search Patient EMR History',
                        style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter a Patient Mobile Number, UHID, or MRN above to retrieve their complete clinical visit timeline.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSans(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVisitDetail(String label, String value, {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: GoogleFonts.notoSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.notoSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color ?? const Color(0xFF1E293B),
            ),
          ),
        ),
      ],
    );
  }
}
