// lib/features/teleconsult/screens/teleconsult_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/mobile_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/staff_app_drawer.dart';

class TeleconsultationScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final int menuId;
  final int moduleId;
  final String actionCode;

  const TeleconsultationScreen({
    super.key,
    this.onOpenDrawer,
    this.menuId = 269,
    this.moduleId = 45,
    this.actionCode = 'VIEW',
  });

  @override
  State<TeleconsultationScreen> createState() => _TeleconsultationScreenState();
}

class _TeleconsultationScreenState extends State<TeleconsultationScreen> {
  String _selectedFilter = 'All';
  bool _isLoading = true;

  List<Map<String, dynamic>> _consultations = [];

  @override
  void initState() {
    super.initState();
    _loadSessionsFromApi();
  }

  Future<void> _loadSessionsFromApi() async {
    setState(() => _isLoading = true);
    try {
      final list = await MobileApiService().fetchTeleconsultSessions(
        menuId: widget.menuId,
        moduleId: widget.moduleId,
        actionCode: widget.actionCode,
      );
      if (mounted) {
        setState(() {
          _consultations = list.map((s) {
            final rawStatus = s['status']?.toString() ?? 'Waiting';
            String normalizedStatus = 'Waiting';
            final ls = rawStatus.toLowerCase();
            if (ls.contains('active') || ls.contains('call') || ls.contains('in_progress')) {
              normalizedStatus = 'In Call';
            } else if (ls.contains('complete')) {
              normalizedStatus = 'Completed';
            } else if (ls.contains('cancel')) {
              normalizedStatus = 'Cancelled';
            }

            return {
              'raw': s,
              'id': s['id']?.toString() ?? s['session_id']?.toString() ?? 'TC-01',
              'patientName': s['patient_name']?.toString() ?? s['patient']?['name']?.toString() ?? 'Patient',
              'mrn': s['patient_mrn']?.toString() ?? s['mrn']?.toString() ?? '101',
              'age': s['age']?.toString() ?? '45',
              'gender': s['gender']?.toString() ?? 'M',
              'doctorName': s['doctor_name']?.toString() ?? s['ophthalmologist_name']?.toString() ?? 'Dr. Suresh Reddy',
              'camp': s['camp_name']?.toString() ?? 'Vision Camp',
              'optometrist': s['optometrist_name']?.toString() ?? 'Staff Optometrist',
              'status': normalizedStatus,
              'scheduledAt': s['scheduled_at']?.toString() ?? s['scheduledAt']?.toString() ?? 'Today',
              'va': s['va']?.toString() ?? '6/6',
              'notes': s['clinical_notes']?.toString() ?? s['notes']?.toString() ?? '',
              'diagnosis': s['diagnosis']?.toString() ?? '',
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _consultations = [];
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_selectedFilter == 'All') return _consultations;
    return _consultations.where((c) => c['status'] == _selectedFilter).toList();
  }

  void _showSessionDetails(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['patientName'], style: GoogleFonts.notoSans(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('MRN: ${item['mrn']} • Session #${item['id']}', style: GoogleFonts.notoSans(fontSize: 12, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(item['status']).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item['status'],
                    style: GoogleFonts.notoSans(fontSize: 12, fontWeight: FontWeight.w700, color: _getStatusColor(item['status'])),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _infoRow(Icons.person_outline, 'Ophthalmologist', item['doctorName']),
            const SizedBox(height: 10),
            _infoRow(Icons.holiday_village_outlined, 'Camp Venue', item['camp']),
            const SizedBox(height: 10),
            _infoRow(Icons.schedule_rounded, 'Scheduled Time', item['scheduledAt']),
            const SizedBox(height: 10),
            _infoRow(Icons.remove_red_eye_outlined, 'Visual Acuity', item['va']),
            if (item['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              _infoRow(Icons.notes_rounded, 'Clinical Notes', item['notes']),
            ],
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text('$label: ', style: GoogleFonts.notoSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
        Expanded(child: Text(value, style: GoogleFonts.notoSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)))),
      ],
    );
  }

  void _startCall(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFF3E8FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.video_call_rounded, color: Color(0xFF9333EA), size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Connecting Teleconsultation',
              style: GoogleFonts.notoSans(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Initiating secure WebRTC video room with ${item['doctorName']} for ${item['patientName']}...',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      setState(() => item['status'] = 'In Call');
                      await MobileApiService().joinTeleconsultSession(
                        item['id'].toString(),
                        menuId: widget.menuId,
                        moduleId: widget.moduleId,
                        actionCode: 'START',
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Teleconsultation Call connected (action-code: START)'),
                          backgroundColor: Color(0xFF16A34A),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9333EA)),
                    child: const Text('Join Call'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _completeConsultation(Map<String, dynamic> item) {
    final notesCtrl = TextEditingController();
    final diagCtrl = TextEditingController(text: 'Presbyopia / Refractive Error');
    bool followUp = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 26),
              const SizedBox(width: 8),
              Text('Complete Session', style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Diagnosis *', style: GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 4),
                TextField(
                  controller: diagCtrl,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Doctor Clinical Notes *', style: GoogleFonts.notoSans(fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 4),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Enter clinical impressions and advised treatment...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: followUp,
                  onChanged: (v) => setModalState(() => followUp = v ?? false),
                  title: Text('Follow-up Review Required', style: GoogleFonts.notoSans(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(ctx).pop();
                setState(() => item['status'] = 'Completed');
                await MobileApiService().completeTeleconsultSession(
                  item['id'].toString(),
                  notes: notesCtrl.text.trim(),
                  menuId: widget.menuId,
                  moduleId: widget.moduleId,
                  actionCode: 'COMPLETE',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Teleconsultation completed (action-code: COMPLETE)'),
                      backgroundColor: Color(0xFF16A34A),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
              child: const Text('Complete'),
            ),
          ],
        ),
      ),
    );
  }

  void _cancelConsultation(Map<String, dynamic> item) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 26),
            const SizedBox(width: 8),
            Text('Cancel Session', style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter reason for cancelling session with ${item['patientName']}:',
                style: GoogleFonts.notoSans(fontSize: 13, color: const Color(0xFF475569))),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Cancellation reason (required)...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Back')),
          ElevatedButton(
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              setState(() => item['status'] = 'Cancelled');
              await MobileApiService().cancelTeleconsultSession(
                item['id'].toString(),
                reason: reasonCtrl.text.trim(),
                menuId: widget.menuId,
                moduleId: widget.moduleId,
                actionCode: 'CANCEL',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Session cancelled (action-code: CANCEL)'),
                    backgroundColor: Color(0xFFDC2626),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Cancel Session'),
          ),
        ],
      ),
    );
  }

  void _showScheduleSessionDialog() {
    final mrnCtrl = TextEditingController();
    final doctorCtrl = TextEditingController(text: 'Dr. Suresh Reddy');
    final dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 16));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.video_call_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Schedule Teleconsult', style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: mrnCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Patient MRN *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: doctorCtrl,
                decoration: const InputDecoration(labelText: 'Ophthalmologist *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(labelText: 'Scheduled At (YYYY-MM-DDTHH:mm) *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (mrnCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              final ok = await MobileApiService().scheduleTeleconsultSession(
                {
                  'emrId': int.tryParse(mrnCtrl.text.trim()) ?? 101,
                  'ophthalmologistId': 'DOC-01',
                  'scheduledAt': dateCtrl.text.trim(),
                },
                menuId: widget.menuId,
                moduleId: widget.moduleId,
                actionCode: 'ADD',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Teleconsult session scheduled (ADD)' : 'Failed to schedule session'),
                    backgroundColor: ok ? const Color(0xFF16A34A) : Colors.red,
                  ),
                );
                _loadSessionsFromApi();
              }
            },
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'In Call':
        return const Color(0xFF16A34A);
      case 'Waiting':
        return const Color(0xFFEA580C);
      case 'Completed':
        return const Color(0xFF2563EB);
      case 'Cancelled':
        return const Color(0xFFDC2626);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: const StaffAppDrawer(currentRoute: '/portal/teleconsult'),
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
              'Teleconsultation',
              style: GoogleFonts.notoSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Tele-Ophthalmology Video Hub',
              style: GoogleFonts.notoSans(
                fontSize: 11,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Refresh /teleconsult/sessions (VIEW)',
            onPressed: _loadSessionsFromApi,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showScheduleSessionDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.video_call_rounded, color: Colors.white),
        label: Text(
          'Schedule Call (ADD)',
          style: GoogleFonts.notoSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['All', 'Waiting', 'In Call', 'Completed', 'Cancelled'].map((status) {
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
          ),

          // Consultation Cards List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.video_camera_back_outlined, size: 48, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            Text(
                              'No teleconsultations found',
                              style: GoogleFonts.notoSans(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final item = _filtered[index];
                          final statusColor = _getStatusColor(item['status']);
                          final isWaiting = item['status'] == 'Waiting';
                          final isInCall = item['status'] == 'In Call';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item['status'],
                                          style: GoogleFonts.notoSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Session #${item['id']}',
                                        style: GoogleFonts.notoSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    item['patientName'],
                                    style: GoogleFonts.notoSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item['age']} Yrs • ${item['gender']} • MRN: ${item['mrn']}',
                                    style: GoogleFonts.notoSans(fontSize: 12, color: const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Doctor: ${item['doctorName']}',
                                          style: GoogleFonts.notoSans(fontSize: 12, color: const Color(0xFF475569), fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.holiday_village_outlined, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          item['camp'],
                                          style: GoogleFonts.notoSans(fontSize: 12, color: const Color(0xFF64748B)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  // Action Buttons matching portal
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _showSessionDetails(item),
                                        icon: const Icon(Icons.visibility_outlined, size: 14),
                                        label: const Text('View (VIEW)'),
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        ),
                                      ),
                                      if (isWaiting)
                                        ElevatedButton.icon(
                                          onPressed: () => _startCall(item),
                                          icon: const Icon(Icons.videocam_rounded, size: 14),
                                          label: const Text('Join Call (START)'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF9333EA),
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          ),
                                        ),
                                      if (isInCall)
                                        ElevatedButton.icon(
                                          onPressed: () => _completeConsultation(item),
                                          icon: const Icon(Icons.check_rounded, size: 14),
                                          label: const Text('Complete (COMPLETE)'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF16A34A),
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          ),
                                        ),
                                      if (isWaiting || isInCall)
                                        OutlinedButton.icon(
                                          onPressed: () => _cancelConsultation(item),
                                          icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFDC2626)),
                                          label: const Text('Cancel (CANCEL)', style: TextStyle(color: Color(0xFFDC2626))),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Color(0xFFDC2626)),
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(duration: 250.ms);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
