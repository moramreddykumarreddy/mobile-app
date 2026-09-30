// lib/features/camps/screens/live_camp_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/mobile_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/staff_app_drawer.dart';

class LiveCampScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final int menuId;
  final int moduleId;
  final String actionCode;

  const LiveCampScreen({
    super.key,
    this.onOpenDrawer,
    this.menuId = 255,
    this.moduleId = 43,
    this.actionCode = 'VIEW',
  });

  @override
  State<LiveCampScreen> createState() => _LiveCampScreenState();
}

class _LiveCampScreenState extends State<LiveCampScreen> {
  String? _selectedCamp;
  bool _isLoading = true;

  List<String> _camps = [];

  Map<String, dynamic> _metrics = {
    'registered': 0,
    'screened': 0,
    'inConsultation': 0,
    'glassesAdvised': 0,
    'cataractReferred': 0,
  };

  List<Map<String, dynamic>> _liveQueue = [];

  @override
  void initState() {
    super.initState();
    _loadLiveDashboard();
  }

  Future<void> _loadLiveDashboard() async {
    setState(() => _isLoading = true);
    try {
      final dropdown = await MobileApiService().fetchCampsDropdown(
        menuId: widget.menuId,
        moduleId: widget.moduleId,
        actionCode: widget.actionCode,
      );
      if (mounted && dropdown.isNotEmpty) {
        _camps = dropdown.map((c) {
          final name = c['camp_name'] ?? c['name'] ?? 'Vision Camp';
          final code = c['camp_code'] ?? c['code'] ?? '';
          return '$name ($code)';
        }).toList();
        if (_camps.isNotEmpty && _selectedCamp == null) {
          _selectedCamp = _camps.first;
        }
      }

      final res = await MobileApiService().fetchLiveCampDashboard(
        menuId: widget.menuId,
        moduleId: widget.moduleId,
        actionCode: widget.actionCode, // 'VIEW'
      );
      if (mounted) {
        setState(() {
          if (res['success'] == true) {
            final camp = res['camp'];
            if (camp is Map) {
              final campName = camp['camp_name'] ?? camp['name'];
              if (campName != null) {
                _selectedCamp = campName.toString();
              }
              _metrics = {
                'registered': camp['registered_count'] ?? camp['registered'] ?? 0,
                'screened': camp['screened_count'] ?? camp['screened'] ?? 0,
                'inConsultation': camp['in_consultation_count'] ?? camp['inConsultation'] ?? 0,
                'glassesAdvised': camp['glasses_count'] ?? camp['glassesAdvised'] ?? 0,
                'cataractReferred': camp['referral_count'] ?? camp['cataractReferred'] ?? 0,
              };
            }
            final queue = res['queue'];
            if (queue is List) {
              _liveQueue = queue.map((q) {
                return {
                  'token': q['token']?.toString() ?? 'T-00',
                  'name': q['patient_name']?.toString() ?? q['name']?.toString() ?? 'Patient',
                  'age': q['age']?.toString() ?? '',
                  'gender': q['gender']?.toString() ?? '',
                  'stage': q['stage']?.toString() ?? 'Waiting',
                  'statusColor': const Color(0xFF0284C7),
                  'va': q['va']?.toString() ?? '',
                };
              }).toList();
            }
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: const StaffAppDrawer(currentRoute: '/portal/live-camp'),
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
            Row(
              children: [
                Text(
                  'Live Camp',
                  style: GoogleFonts.notoSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFEF4444),
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 800.ms),
                const SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: GoogleFonts.notoSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
            Text(
              'Realtime Camp Operations & Queue',
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
            tooltip: 'Refresh /reports/dashboard/screening-team (VIEW)',
            onPressed: _loadLiveDashboard,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: LinearProgressIndicator(),
              ),
            // Active Camp Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text(_camps.isEmpty ? 'Loading camps...' : 'Select Camp'),
                  value: _camps.contains(_selectedCamp)
                      ? _selectedCamp
                      : (_camps.isNotEmpty ? _camps.first : null),
                  items: _camps.map((camp) {
                    return DropdownMenuItem(
                      value: camp,
                      child: Text(
                        camp,
                        style: GoogleFonts.notoSans(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCamp = val);
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Live Metrics Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildMetricCard('Total Registered', '${_metrics['registered'] ?? 0}', Icons.how_to_reg_rounded, const Color(0xFF004990)),
                _buildMetricCard('Screened', '${_metrics['screened'] ?? 0}', Icons.remove_red_eye_rounded, const Color(0xFF0284C7)),
                _buildMetricCard('In Consultation', '${_metrics['inConsultation'] ?? 0}', Icons.medical_services_rounded, const Color(0xFFE11D48)),
                _buildMetricCard('Glasses Advised', '${_metrics['glassesAdvised'] ?? 0}', Icons.auto_awesome_rounded, const Color(0xFF16A34A)),
                _buildMetricCard('Cataract Referred', '${_metrics['cataractReferred'] ?? 0}', Icons.local_hospital_rounded, const Color(0xFF9333EA)),
                _buildMetricCard('Completed Queue', '${_liveQueue.length}', Icons.check_circle_outline_rounded, const Color(0xFF64748B)),
              ],
            ),

            const SizedBox(height: 24),

            // Live Triage Queue
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Live Patient Queue',
                  style: GoogleFonts.notoSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  '${_liveQueue.length} Active',
                  style: GoogleFonts.notoSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _liveQueue.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Center(
                      child: Text(
                        'No patients currently in live queue',
                        style: GoogleFonts.notoSans(color: const Color(0xFF94A3B8), fontSize: 13),
                      ),
                    ),
                  )
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _liveQueue.length,
              itemBuilder: (context, index) {
                final item = _liveQueue[index];
                final color = item['statusColor'] as Color;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item['token'],
                          style: GoogleFonts.notoSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: GoogleFonts.notoSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '${item['age']} Yrs • ${item['gender']} • VA: ${item['va']}',
                              style: GoogleFonts.notoSans(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item['stage'],
                          style: GoogleFonts.notoSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: Duration(milliseconds: index * 60));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String title, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                count,
                style: GoogleFonts.notoSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
          Text(
            title,
            style: GoogleFonts.notoSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
