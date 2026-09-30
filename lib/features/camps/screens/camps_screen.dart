// lib/features/camps/screens/camps_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
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
  String _selectedFilter = 'All';
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
            
            // Build rich location from village, mandal, district
            final locParts = [
              c['village_name'] ?? c['villageName'],
              c['mandal_name'] ?? c['mandalName'],
              c['district_name'] ?? c['districtName'] ?? c['dist_name'] ?? c['distName'],
            ].where((p) => p != null && p.toString().trim().isNotEmpty).toList();
            final locStr = locParts.isNotEmpty
                ? locParts.join(', ')
                : (c['venue_address']?.toString() ?? c['venueAddress']?.toString() ?? c['location']?.toString() ?? 'Andhra Pradesh');

            return {
              'raw': c,
              'id': codeInt > 0 ? codeInt.toString() : (rawCode?.toString() ?? '0'),
              'camp_code': codeInt,
              'name': c['camp_name']?.toString() ?? c['campName']?.toString() ?? c['name']?.toString() ?? 'Vision Camp',
              'location': locStr,
              'date': c['scheduled_date']?.toString() ?? c['scheduledDate']?.toString() ?? c['start_date']?.toString() ?? c['date']?.toString() ?? 'Today',
              'status': c['status_name']?.toString() ?? c['statusName']?.toString() ?? c['status']?.toString() ?? 'Ongoing',
              'status_code': c['status_code'] ?? c['statusCode'],
              'registered': c['registered_count'] ?? c['registeredCount'] ?? c['registered'] ?? 0,
              'screened': c['screened_count'] ?? c['screenedCount'] ?? c['screened'] ?? 0,
              'limit': c['patient_limit_count'] ?? c['patientLimitCount'] ?? c['patient_limit'] ?? 100,
              'team': c['team_name']?.toString() ?? c['teamName']?.toString() ?? c['team']?.toString() ?? 'Screening Unit',
              'mandal': c['mandal_name']?.toString() ?? c['mandalName']?.toString() ?? '',
              'district': c['district_name']?.toString() ?? c['districtName']?.toString() ?? c['dist_name']?.toString() ?? '',
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

  List<Map<String, dynamic>> get _filteredCamps {
    return _allCamps.where((camp) {
      if (_selectedFilter != 'All') {
        final s = camp['status'].toString().toLowerCase();
        final f = _selectedFilter.toLowerCase();
        if (!s.contains(f) && !f.contains(s)) return false;
      }
      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final name = camp['name'].toString().toLowerCase();
        final loc = camp['location'].toString().toLowerCase();
        final id = camp['id'].toString().toLowerCase();
        final dist = camp['district'].toString().toLowerCase();
        return name.contains(query) || loc.contains(query) || id.contains(query) || dist.contains(query);
      }
      return true;
    }).toList();
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
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

  void _openFacilityQrDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final res = await MobileApiService().fetchFacilityQr(
      menuId: widget.menuId,
      moduleId: widget.moduleId,
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
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
              child: Text(
                'ABHA Scan & Share QR',
                style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, size: 140, color: Color(0xFF0F172A)),
                  const SizedBox(height: 8),
                  Text(
                    'Facility QR Code Active',
                    style: GoogleFonts.notoSans(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    res?['facility_name']?.toString() ?? 'Andhra Pradesh Vision Care',
                    style: GoogleFonts.notoSans(fontSize: 11, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Patients can scan this QR using ABHA / Aarogya Setu app to share health records instantly.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(fontSize: 11, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCampDetailsModal(Map<String, dynamic> camp) {
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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camp['name'],
                        style: GoogleFonts.notoSans(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Camp Code: #${camp['id']}',
                        style: GoogleFonts.notoSans(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(camp['status']).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    camp['status'],
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _getStatusColor(camp['status']),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: ListView(
                children: [
                  _detailRow(Icons.location_on_outlined, 'Venue & Address', camp['location']),
                  _detailRow(Icons.map_outlined, 'District & Mandal', '${camp['district']} • ${camp['mandal']}'),
                  _detailRow(Icons.calendar_today_outlined, 'Scheduled Date', camp['date']),
                  _detailRow(Icons.access_time_rounded, 'Timings',
                      '${camp['start_time'].isNotEmpty ? camp['start_time'] : 'Not Started'} — ${camp['end_time'].isNotEmpty ? camp['end_time'] : 'In Progress'}'),
                  _detailRow(Icons.groups_outlined, 'Screening Team', camp['team']),
                  _detailRow(Icons.speed_rounded, 'Capacity & Limits',
                      'Limit: ${camp['limit']} | Screened: ${camp['screened']} | Registered: ${camp['registered']}'),
                  if (camp['notes'].toString().isNotEmpty)
                    _detailRow(Icons.notes_rounded, 'Notes / Instructions', camp['notes']),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close'),
            ),
          ],
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
                  style: GoogleFonts.notoSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                ),
                Text(
                  value.isNotEmpty ? value : '—',
                  style: GoogleFonts.notoSans(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStartCampDialog(Map<String, dynamic> camp) {
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
          'Are you sure you want to start camp "${camp['name']}"? This will set status to Ongoing and begin the screening session.',
          style: GoogleFonts.notoSans(fontSize: 13, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final campCode = camp['camp_code'] as int;
              final ok = await MobileApiService().startCamp(campCode);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Camp #${camp['id']} started successfully' : 'Failed to start camp'),
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
              'Complete and close "${camp['name']}"? Enter any concluding remarks or notes below.',
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
              final campCode = camp['camp_code'] as int;
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
              'Please provide a mandatory reason for cancelling camp "${camp['name']}".',
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
              final campCode = camp['camp_code'] as int;
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
            child: const Text('Cancel Camp'),
          ),
        ],
      ),
    );
  }

  void _showUpdateLimitDialog(Map<String, dynamic> camp) {
    final limitCtrl = TextEditingController(text: camp['limit'].toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.tune_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 8),
            Text('Update Patient Limit', style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Adjust the max patient limit for "${camp['name']}":',
                style: GoogleFonts.notoSans(fontSize: 13, color: const Color(0xFF475569))),
            const SizedBox(height: 12),
            TextField(
              controller: limitCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Patient Limit Count',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newLimit = int.tryParse(limitCtrl.text.trim()) ?? 0;
              if (newLimit <= 0) return;
              Navigator.of(ctx).pop();
              final campCode = camp['camp_code'] as int;
              final ok = await MobileApiService().updatePatientLimit(campCode, newLimit);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Limit updated to $newLimit' : 'Failed to update limit')),
                );
                _loadCampsFromApi();
              }
            },
            child: const Text('Save Limit'),
          ),
        ],
      ),
    );
  }

  void _showCreateCampDialog() {
    final nameCtrl = TextEditingController();
    final venueCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '100');
    final dateCtrl = TextEditingController(text: DateTime.now().toIso8601String().substring(0, 10));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('New Vision Camp', style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Camp Name *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: venueCtrl,
                decoration: const InputDecoration(labelText: 'Venue / Address *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dateCtrl,
                decoration: const InputDecoration(labelText: 'Scheduled Date (YYYY-MM-DD) *'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: limitCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Patient Limit *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              final payload = {
                'camp_name': nameCtrl.text.trim(),
                'venue_address': venueCtrl.text.trim(),
                'scheduled_date': dateCtrl.text.trim(),
                'patient_limit_count': int.tryParse(limitCtrl.text.trim()) ?? 100,
                'camp_type_code': 1,
                'dist_code': 500,
                'district_name': 'Guntur',
                'mandal_code': 'M-01',
                'mandal_name': 'Guntur Rural',
                'team_code': 1,
              };
              final res = await MobileApiService().createCamp(payload);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res != null ? 'Camp created successfully' : 'Failed to create camp'),
                    backgroundColor: res != null ? const Color(0xFF16A34A) : Colors.red,
                  ),
                );
                _loadCampsFromApi();
              }
            },
            child: const Text('Create Camp'),
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
            tooltip: 'Open menu (☰)',
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
            tooltip: 'Refresh /camps (VIEW)',
            onPressed: _loadCampsFromApi,
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateCampDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'New Camp',
          style: GoogleFonts.notoSans(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                // Search box
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.notoSans(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search camps by name, venue, code, district...',
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
                const SizedBox(height: 12),
                // Status Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Ongoing', 'Scheduled', 'Completed', 'Cancelled'].map((status) {
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
                                    'No camps found',
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
                          final statusColor = _getStatusColor(camp['status']);
                          final isOngoing = camp['status'].toString().toLowerCase().contains('ongoing') ||
                              camp['status'].toString().toLowerCase().contains('active');
                          final isScheduled = camp['status'].toString().toLowerCase().contains('schedul') ||
                              camp['status'].toString().toLowerCase().contains('upcom');

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
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          camp['status'],
                                          style: GoogleFonts.notoSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: statusColor,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Camp #${camp['id']}',
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
                                    camp['name'],
                                    style: GoogleFonts.notoSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_outlined, size: 15, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          camp['location'],
                                          style: GoogleFonts.notoSans(
                                            fontSize: 13,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(
                                        camp['date'],
                                        style: GoogleFonts.notoSans(
                                          fontSize: 12,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          camp['team'],
                                          style: GoogleFonts.notoSans(
                                            fontSize: 12,
                                            color: const Color(0xFF64748B),
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
                                        'Reg: ${camp['registered']}',
                                        style: GoogleFonts.notoSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        'Screened: ${camp['screened']}',
                                        style: GoogleFonts.notoSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF16A34A),
                                        ),
                                      ),
                                      Text(
                                        'Limit: ${camp['limit']}',
                                        style: GoogleFonts.notoSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Action Buttons matching portal
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _showCampDetailsModal(camp),
                                        icon: const Icon(Icons.visibility_outlined, size: 14),
                                        label: const Text('View'),
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        ),
                                      ),
                                      if (isScheduled)
                                        ElevatedButton.icon(
                                          onPressed: () => _showStartCampDialog(camp),
                                          icon: const Icon(Icons.play_arrow_rounded, size: 14),
                                          label: const Text('Start'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF16A34A),
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          ),
                                        ),
                                      if (isOngoing)
                                        ElevatedButton.icon(
                                          onPressed: () => _showCompleteCampDialog(camp),
                                          icon: const Icon(Icons.check_rounded, size: 14),
                                          label: const Text('Complete'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF2563EB),
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          ),
                                        ),
                                      OutlinedButton.icon(
                                        onPressed: () => _showUpdateLimitDialog(camp),
                                        icon: const Icon(Icons.tune_rounded, size: 14),
                                        label: const Text('Limit'),
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        ),
                                      ),
                                      if (!camp['status'].toString().toLowerCase().contains('cancel') &&
                                          !camp['status'].toString().toLowerCase().contains('complet'))
                                        OutlinedButton.icon(
                                          onPressed: () => _showCancelCampDialog(camp),
                                          icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFDC2626)),
                                          label: const Text('Cancel', style: TextStyle(color: Color(0xFFDC2626))),
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
          ),
        ],
      ),
    );
  }
}
