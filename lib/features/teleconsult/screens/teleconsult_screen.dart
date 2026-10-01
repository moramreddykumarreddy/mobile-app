// lib/features/teleconsult/screens/teleconsult_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/mobile_api_service.dart';
import '../../../core/services/session_menu_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/staff_app_bar.dart';
import '../../../core/widgets/staff_app_drawer.dart';
import '../../../core/widgets/staff_bottom_nav_bar.dart';

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
  final _searchController = TextEditingController();
  String _selectedStatusTab = 'All';
  bool _isLoading = true;

  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessionsFromApi();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSessionsFromApi() async {
    setState(() => _isLoading = true);
    try {
      final dynMenu =
          SessionMenuService().getMenuForRoute('/portal/teleconsult');
      final effectiveModuleId = dynMenu?.moduleId ?? widget.moduleId;
      final effectiveMenuId = dynMenu?.menuId ?? widget.menuId;

      final list = await MobileApiService().fetchTeleconsultSessions(
        menuId: effectiveMenuId,
        moduleId: effectiveModuleId,
        actionCode: widget.actionCode,
      );

      if (mounted) {
        setState(() {
          _sessions = list.map((s) {
            final id =
                s['id']?.toString() ?? s['session_id']?.toString() ?? '';
            final patientMap =
                s['patient'] is Map ? s['patient'] as Map : null;
            final patientName = (patientMap?['name'] ??
                    s['patient_name'] ??
                    s['patientName'] ??
                    'Patient')
                .toString()
                .trim();
            final doctorName = (s['doctorName'] ??
                    s['doctor_name'] ??
                    s['ophthalmologist_name'] ??
                    'Specialist Ophthalmologist')
                .toString()
                .trim();
            final campName = (s['campName'] ??
                    s['camp_name'] ??
                    'Primary Eye Camp')
                .toString()
                .trim();

            final rawStatus =
                (s['status'] ?? 'scheduled').toString().toLowerCase().trim();
            String normalizedStatus = 'Scheduled';
            if (rawStatus == 'active' ||
                rawStatus.contains('active') ||
                rawStatus.contains('call') ||
                rawStatus.contains('in_progress')) {
              normalizedStatus = 'Live Active';
            } else if (rawStatus == 'completed' ||
                rawStatus.contains('complete')) {
              normalizedStatus = 'Completed';
            } else if (rawStatus == 'cancelled' ||
                rawStatus.contains('cancel')) {
              normalizedStatus = 'Cancelled';
            } else {
              normalizedStatus = 'Scheduled';
            }

            final roomId = (s['roomId'] ?? s['room_id'] ?? '').toString();
            final meetingUrl = roomId.startsWith('http://') ||
                    roomId.startsWith('https://')
                ? roomId
                : (roomId.isNotEmpty ? 'https://meet.jit.si/$roomId' : '');

            return {
              'raw': s,
              'id': id,
              'patientName': patientName,
              'doctorName': doctorName.startsWith('Dr.')
                  ? doctorName
                  : 'Dr. $doctorName',
              'campName': campName,
              'status': normalizedStatus,
              'rawStatus': rawStatus,
              'roomId': roomId,
              'meetingUrl': meetingUrl,
              'webrtcToken': (s['webrtcToken'] ??
                      s['webrtc_token'] ??
                      s['token'] ??
                      '')
                  .toString(),
              'scheduledAt': (s['scheduledAt'] ?? s['scheduled_at'] ?? '')
                  .toString(),
              'startedAt':
                  (s['startedAt'] ?? s['started_at'] ?? '').toString(),
              'endedAt': (s['endedAt'] ?? s['ended_at'] ?? '').toString(),
              'clinicalNotes': (s['clinicalNotes'] ??
                      s['clinical_notes'] ??
                      s['notes'] ??
                      '')
                  .toString()
                  .trim(),
              'diagnosis': (s['diagnosis'] ?? '').toString().trim(),
              'followUpRequired': s['followUpRequired'] == true ||
                  s['follow_up_required'] == true,
              'followUpDate':
                  (s['followUpDate'] ?? s['follow_up_date'] ?? '').toString(),
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('TeleconsultationScreen error: $e');
      if (mounted) {
        setState(() {
          _sessions = [];
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredSessions {
    return _sessions.where((s) {
      // 1. Status Filter Tab
      if (_selectedStatusTab != 'All') {
        if (s['status'] != _selectedStatusTab) return false;
      }

      // 2. Search query
      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final pName = s['patientName'].toString().toLowerCase();
        final dName = s['doctorName'].toString().toLowerCase();
        final cName = s['campName'].toString().toLowerCase();
        final diag = s['diagnosis'].toString().toLowerCase();
        final notes = s['clinicalNotes'].toString().toLowerCase();
        return pName.contains(query) ||
            dName.contains(query) ||
            cName.contains(query) ||
            diag.contains(query) ||
            notes.contains(query);
      }
      return true;
    }).toList();
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final year = dt.year;
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year, $hour:$minute $ampm';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Live Active':
        return const Color(0xFF16A34A);
      case 'Scheduled':
        return const Color(0xFFD97706);
      case 'Completed':
        return const Color(0xFF2563EB);
      case 'Cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'Live Active':
        return const Color(0xFFDCFCE7);
      case 'Scheduled':
        return const Color(0xFFFEF3C7);
      case 'Completed':
        return const Color(0xFFDBEAFE);
      case 'Cancelled':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ACTION 1: JOIN CALL & TELECONSULTATION ROOM
  // ─────────────────────────────────────────────────────────────────────────────
  Future<void> _handleJoinCall(Map<String, dynamic> session) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    Map<String, dynamic>? joinCredentials;
    try {
      final dynMenu =
          SessionMenuService().getMenuForRoute('/portal/teleconsult');
      joinCredentials = await MobileApiService().joinTeleconsultSession(
        session['id'].toString(),
        menuId: dynMenu?.menuId ?? widget.menuId,
        moduleId: dynMenu?.moduleId ?? widget.moduleId,
        actionCode: 'START',
      );
    } catch (e) {
      debugPrint('Join API call error: $e');
    }

    if (mounted) Navigator.of(context).pop(); // dismiss loading

    final roomFromApi = joinCredentials?['roomId']?.toString() ??
        joinCredentials?['room_id']?.toString();
    final effectiveRoom = (roomFromApi != null && roomFromApi.isNotEmpty)
        ? roomFromApi
        : session['meetingUrl'].toString();

    // Mark as Live Active locally
    setState(() {
      session['status'] = 'Live Active';
    });

    if (!mounted) return;

    // Open Call Room Sheet
    _openTeleconsultRoomSheet(session, effectiveRoom);
  }

  void _openTeleconsultRoomSheet(
      Map<String, dynamic> session, String meetingUrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LiveCallRoomSheet(
        session: session,
        meetingUrl: meetingUrl,
        onComplete: () {
          Navigator.of(ctx).pop();
          _showCompleteConsultationDialog(session);
        },
        onCancel: () {
          Navigator.of(ctx).pop();
          _showCancelConsultationDialog(session);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ACTION 2: COMPLETE CONSULTATION (with Diagnosis, Notes, Follow-up)
  // ─────────────────────────────────────────────────────────────────────────────
  void _showCompleteConsultationDialog(Map<String, dynamic> session) {
    final diagCtrl = TextEditingController(
      text: session['diagnosis'].toString().isNotEmpty
          ? session['diagnosis']
          : '',
    );
    final notesCtrl = TextEditingController(
      text: session['clinicalNotes'].toString().isNotEmpty
          ? session['clinicalNotes']
          : '',
    );
    bool followUp = session['followUpRequired'] == true;
    DateTime selectedFollowUpDate =
        DateTime.now().add(const Duration(days: 14));
    bool isSubmitting = false;

    final quickDiagnoses = [
      'Presbyopia',
      'Cataract (Senile)',
      'Refractive Error',
      'Glaucoma Suspect',
      'Diabetic Retinopathy',
      'Allergic Conjunctivitis',
      'Pterygium',
      'Normal Vision',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 14),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF16A34A),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Complete Consultation',
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Patient: ${session['patientName']} • ${session['doctorName']}',
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
                const Divider(height: 24),

                // Diagnosis input
                Text(
                  'Diagnosis *',
                  style: GoogleFonts.notoSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: diagCtrl,
                  style: GoogleFonts.notoSans(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'e.g. Cataract, Presbyopia, Glaucoma...',
                    hintStyle: GoogleFonts.notoSans(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Quick Diagnosis Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: quickDiagnoses.map((d) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(
                            d,
                            style: GoogleFonts.notoSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF475569),
                            ),
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          onPressed: () {
                            setModalState(() => diagCtrl.text = d);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),

                // Clinical Notes
                Text(
                  'Clinical Consultation Notes *',
                  style: GoogleFonts.notoSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  style: GoogleFonts.notoSans(fontSize: 13),
                  decoration: InputDecoration(
                    hintText:
                        'Enter clinical impressions, treatment advice, and prescription notes...',
                    hintStyle: GoogleFonts.notoSans(
                      fontSize: 12.5,
                      color: const Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Follow-up required switch
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: Color(0xFF0284C7),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Follow-up Review Required',
                                style: GoogleFonts.notoSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: followUp,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setModalState(() => followUp = val);
                            },
                          ),
                        ],
                      ),
                      if (followUp) ...[
                        const Divider(height: 12),
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: modalCtx,
                              initialDate: selectedFollowUpDate,
                              firstDate: DateTime.now(),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setModalState(
                                  () => selectedFollowUpDate = picked);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Follow-up Date:',
                                  style: GoogleFonts.notoSans(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Text(
                                    '${selectedFollowUpDate.year}-${selectedFollowUpDate.month.toString().padLeft(2, '0')}-${selectedFollowUpDate.day.toString().padLeft(2, '0')}',
                                    style: GoogleFonts.notoSans(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Submit Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting
                            ? null
                            : () => Navigator.of(modalCtx).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final diag = diagCtrl.text.trim();
                                final notes = notesCtrl.text.trim();
                                if (diag.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('Please specify a diagnosis'),
                                      backgroundColor: Color(0xFFDC2626),
                                    ),
                                  );
                                  return;
                                }
                                if (notes.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Please enter clinical consultation notes'),
                                      backgroundColor: Color(0xFFDC2626),
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);
                                final followUpDateStr = followUp
                                    ? '${selectedFollowUpDate.year}-${selectedFollowUpDate.month.toString().padLeft(2, '0')}-${selectedFollowUpDate.day.toString().padLeft(2, '0')}'
                                    : null;

                                final dynMenu = SessionMenuService()
                                    .getMenuForRoute('/portal/teleconsult');
                                final ok = await MobileApiService()
                                    .completeTeleconsultSession(
                                  session['id'].toString(),
                                  diagnosis: diag,
                                  clinicalNotes: notes,
                                  followUpRequired: followUp,
                                  followUpDate: followUpDateStr,
                                  menuId: dynMenu?.menuId ?? widget.menuId,
                                  moduleId:
                                      dynMenu?.moduleId ?? widget.moduleId,
                                  actionCode: 'COMPLETE',
                                );

                                if (modalCtx.mounted) {
                                  Navigator.of(modalCtx).pop();
                                }

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok
                                          ? 'Consultation marked as completed successfully!'
                                          : 'Failed to complete session on server'),
                                      backgroundColor: ok
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFFDC2626),
                                    ),
                                  );
                                  _loadSessionsFromApi();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Complete Consultation'),
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
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ACTION 3: CANCEL CONSULTATION (with Mandatory Remarks)
  // ─────────────────────────────────────────────────────────────────────────────
  void _showCancelConsultationDialog(Map<String, dynamic> session) {
    final reasonCtrl = TextEditingController();
    bool isSubmitting = false;

    final quickReasons = [
      'Patient Not Available',
      'Technical / Network Issue',
      'Rescheduled by Doctor',
      'Duplicate Booking',
      'Patient Opted Out',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 14),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cancel_outlined,
                        color: Color(0xFFDC2626),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cancel Teleconsultation',
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Are you sure you want to cancel the session for ${session['patientName']}?',
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
                const Divider(height: 24),

                Text(
                  'Reason for Cancellation *',
                  style: GoogleFonts.notoSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 2,
                  style: GoogleFonts.notoSans(fontSize: 13),
                  decoration: InputDecoration(
                    hintText:
                        'Please state the reason for session cancellation...',
                    hintStyle: GoogleFonts.notoSans(
                      fontSize: 12.5,
                      color: const Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Quick Reason Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: quickReasons.map((r) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(
                            r,
                            style: GoogleFonts.notoSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                          backgroundColor: const Color(0xFFFEF2F2),
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          onPressed: () {
                            setModalState(() => reasonCtrl.text = r);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 18),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting
                            ? null
                            : () => Navigator.of(modalCtx).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final reason = reasonCtrl.text.trim();
                                if (reason.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Please enter a cancellation reason'),
                                      backgroundColor: Color(0xFFDC2626),
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isSubmitting = true);
                                final dynMenu = SessionMenuService()
                                    .getMenuForRoute('/portal/teleconsult');
                                final ok = await MobileApiService()
                                    .cancelTeleconsultSession(
                                  session['id'].toString(),
                                  remarks: reason,
                                  menuId: dynMenu?.menuId ?? widget.menuId,
                                  moduleId:
                                      dynMenu?.moduleId ?? widget.moduleId,
                                  actionCode: 'CANCEL',
                                );

                                if (modalCtx.mounted) {
                                  Navigator.of(modalCtx).pop();
                                }

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok
                                          ? 'Session cancelled successfully'
                                          : 'Failed to cancel session'),
                                      backgroundColor: ok
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFFDC2626),
                                    ),
                                  );
                                  _loadSessionsFromApi();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Confirm Cancel'),
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
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ACTION 4: VIEW FULL SESSION DETAILS
  // ─────────────────────────────────────────────────────────────────────────────
  void _showSessionDetails(Map<String, dynamic> session) {
    final statusColor = _getStatusColor(session['status']);
    final statusBgColor = _getStatusBgColor(session['status']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
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

            // Patient Name & Status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session['patientName'],
                        style: GoogleFonts.notoSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session['campName'],
                        style: GoogleFonts.notoSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    session['status'],
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            Expanded(
              child: ListView(
                children: [
                  _detailRow(
                    Icons.medical_services_outlined,
                    'Specialist Doctor',
                    session['doctorName'],
                    AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    Icons.location_on_outlined,
                    'Camp Venue',
                    session['campName'],
                    const Color(0xFFD97706),
                  ),
                  const SizedBox(height: 12),
                  _detailRow(
                    Icons.schedule_rounded,
                    'Scheduled Time',
                    _formatDateTime(session['scheduledAt']),
                    const Color(0xFF64748B),
                  ),
                  if (session['startedAt'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _detailRow(
                      Icons.play_circle_outline_rounded,
                      'Started Time',
                      _formatDateTime(session['startedAt']),
                      const Color(0xFF16A34A),
                    ),
                  ],
                  if (session['endedAt'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _detailRow(
                      Icons.stop_circle_outlined,
                      'Ended Time',
                      _formatDateTime(session['endedAt']),
                      const Color(0xFFDC2626),
                    ),
                  ],
                  if (session['diagnosis'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _detailRow(
                      Icons.assignment_outlined,
                      'Diagnosis',
                      session['diagnosis'],
                      const Color(0xFF0284C7),
                    ),
                  ],
                  if (session['clinicalNotes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _detailRow(
                      Icons.notes_rounded,
                      'Clinical Notes',
                      session['clinicalNotes'],
                      const Color(0xFF475569),
                    ),
                  ],
                  if (session['followUpRequired'] == true) ...[
                    const SizedBox(height: 12),
                    _detailRow(
                      Icons.event_repeat_rounded,
                      'Follow-up Required',
                      session['followUpDate'].toString().isNotEmpty
                          ? 'Date: ${session['followUpDate']}'
                          : 'Yes',
                      const Color(0xFFEA580C),
                    ),
                  ],
                  if (session['meetingUrl'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _detailRowWithAction(
                      Icons.video_call_outlined,
                      'Video Call Room',
                      session['meetingUrl'],
                      AppColors.primary,
                      onTap: () {
                        Clipboard.setData(
                            ClipboardData(text: session['meetingUrl']));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Video Room link copied to clipboard!'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
      IconData icon, String label, String value, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.notoSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.notoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRowWithAction(
      IconData icon, String label, String value, Color iconColor,
      {required VoidCallback onTap}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.notoSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.notoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: 'Copy Link',
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BUILD METHOD
  // ─────────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: const StaffAppDrawer(currentRoute: '/portal/teleconsult'),
      bottomNavigationBar:
          const StaffBottomNavBar(currentRoute: '/portal/teleconsult'),
      appBar: StaffAppBar(onOpenDrawer: widget.onOpenDrawer),
      body: Column(
        children: [
          // Top Search & Status Tabs Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: [
                // Full-width Search Box
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.notoSans(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search patient, doctor, camp, diagnosis...',
                    hintStyle: GoogleFonts.notoSans(
                      color: const Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Color(0xFF94A3B8),
                    ),
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
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
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
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Status Tabs Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      'All',
                      'Scheduled',
                      'Live Active',
                      'Completed',
                      'Cancelled'
                    ].map((status) {
                      final isSelected = _selectedStatusTab == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () =>
                              setState(() => _selectedStatusTab = status),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (status == 'Live Active') ...[
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF16A34A),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                ],
                                Text(
                                  status,
                                  style: GoogleFonts.notoSans(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Consultation Cards List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSessions.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _loadSessionsFromApi,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height:
                                  MediaQuery.of(context).size.height * 0.18,
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.video_camera_back_outlined,
                                    size: 48,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No ${_selectedStatusTab == 'All' ? '' : '${_selectedStatusTab.toLowerCase()} '}teleconsultations found',
                                    style: GoogleFonts.notoSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _loadSessionsFromApi,
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 16),
                                    label: const Text('Refresh Sessions'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 36),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSessionsFromApi,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                          itemCount: _filteredSessions.length,
                          itemBuilder: (context, index) {
                            final session = _filteredSessions[index];
                            final status = session['status'] as String;
                            final statusColor = _getStatusColor(status);
                            final statusBgColor = _getStatusBgColor(status);
                            final isScheduled = status == 'Scheduled';
                            final isLiveActive = status == 'Live Active';
                            final isCompleted = status == 'Completed';
                            final isCancelled = status == 'Cancelled';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0)),
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
                                    // Row 1: Status Badge & Scheduled Time
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusBgColor,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (isLiveActive) ...[
                                                Container(
                                                  width: 7,
                                                  height: 7,
                                                  decoration:
                                                      const BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Color(0xFF16A34A),
                                                  ),
                                                ),
                                                const SizedBox(width: 5),
                                              ],
                                              Text(
                                                status,
                                                style: GoogleFonts.notoSans(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: statusColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.access_time_rounded,
                                              size: 13,
                                              color: Color(0xFF94A3B8),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatDateTime(
                                                  session['scheduledAt']),
                                              style: GoogleFonts.notoSans(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Row 2: Patient Name & Details
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: AppColors.primary
                                              .withOpacity(0.12),
                                          child: const Icon(
                                            Icons.person_rounded,
                                            color: AppColors.primary,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                session['patientName'],
                                                style: GoogleFonts.notoSans(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      const Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.location_on_outlined,
                                                    size: 14,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Expanded(
                                                    child: Text(
                                                      session['campName'],
                                                      style:
                                                          GoogleFonts.notoSans(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: const Color(
                                                            0xFF475569),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Row 3: Ophthalmologist Specialist Card
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 7),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.medical_services_outlined,
                                            size: 15,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Doctor: ',
                                            style: GoogleFonts.notoSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              session['doctorName'],
                                              style: GoogleFonts.notoSans(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF0F172A),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Clinical Notes / Diagnosis / Remarks preview (if available)
                                    if (session['diagnosis']
                                            .toString()
                                            .isNotEmpty ||
                                        session['clinicalNotes']
                                            .toString()
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isCancelled
                                              ? const Color(0xFFFEF2F2)
                                              : (isCompleted
                                                  ? const Color(0xFFF0FDF4)
                                                  : const Color(0xFFF8FAFC)),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isCancelled
                                                ? const Color(0xFFFECACA)
                                                : (isCompleted
                                                    ? const Color(0xFFBBF7D0)
                                                    : const Color(0xFFE2E8F0)),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (session['diagnosis']
                                                .toString()
                                                .isNotEmpty) ...[
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.assignment_outlined,
                                                    size: 14,
                                                    color: Color(0xFF0284C7),
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Text(
                                                    'Diagnosis: ',
                                                    style: GoogleFonts.notoSans(
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: const Color(
                                                          0xFF0284C7),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Text(
                                                      session['diagnosis'],
                                                      style:
                                                          GoogleFonts.notoSans(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: const Color(
                                                            0xFF0F172A),
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 3),
                                            ],
                                            if (session['clinicalNotes']
                                                .toString()
                                                .isNotEmpty) ...[
                                              Text(
                                                session['clinicalNotes'],
                                                style: GoogleFonts.notoSans(
                                                  fontSize: 11.5,
                                                  fontStyle: isCancelled
                                                      ? FontStyle.italic
                                                      : FontStyle.normal,
                                                  color: isCancelled
                                                      ? const Color(0xFFDC2626)
                                                      : const Color(0xFF475569),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            if (session['followUpRequired'] ==
                                                true) ...[
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.event_repeat_rounded,
                                                    size: 13,
                                                    color: Color(0xFFEA580C),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    session['followUpDate']
                                                            .toString()
                                                            .isNotEmpty
                                                        ? 'Follow-up on ${session['followUpDate']}'
                                                        : 'Follow-up Required',
                                                    style: GoogleFonts.notoSans(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: const Color(
                                                          0xFFEA580C),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],

                                    const Divider(height: 20),

                                    // Action Buttons Row (Contextual per status)
                                    if (isScheduled || isLiveActive) ...[
                                      Row(
                                        children: [
                                          // 1. Join Call Button (RED/CRIMSON PRIMARY CTA matching Portal)
                                          Expanded(
                                            flex: 3,
                                            child: ElevatedButton.icon(
                                              onPressed: () =>
                                                  _handleJoinCall(session),
                                              icon: const Icon(
                                                Icons.videocam_rounded,
                                                size: 16,
                                              ),
                                              label: Text(
                                                isLiveActive
                                                    ? 'Enter Room'
                                                    : 'Join Call',
                                                style: GoogleFonts.notoSans(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFFDC2626), // Portal red CTA
                                                foregroundColor: Colors.white,
                                                minimumSize:
                                                    const Size(0, 38),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                elevation: 0,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 10),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // 2. Complete Button
                                          Expanded(
                                            flex: 3,
                                            child: OutlinedButton.icon(
                                              onPressed: () =>
                                                  _showCompleteConsultationDialog(
                                                      session),
                                              icon: const Icon(
                                                Icons.check_circle_outline,
                                                size: 15,
                                                color: Color(0xFF16A34A),
                                              ),
                                              label: Text(
                                                'Complete',
                                                style: GoogleFonts.notoSans(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color:
                                                      const Color(0xFF16A34A),
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    const Color(0xFF16A34A),
                                                side: const BorderSide(
                                                    color: Color(0xFF86EFAC)),
                                                backgroundColor:
                                                    const Color(0xFFF0FDF4),
                                                minimumSize:
                                                    const Size(0, 38),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),

                                          // 3. Cancel Button
                                          IconButton(
                                            onPressed: () =>
                                                _showCancelConsultationDialog(
                                                    session),
                                            icon: const Icon(
                                              Icons.cancel_outlined,
                                              size: 20,
                                              color: Color(0xFFDC2626),
                                            ),
                                            tooltip: 'Cancel Consultation',
                                            style: IconButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFFEF2F2),
                                              padding: const EdgeInsets.all(8),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),

                                          // 4. View Details Info
                                          IconButton(
                                            onPressed: () =>
                                                _showSessionDetails(session),
                                            icon: const Icon(
                                              Icons.info_outline_rounded,
                                              size: 20,
                                              color: Color(0xFF64748B),
                                            ),
                                            tooltip: 'View Details',
                                            style: IconButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFF1F5F9),
                                              padding: const EdgeInsets.all(8),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      // Completed or Cancelled: Full width View Summary
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _showSessionDetails(session),
                                          icon: const Icon(
                                            Icons.visibility_outlined,
                                            size: 16,
                                          ),
                                          label: Text(
                                            isCompleted
                                                ? 'View Completed Summary'
                                                : 'View Cancellation Details',
                                            style: GoogleFonts.notoSans(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                            minimumSize: const Size(0, 38),
                                            side: const BorderSide(
                                                color: Color(0xFFCBD5E1)),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 250.ms)
                                .slideY(begin: 0.04);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE CALL ROOM SHEET (WITH DURATION TIMER & ACTION SHORTCUTS)
// ─────────────────────────────────────────────────────────────────────────────
class _LiveCallRoomSheet extends StatefulWidget {
  final Map<String, dynamic> session;
  final String meetingUrl;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const _LiveCallRoomSheet({
    required this.session,
    required this.meetingUrl,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<_LiveCallRoomSheet> createState() => _LiveCallRoomSheetState();
}

class _LiveCallRoomSheetState extends State<_LiveCallRoomSheet> {
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatCallTimer(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 16),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Teleconsultation In Call',
                    style: GoogleFonts.notoSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatCallTimer(_seconds),
                  style: GoogleFonts.notoSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),

          // Patient & Doctor Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      child: const Icon(Icons.person,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.session['patientName'],
                            style: GoogleFonts.notoSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            widget.session['campName'],
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
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
                Row(
                  children: [
                    const Icon(Icons.medical_services_outlined,
                        size: 16, color: Color(0xFF0284C7)),
                    const SizedBox(width: 8),
                    Text(
                      'Doctor: ',
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        widget.session['doctorName'],
                        style: GoogleFonts.notoSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Meeting Link & Copy
          if (widget.meetingUrl.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam_outlined,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.meetingUrl,
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: const Color(0xFF334155),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: widget.meetingUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Meeting room link copied to clipboard!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.copy_rounded,
                              size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'Copy',
                            style: GoogleFonts.notoSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
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

          const Spacer(),

          // Complete consultation CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onComplete,
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: Text(
                'Complete Consultation',
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Cancel or End Call Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Cancel Consultation'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF475569),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Leave Room'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
