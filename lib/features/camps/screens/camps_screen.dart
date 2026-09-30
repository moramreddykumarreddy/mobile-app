// lib/features/camps/screens/camps_screen.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/services/mobile_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/staff_app_drawer.dart';

class CampsScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final int menuId;
  final int moduleId;
  final String actionCode;

  const CampsScreen({
    super.key,
    this.onOpenDrawer,
    this.menuId = 214,
    this.moduleId = 24,
    this.actionCode = 'VIEW',
  });

  @override
  State<CampsScreen> createState() => _CampsScreenState();
}

class _CampsScreenState extends State<CampsScreen> {
  // Dropdown filter: Default 'All' so camps are always visible on first load
  String _activeDropdownValue = 'All';

  // Status tabs: 'All', 'In Progress', 'Scheduled', 'Completed'
  String _selectedStatusTab = 'All';

  final _searchController = TextEditingController();
  bool _isLoading = true;

  List<Map<String, dynamic>> _allCamps = [];

  @override
  void initState() {
    super.initState();
    _loadCampsFromApi();
  }

  Future<void> _loadCampsFromApi() async {
    setState(() => _isLoading = true);
    try {
      final items = await MobileApiService().fetchCamps(
        menuId: widget.menuId,
        moduleId: widget.moduleId,
        actionCode: widget.actionCode,
        page: 1,
        limit: 100,
      );
      if (mounted) {
        setState(() {
          _allCamps = items.map((c) {
            final rawCode = c['camp_code'] ?? c['campCode'] ?? c['id'] ?? c['camp_id'];
            final codeInt = int.tryParse(rawCode?.toString() ?? '0') ?? 0;

            // "is_active": "1" or 1 -> active, "0" or 0 -> inactive
            // Use string comparison only to avoid Dart int/String equality pitfall
            final rawActive = c['is_active'] ?? c['isActive'] ?? 1;
            final String rawActiveStr = rawActive.toString().trim();
            final bool isActive = rawActiveStr == '1' || rawActiveStr == 'true';

            // Build rich location from village, mandal, district
            final locParts = [
              c['village_name'] ?? c['villageName'],
              c['mandal_name'] ?? c['mandalName'],
              c['district_name'] ?? c['districtName'] ?? c['dist_name'] ?? c['distName'],
            ].where((p) => p != null && p.toString().trim().isNotEmpty).toList();
            final locStr = locParts.isNotEmpty
                ? locParts.join(', ')
                : (c['venue_address']?.toString() ??
                    c['venueAddress']?.toString() ??
                    c['location']?.toString() ??
                    '');

            return {
              'raw': c,
              'camp_code': codeInt,
              'id': codeInt > 0 ? codeInt.toString() : (rawCode?.toString() ?? '0'),
              'name': c['camp_name']?.toString() ??
                  c['campName']?.toString() ??
                  c['name']?.toString() ??
                  'Vision Camp',
              'camp_type': c['camp_type_name']?.toString() ??
                  c['campTypeName']?.toString() ??
                  c['camp_type']?.toString() ??
                  'Community Eye Camp',
              'team': c['team_name']?.toString() ??
                  c['teamName']?.toString() ??
                  c['team']?.toString() ??
                  'Screening Unit',
              'status': c['status_name']?.toString() ??
                  c['statusName']?.toString() ??
                  c['status']?.toString() ??
                  'in_progress',
              'status_code': c['status_code'] ?? c['statusCode'],
              'is_active': isActive,
              'location': locStr,
              'date': c['scheduled_date']?.toString() ??
                  c['scheduledDate']?.toString() ??
                  c['start_date']?.toString() ??
                  c['date']?.toString() ??
                  '',
              'registered': c['registered_count'] ?? c['registeredCount'] ?? c['registered'] ?? 0,
              'screened': c['screened_count'] ?? c['screenedCount'] ?? c['screened'] ?? 0,
              'limit': c['patient_limit_count'] ??
                  c['patientLimitCount'] ??
                  c['patient_limit'] ??
                  100,
              'mandal': c['mandal_name']?.toString() ?? c['mandalName']?.toString() ?? '',
              'district': c['district_name']?.toString() ??
                  c['districtName']?.toString() ??
                  c['dist_name']?.toString() ??
                  '',
              'start_time': c['start_time']?.toString() ?? c['startTime']?.toString() ?? '',
              'end_time': c['end_time']?.toString() ?? c['endTime']?.toString() ?? '',
              'notes': c['notes']?.toString() ?? '',
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[CampsScreen] _loadCampsFromApi error: $e');
      if (mounted) {
        setState(() {
          _allCamps = [];
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

  // Active / Inactive dropdown filter + status tab + search logic
  List<Map<String, dynamic>> get _filteredCamps {
    final results = _allCamps.where((camp) {
      // camp['is_active'] is stored as bool (true/false) during _loadCampsFromApi mapping
      final bool isActive = camp['is_active'] == true;

      // 1. Dropdown filter: Active, Inactive, All
      if (_activeDropdownValue == 'Active') {
        if (!isActive) return false;
      } else if (_activeDropdownValue == 'Inactive') {
        if (isActive) return false;
      }
      // 'All' passes through

      // 2. Status tab filter: All, In Progress, Scheduled, Completed
      final s = (camp['status']?.toString() ?? '').toLowerCase();
      if (_selectedStatusTab == 'In Progress') {
        if (!s.contains('progress') && !s.contains('ongoing')) return false;
      } else if (_selectedStatusTab == 'Scheduled') {
        if (!s.contains('schedul') && !s.contains('upcom')) return false;
      } else if (_selectedStatusTab == 'Completed') {
        if (!s.contains('complet')) return false;
      }

      // 3. Search query
      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final name = (camp['name']?.toString() ?? '').toLowerCase();
        final type = (camp['camp_type']?.toString() ?? '').toLowerCase();
        final team = (camp['team']?.toString() ?? '').toLowerCase();
        final loc = (camp['location']?.toString() ?? '').toLowerCase();
        final dist = (camp['district']?.toString() ?? '').toLowerCase();
        return name.contains(query) ||
            type.contains(query) ||
            team.contains(query) ||
            loc.contains(query) ||
            dist.contains(query);
      }
      return true;
    }).toList();
    debugPrint('[CampsScreen] _filteredCamps: total=${_allCamps.length} filtered=${results.length} dropdown=$_activeDropdownValue tab=$_selectedStatusTab');
    return results;
  }

  Color _getStatusColor(String? status) {
    final s = (status ?? '').toLowerCase();
    if (s.contains('active') || s.contains('ongoing') || s.contains('progress')) {
      return const Color(0xFF16A34A);
    }
    if (s.contains('complet')) {
      return const Color(0xFF2563EB);
    }
    if (s.contains('schedul') || s.contains('upcom')) {
      return const Color(0xFFEA580C);
    }
    if (s.contains('cancel')) {
      return const Color(0xFFDC2626);
    }
    return AppColors.primary;
  }

  // Facility QR Dialog: reads real base64 string from /abha/scan-share/facility-qr
  void _openFacilityQrDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _FacilityQrDialog(
        menuId: widget.menuId,
        moduleId: widget.moduleId,
      ),
    );
  }

  // Camp QR Dialog: shows QR code containing camp_code so scanning it returns the camp code
  // Do NOT display camp code text in UI!
  void _showCampQrDialog(Map<String, dynamic> camp) {
    final rawCode = camp['camp_code'] ?? camp['id'];
    final campCodeStr = (rawCode != null && rawCode.toString() != '0' && rawCode.toString().isNotEmpty)
        ? rawCode.toString()
        : 'CAMP';
    final campName = camp['name']?.toString() ?? 'Vision Camp';
    final campType = camp['camp_type']?.toString() ?? '';
    final team = camp['team']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Camp QR Code',
                            style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Scan to identify camp',
                            style: GoogleFonts.notoSans(fontSize: 11, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  campName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                if (campType.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '$campType • $team',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSans(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: CustomPaint(
                      size: const Size(200, 200),
                      painter: QrPainter(
                        data: campCodeStr,
                        version: QrVersions.auto,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF0F172A),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Scanning this QR code provides the camp identification.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(fontSize: 11, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Camp Details Modal: shows full info without showing camp code in UI
  void _showCampDetailsModal(Map<String, dynamic> camp) {
    final status = camp['status']?.toString() ?? 'in_progress';
    final statusColor = _getStatusColor(status);
    final name = camp['name']?.toString() ?? 'Vision Camp';
    final campType = camp['camp_type']?.toString() ?? 'Community Eye Camp';
    final team = camp['team']?.toString() ?? 'Screening Unit';
    final location = camp['location']?.toString() ?? '';
    final district = camp['district']?.toString() ?? '';
    final mandal = camp['mandal']?.toString() ?? '';
    final date = camp['date']?.toString() ?? '';
    final startTime = camp['start_time']?.toString() ?? '';
    final endTime = camp['end_time']?.toString() ?? '';
    final registered = camp['registered']?.toString() ?? '0';
    final screened = camp['screened']?.toString() ?? '0';
    final limit = camp['limit']?.toString() ?? '100';
    final notes = camp['notes']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.notoSans(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            campType,
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.notoSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  children: [
                    _detailRow(Icons.medical_services_outlined, 'Camp Type', campType),
                    _detailRow(Icons.groups_outlined, 'Screening Team', team),
                    if (location.isNotEmpty)
                      _detailRow(Icons.location_on_outlined, 'Venue & Address', location),
                    if (district.isNotEmpty || mandal.isNotEmpty)
                      _detailRow(
                        Icons.map_outlined,
                        'District & Mandal',
                        '${district.isNotEmpty ? district : '-'} • ${mandal.isNotEmpty ? mandal : '-'}',
                      ),
                    if (date.isNotEmpty)
                      _detailRow(Icons.calendar_today_outlined, 'Scheduled Date', date),
                    if (startTime.isNotEmpty || endTime.isNotEmpty)
                      _detailRow(
                        Icons.access_time_rounded,
                        'Timings',
                        '${startTime.isNotEmpty ? startTime : 'Not set'} — ${endTime.isNotEmpty ? endTime : 'In Progress'}',
                      ),
                    _detailRow(
                      Icons.speed_rounded,
                      'Capacity & Limits',
                      'Limit: $limit | Screened: $screened | Registered: $registered',
                    ),
                    if (notes.isNotEmpty)
                      _detailRow(Icons.notes_rounded, 'Notes / Instructions', notes),
                  ],
                ),
              ),
              // Bottom action buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _showCampQrDialog(camp);
                        },
                        icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                        label: const Text('Show QR'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF475569),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
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
                Text(
                  value.isNotEmpty ? value : 'â€”',
                  style: GoogleFonts.notoSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

  void _showStartCampDialog(Map<String, dynamic> camp) {
    final campName = camp['name']?.toString() ?? 'Vision Camp';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF16A34A), size: 28),
            const SizedBox(width: 8),
            Text('Start Camp', style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Are you sure you want to start camp "$campName"? This will set status to Ongoing and begin the screening session.',
          style: GoogleFonts.notoSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final campCode = (camp['camp_code'] as int?) ?? 0;
              final ok = await MobileApiService().startCamp(campCode);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? '$campName started successfully' : 'Failed to start camp'),
                    backgroundColor: ok ? const Color(0xFF16A34A) : Colors.red,
                  ),
                );
                _loadCampsFromApi();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
            child: const Text('Start Now'),
          ),
        ],
      ),
    );
  }

  void _showCompleteCampDialog(Map<String, dynamic> camp) {
    final campName = camp['name']?.toString() ?? 'Vision Camp';
    final notesCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF2563EB), size: 28),
            const SizedBox(width: 8),
            Text('Complete Camp', style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Complete and close "$campName"? Enter any concluding remarks or notes below.',
              style: GoogleFonts.notoSans(fontSize: 13, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Conclusion notes (optional)...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final campCode = (camp['camp_code'] as int?) ?? 0;
              final ok = await MobileApiService().completeCamp(campCode, notes: notesCtrl.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Camp completed successfully' : 'Failed to complete camp'),
                    backgroundColor: ok ? const Color(0xFF2563EB) : Colors.red,
                  ),
                );
                _loadCampsFromApi();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Complete Camp'),
          ),
        ],
      ),
    );
  }

  void _showCancelCampDialog(Map<String, dynamic> camp) {
    final campName = camp['name']?.toString() ?? 'Vision Camp';
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 28),
            const SizedBox(width: 8),
            Text('Cancel Camp', style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a mandatory reason for cancelling camp "$campName".',
              style: GoogleFonts.notoSans(fontSize: 13, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Cancellation reason (required)...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
              final campCode = (camp['camp_code'] as int?) ?? 0;
              final ok = await MobileApiService().cancelCamp(campCode, notes: reasonCtrl.text.trim());
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Camp cancelled' : 'Failed to cancel camp'),
                    backgroundColor: ok ? const Color(0xFFDC2626) : Colors.red,
                  ),
                );
                _loadCampsFromApi();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: const StaffAppDrawer(currentRoute: '/portal/camps'),
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
            tooltip: 'Open menu (â˜°)',
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Camps',
              style: GoogleFonts.notoSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Camp Management',
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
            icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
            tooltip: 'Facility ABHA Scan & Share QR',
            onPressed: _openFacilityQrDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Refresh camps',
            onPressed: _loadCampsFromApi,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Search & Active/Inactive Dropdown Row + Status Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: [
                // Row with Search box on left and Active/Inactive Dropdown on right
                Row(
                  children: [
                    // Search box
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.notoSans(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search camps...',
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
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
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
                    ),
                    const SizedBox(width: 10),
                    // Active / Inactive Dropdown beside Searchbar
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _activeDropdownValue,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B), size: 20),
                          style: GoogleFonts.notoSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                          onChanged: (String? val) {
                            if (val != null) {
                              setState(() => _activeDropdownValue = val);
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 'Active', child: Text('Active')),
                            DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                            DropdownMenuItem(value: 'All', child: Text('All')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Status Tabs: Clean, elegant pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'In Progress', 'Scheduled', 'Completed'].map((status) {
                      final isSelected = _selectedStatusTab == status;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setState(() => _selectedStatusTab = status),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              status,
                              style: GoogleFonts.notoSans(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? Colors.white : const Color(0xFF64748B),
                              ),
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

          // Camps List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCamps.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _loadCampsFromApi,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.holiday_village_outlined, size: 48, color: Color(0xFF94A3B8)),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No ${_activeDropdownValue.toLowerCase()} camps found',
                                    style: GoogleFonts.notoSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _loadCampsFromApi,
                                    icon: const Icon(Icons.refresh_rounded, size: 16),
                                    label: const Text('Refresh Camps'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCampsFromApi,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: _filteredCamps.length,
                          itemBuilder: (context, index) {
                            final camp = _filteredCamps[index];
                            final status = camp['status']?.toString() ?? 'in_progress';
                            final statusColor = _getStatusColor(status);
                            final name = camp['name']?.toString() ?? 'Vision Camp';
                            final campType = camp['camp_type']?.toString() ?? 'Community Eye Camp';
                            final team = camp['team']?.toString() ?? 'Screening Unit';
                            final location = camp['location']?.toString() ?? '';
                            final date = camp['date']?.toString() ?? '';

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
                                    // Top Row: Status badge on left (DO NOT show camp code in UI!)
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            status,
                                            style: GoogleFonts.notoSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        if (date.isNotEmpty)
                                          Row(
                                            children: [
                                              const Icon(Icons.calendar_today_outlined,
                                                  size: 13, color: Color(0xFF94A3B8)),
                                              const SizedBox(width: 4),
                                              Text(
                                                date,
                                                style: GoogleFonts.notoSans(
                                                  fontSize: 12,
                                                  color: const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Camp Name
                                    Text(
                                      name,
                                      style: GoogleFonts.notoSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Camp Type
                                    Row(
                                      children: [
                                        const Icon(Icons.medical_services_outlined,
                                            size: 15, color: Color(0xFF64748B)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            campType,
                                            style: GoogleFonts.notoSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),

                                    // Team Name
                                    Row(
                                      children: [
                                        const Icon(Icons.groups_outlined,
                                            size: 15, color: Color(0xFF64748B)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            team,
                                            style: GoogleFonts.notoSans(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    if (location.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined,
                                              size: 15, color: Color(0xFF64748B)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              location,
                                              style: GoogleFonts.notoSans(
                                                fontSize: 12,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],

                                    const Divider(height: 24),

                                    // Action Buttons: View and QR
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _showCampDetailsModal(camp),
                                            icon: const Icon(Icons.visibility_outlined,
                                                size: 16, color: AppColors.primary),
                                            label: Text(
                                              'View',
                                              style: GoogleFonts.notoSans(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              side: const BorderSide(color: AppColors.primary),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () => _showCampQrDialog(camp),
                                            icon: const Icon(Icons.qr_code_2_rounded,
                                                size: 16, color: Colors.white),
                                            label: Text(
                                              'QR',
                                              style: GoogleFonts.notoSans(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
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
          ),
        ],
      ),
    );
  }
}
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Facility QR Dialog: Reads base64 QR from /abha/scan-share/facility-qr
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _FacilityQrDialog extends StatefulWidget {
  final int menuId;
  final int moduleId;

  const _FacilityQrDialog({
    required this.menuId,
    required this.moduleId,
  });

  @override
  State<_FacilityQrDialog> createState() => _FacilityQrDialogState();
}

class _FacilityQrDialogState extends State<_FacilityQrDialog> {
  bool _isLoading = true;
  String? _error;
  Uint8List? _qrBytes;
  String? _facilityName;

  @override
  void initState() {
    super.initState();
    _fetchQr();
  }

  Future<void> _fetchQr() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await MobileApiService().fetchFacilityQr(
        menuId: widget.menuId,
        moduleId: widget.moduleId,
      );

      if (res != null) {
        final raw = res['qrCode'] ?? res['data']?['qrCode'] ?? res['qr_code'] ?? '';
        String clean = raw.toString().trim();
        if (clean.contains(',')) {
          clean = clean.split(',').last;
        }
        clean = clean.replaceAll(RegExp(r'\s+'), '');

        if (clean.isNotEmpty) {
          final bytes = base64Decode(clean);
          if (mounted) {
            setState(() {
              _qrBytes = bytes;
              _facilityName = res['facility_name']?.toString() ??
                  res['data']?['facility_name']?.toString() ??
                  'Andhra Pradesh Vision Care';
              _isLoading = false;
            });
            return;
          }
        }
      }
      if (mounted) {
        setState(() {
          _error = 'Unable to generate Facility QR code';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[FacilityQR] decode error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load QR: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF059669)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Facility QR Code',
                        style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'ABHA Scan & Share',
                        style: GoogleFonts.notoSans(fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const SizedBox(
                height: 220,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 14),
                      Text('Loading Facility QR...',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red, size: 40),
                      const SizedBox(height: 10),
                      Text(_error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 12)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _fetchQr,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Text(
                _facilityName ?? 'Andhra Pradesh Vision Care',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _qrBytes!,
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Patients can scan this QR using ABHA / Aarogya Setu app to share health records instantly.',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSans(fontSize: 11, color: const Color(0xFF64748B)),
              ),
            ],
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
