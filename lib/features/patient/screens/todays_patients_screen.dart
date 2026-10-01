// lib/features/patient/screens/todays_patients_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/mobile_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/staff_app_bar.dart';
import '../../../core/widgets/staff_app_drawer.dart';
import '../../../core/widgets/staff_bottom_nav_bar.dart';

class TodaysPatientsScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final int menuId;
  final int moduleId;
  final String actionCode;

  const TodaysPatientsScreen({
    super.key,
    this.onOpenDrawer,
    this.menuId = 184,
    this.moduleId = 29,
    this.actionCode = 'VIEW',
  });

  @override
  State<TodaysPatientsScreen> createState() => _TodaysPatientsScreenState();
}

class _TodaysPatientsScreenState extends State<TodaysPatientsScreen> {
  String _selectedFilter = 'All';
  final _searchController = TextEditingController();
  bool _isLoading = true;

  List<Map<String, dynamic>> _patients = [];
  Map<String, dynamic> _counts = {'registered': 0, 'draft': 0, 'prescriptionDone': 0};

  @override
  void initState() {
    super.initState();
    _loadPatientsFromApi();
  }

  Future<void> _loadPatientsFromApi() async {
    setState(() => _isLoading = true);
    try {
      final res = await MobileApiService().fetchTodayRegisteredPatients(
        menuId: widget.menuId,
        moduleId: widget.moduleId,
        actionCode: widget.actionCode,
      );
      if (mounted) {
        setState(() {
          if (res['success'] == true && res['patients'] is List) {
            final list = res['patients'] as List;
            if (res['counts'] is Map) {
              _counts = Map<String, dynamic>.from(res['counts']);
            }
            _patients = list.map((p) {
              final rawStatus = p['status']?.toString() ?? 'Registered';
              return {
                'raw': p,
                'visitId': p['visitId'] ?? p['visit_id'] ?? 101,
                'emrId': p['emrId'] ?? p['emr_id'] ?? 101,
                'token': p['token_no']?.toString() ?? p['token']?.toString() ?? 'T-01',
                'uhid': p['uhid']?.toString() ?? p['mrn']?.toString() ?? 'APVC-000',
                'name': p['name']?.toString() ?? p['fullName']?.toString() ?? p['patient_name']?.toString() ?? 'Patient',
                'age': p['age']?.toString() ?? '',
                'gender': p['gender']?.toString() ?? '',
                'mobile': p['mobile']?.toString() ?? '',
                'status': rawStatus,
                'vaRe': p['va_re']?.toString() ?? '6/6',
                'vaLe': p['va_le']?.toString() ?? '6/9',
                'chiefComplaints': p['chief_complaints']?.toString() ?? 'Diminution of vision',
                'diagnosis': p['diagnosis']?.toString() ?? 'Refractive Error',
              };
            }).toList();
          } else {
            _patients = [];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _patients = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredPatients {
    return _patients.where((p) {
      if (_selectedFilter != 'All') {
        final s = p['status'].toString().toLowerCase();
        final f = _selectedFilter.toLowerCase();
        if (!s.contains(f) && !f.contains(s)) return false;
      }
      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final name = p['name'].toString().toLowerCase();
        final token = p['token'].toString().toLowerCase();
        final uhid = p['uhid'].toString().toLowerCase();
        final mobile = p['mobile'].toString().toLowerCase();
        return name.contains(query) || token.contains(query) || uhid.contains(query) || mobile.contains(query);
      }
      return true;
    }).toList();
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('prescription') || s.contains('done') || s.contains('complete') || s.contains('final')) {
      return const Color(0xFF16A34A);
    }
    if (s.contains('draft') || s.contains('revert')) {
      return const Color(0xFFEA580C);
    }
    return const Color(0xFF0284C7);
  }

  void _openEmrModal(Map<String, dynamic> patient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EmrConsultationSheet(
        patient: patient,
        menuId: widget.menuId,
        moduleId: widget.moduleId,
        onRefreshNeeded: _loadPatientsFromApi,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: const StaffAppDrawer(currentRoute: '/portal/patients'),
      bottomNavigationBar: const StaffBottomNavBar(currentRoute: '/portal/patients'),
      appBar: StaffAppBar(onOpenDrawer: widget.onOpenDrawer),
      body: Column(
        children: [
          // Header Stats Badges
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildStatPill('Registered', '${_counts['registered'] ?? _patients.length}', const Color(0xFF004990)),
                    const SizedBox(width: 8),
                    _buildStatPill('Draft EMR', '${_counts['draft'] ?? 0}', const Color(0xFFEA580C)),
                    const SizedBox(width: 8),
                    _buildStatPill('Prescriptions', '${_counts['prescriptionDone'] ?? 0}', const Color(0xFF16A34A)),
                  ],
                ),
                const SizedBox(height: 10),
                // Search box
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.notoSans(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by token, name, UHID, mobile...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Status Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Registered', 'Draft', 'Prescription Done'].map((status) {
                      final isSelected = _selectedFilter == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedFilter = status);
                          },
                          selectedColor: AppColors.primary,
                          backgroundColor: const Color(0xFFF1F5F9),
                          labelStyle: GoogleFonts.notoSans(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF64748B),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Patients List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadPatientsFromApi,
              color: AppColors.primary,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredPatients.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.people_outline_rounded, size: 48, color: Color(0xFF94A3B8)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No registered patients found',
                                    style: GoogleFonts.notoSans(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                        itemCount: _filteredPatients.length,
                        itemBuilder: (context, index) {
                          final patient = _filteredPatients[index];
                          final statusColor = _getStatusColor(patient['status']);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                            color: Colors.white,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _openEmrModal(patient),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            patient['token'],
                                            style: GoogleFonts.notoSans(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                patient['name'],
                                                style: GoogleFonts.notoSans(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF0F172A),
                                                ),
                                              ),
                                              Text(
                                                '${patient['age']} Yrs • ${patient['gender']} • ${patient['uhid']}',
                                                style: GoogleFonts.notoSans(fontSize: 11, color: const Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            patient['status'],
                                            style: GoogleFonts.notoSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: statusColor,
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
                                          'VA: RE ${patient['vaRe']} | LE ${patient['vaLe']}',
                                          style: GoogleFonts.notoSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF334155),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              'Open EMR Sheet',
                                              style: GoogleFonts.notoSans(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.primary),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ).animate().fadeIn(delay: Duration(milliseconds: index * 40));
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: GoogleFonts.notoSans(fontSize: 10, fontWeight: FontWeight.w600, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMR CONSULTATION BOTTOM SHEET WITH ACTIVE TABS & ACTION BUTTONS
// ─────────────────────────────────────────────────────────────────────────────
class _EmrConsultationSheet extends StatefulWidget {
  final Map<String, dynamic> patient;
  final int menuId;
  final int moduleId;
  final VoidCallback onRefreshNeeded;

  const _EmrConsultationSheet({
    required this.patient,
    required this.menuId,
    required this.moduleId,
    required this.onRefreshNeeded,
  });

  @override
  State<_EmrConsultationSheet> createState() => _EmrConsultationSheetState();
}

class _EmrConsultationSheetState extends State<_EmrConsultationSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Chief Complaints controllers
  String _primaryComplaint = 'Diminution of vision';
  String _complaintDuration = '3';
  String _complaintUnit = 'MONTHS';
  final String _complaintOnset = 'GRADUAL';

  // Diagnosis controllers
  final _diagController = TextEditingController(text: 'Refractive Error (Presbyopia)');
  String _eyeSide = 'BOTH';

  // Rx controllers
  final _drugNameController = TextEditingController(text: 'Carboxymethylcellulose 0.5% Drops');
  String _frequency = '1-0-1';
  final _durationDaysController = TextEditingController(text: '15');
  final _instructionsController = TextEditingController(text: '1 drop in both eyes');

  // Doctor Notes
  final _notesController = TextEditingController(text: 'Patient counseled for spectacle wear. Review after 6 months.');

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _diagController.dispose();
    _drugNameController.dispose();
    _durationDaysController.dispose();
    _instructionsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _emrId => (widget.patient['emrId'] is int) ? widget.patient['emrId'] : 101;

  Future<void> _saveComplaints() async {
    setState(() => _isSaving = true);
    final ok = await MobileApiService().saveChiefComplaints(
      _emrId,
      [
        {
          'primary_complaint': _primaryComplaint,
          'duration_value': int.tryParse(_complaintDuration) ?? 1,
          'duration_unit': _complaintUnit,
          'onset': _complaintOnset,
        }
      ],
      menuId: widget.menuId,
      moduleId: widget.moduleId,
      actionCode: 'CHIEF_COMPLAINTS',
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Chief Complaints saved (CHIEF_COMPLAINTS)' : 'Failed to save complaints'),
        backgroundColor: ok ? const Color(0xFF16A34A) : Colors.red,
      ),
    );
  }

  Future<void> _saveDiagnosis() async {
    setState(() => _isSaving = true);
    final ok = await MobileApiService().saveDiagnoses(
      _emrId,
      [
        {
          'diagnosis_name': _diagController.text.trim(),
          'eye_side': _eyeSide,
          'icd10_code': 'H52.4',
        }
      ],
      menuId: widget.menuId,
      moduleId: widget.moduleId,
      actionCode: 'DIAGNOSIS',
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Diagnosis saved (DIAGNOSIS)' : 'Failed to save diagnosis'),
        backgroundColor: ok ? const Color(0xFF16A34A) : Colors.red,
      ),
    );
  }

  Future<void> _prescribeRx() async {
    setState(() => _isSaving = true);
    final ok = await MobileApiService().prescribeMedication(
      _emrId,
      {
        'drug_name': _drugNameController.text.trim(),
        'frequency': _frequency,
        'duration_days': int.tryParse(_durationDaysController.text.trim()) ?? 7,
        'instructions': _instructionsController.text.trim(),
      },
      menuId: widget.menuId,
      moduleId: widget.moduleId,
      actionCode: 'RX',
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Medication prescribed (RX)' : 'Failed to prescribe medication'),
        backgroundColor: ok ? const Color(0xFF16A34A) : Colors.red,
      ),
    );
  }

  Future<void> _saveNotes() async {
    setState(() => _isSaving = true);
    final ok = await MobileApiService().saveDoctorNotes(
      _emrId,
      _notesController.text.trim(),
      menuId: widget.menuId,
      moduleId: widget.moduleId,
      actionCode: 'DOCTOR_NOTES',
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Doctor Notes saved (DOCTOR_NOTES)' : 'Failed to save notes'),
        backgroundColor: ok ? const Color(0xFF16A34A) : Colors.red,
      ),
    );
  }

  void _showRevertEmrDialog() {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.replay_rounded, color: Color(0xFFEA580C), size: 28),
            const SizedBox(width: 8),
            Text('Revert EMR to Draft', style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reverting this EMR unlocks all clinical sections for editing. Please enter a mandatory reason.',
              style: GoogleFonts.notoSans(fontSize: 13, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Reason for revert (required)...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              final ok = await MobileApiService().revertEmr(
                _emrId,
                reasonCtrl.text.trim(),
                menuId: widget.menuId,
                moduleId: widget.moduleId,
                actionCode: 'REVERT_EMR',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'EMR reverted to Draft (REVERT_EMR)' : 'Failed to revert EMR'),
                    backgroundColor: ok ? const Color(0xFFEA580C) : Colors.red,
                  ),
                );
                widget.onRefreshNeeded();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
            child: const Text('Confirm Revert'),
          ),
        ],
      ),
    );
  }

  void _printPrescription() async {
    await MobileApiService().fetchPrescriptionPrint(
      _emrId,
      menuId: widget.menuId,
      moduleId: widget.moduleId,
      actionCode: 'PRINT',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prescription sent to printer (action-code: PRINT)'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle & Patient Banner Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${p['name']} (${p['token']})',
                          style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'UHID: ${p['uhid']} • ${p['age']}Y / ${p['gender']}',
                          style: GoogleFonts.notoSans(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // EMR Tabs matching Action Codes
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.notoSans(fontSize: 13, fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: 'Complaints'),
              Tab(text: 'Diagnosis'),
              Tab(text: 'Medications (Rx)'),
              Tab(text: 'Doctor Notes'),
            ],
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Chief Complaints (CHIEF_COMPLAINTS)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      Text('Primary Chief Complaint *', style: GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _primaryComplaint,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          'Diminution of vision',
                          'Eye strain / Headache',
                          'Watering from eyes',
                          'Redness and Irritation',
                          'Foreign body sensation',
                          'Itching / Allergic symptoms',
                        ].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                        onChanged: (v) => setState(() => _primaryComplaint = v ?? _primaryComplaint),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Duration Value', style: GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  initialValue: _complaintDuration,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  onChanged: (v) => _complaintDuration = v,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Unit', style: GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: _complaintUnit,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  items: ['DAYS', 'WEEKS', 'MONTHS', 'YEARS']
                                      .map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13))))
                                      .toList(),
                                  onChanged: (v) => setState(() => _complaintUnit = v ?? _complaintUnit),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveComplaints,
                        icon: const Icon(Icons.save_rounded, size: 16),
                        label: const Text('Save Chief Complaints (CHIEF_COMPLAINTS)'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                ),

                // Tab 2: Diagnosis (DIAGNOSIS)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      Text('Clinical Diagnosis *', style: GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _diagController,
                        decoration: InputDecoration(
                          hintText: 'e.g. Presbyopia, Cataract, Glaucoma',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Affected Eye Side *', style: GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _eyeSide,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: [
                          DropdownMenuItem(value: 'BOTH', child: Text('Both Eyes (OU)')),
                          DropdownMenuItem(value: 'RIGHT', child: Text('Right Eye (OD)')),
                          DropdownMenuItem(value: 'LEFT', child: Text('Left Eye (OS)')),
                        ],
                        onChanged: (v) => setState(() => _eyeSide = v ?? _eyeSide),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveDiagnosis,
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text('Save Diagnosis (DIAGNOSIS)'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                ),

                // Tab 3: Rx & Medications (RX)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      Text('Drug / Eye Drop Name *', style: GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _drugNameController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Frequency', style: GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: _frequency,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                  items: ['1-0-1', '1-1-1', '1-0-0', '0-0-1', 'TID', 'QID']
                                      .map((f) => DropdownMenuItem(value: f, child: Text(f, style: const TextStyle(fontSize: 13))))
                                      .toList(),
                                  onChanged: (v) => setState(() => _frequency = v ?? _frequency),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Days', style: GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 13)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _durationDaysController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Instructions / Remarks', style: GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _instructionsController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _prescribeRx,
                        icon: const Icon(Icons.medication_rounded, size: 16),
                        label: const Text('Prescribe Medication (RX)'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                ),

                // Tab 4: Doctor Notes (DOCTOR_NOTES)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    children: [
                      Text('Clinical & Doctor Notes *', style: GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Enter clinical observations, surgical advice or follow-up instructions...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveNotes,
                        icon: const Icon(Icons.note_alt_rounded, size: 16),
                        label: const Text('Save Doctor Notes (DOCTOR_NOTES)'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Workflow Action Row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _showRevertEmrDialog,
                  icon: const Icon(Icons.replay_rounded, size: 16, color: Color(0xFFEA580C)),
                  label: const Text('Revert (REVERT_EMR)', style: TextStyle(color: Color(0xFFEA580C))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFEA580C)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _printPrescription,
                  icon: const Icon(Icons.print_rounded, color: AppColors.primary),
                  tooltip: 'Print Prescription (PRINT)',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onRefreshNeeded();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Done Consultation'),
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
