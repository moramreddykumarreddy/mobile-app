// lib/features/teams/screens/teams_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/mobile_api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/staff_app_drawer.dart';

class TeamsScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final int menuId;
  final int moduleId;
  final String actionCode;

  const TeamsScreen({
    super.key,
    this.onOpenDrawer,
    this.menuId = 210,
    this.moduleId = 33,
    this.actionCode = 'VIEW',
  });

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final _searchController = TextEditingController();
  bool _isLoading = true;
  String _selectedFilter = 'All';

  List<Map<String, dynamic>> _teams = [];

  @override
  void initState() {
    super.initState();
    _loadTeamsFromApi();
  }

  Future<void> _loadTeamsFromApi() async {
    setState(() => _isLoading = true);
    try {
      final list = await MobileApiService().fetchScreeningTeams(
        menuId: widget.menuId,
        moduleId: widget.moduleId,
        actionCode: widget.actionCode,
      );
      if (mounted) {
        setState(() {
          _teams = list.map((t) {
            final rawCode = t['team_code'] ?? t['id'];
            final codeInt = int.tryParse(rawCode?.toString() ?? '0') ?? 0;
            final isActive = (t['is_active'] == 1 || t['is_active'] == '1' || t['status'] == 'Active');
            final membersRaw = t['members'];
            final membersList = membersRaw is List ? List<Map<String, dynamic>>.from(membersRaw.whereType<Map>()) : <Map<String, dynamic>>[];

            return {
              'raw': t,
              'team_code': codeInt,
              'id': codeInt > 0 ? codeInt.toString() : (rawCode?.toString() ?? 'TEAM'),
              'name': t['team_name']?.toString() ?? t['name']?.toString() ?? 'Screening Unit',
              'lead': t['team_lead_name']?.toString() ?? t['lead']?.toString() ?? 'Lead Doctor',
              'nodal': t['nodal_officer_name']?.toString() ?? 'Nodal Officer',
              'district': t['dist_name']?.toString() ?? t['district']?.toString() ?? 'Andhra Pradesh',
              'members': membersList,
              'membersCount': membersList.isNotEmpty ? membersList.length : (t['member_count'] ?? t['members_count'] ?? 4),
              'isActive': isActive,
              'status': isActive ? 'Active' : 'Inactive',
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _teams = [];
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

  List<Map<String, dynamic>> get _filteredTeams {
    return _teams.where((t) {
      if (_selectedFilter != 'All' && t['status'] != _selectedFilter) {
        return false;
      }
      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final name = t['name'].toString().toLowerCase();
        final lead = t['lead'].toString().toLowerCase();
        final id = t['id'].toString().toLowerCase();
        final dist = t['district'].toString().toLowerCase();
        return name.contains(query) || lead.contains(query) || id.contains(query) || dist.contains(query);
      }
      return true;
    }).toList();
  }

  void _showTeamRosterDialog(Map<String, dynamic> team) {
    final List<Map<String, dynamic>> members = team['members'] as List<Map<String, dynamic>>;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.70,
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
                        team['name'],
                        style: GoogleFonts.notoSans(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Team Code #${team['id']} • ${team['district']}',
                        style: GoogleFonts.notoSans(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: team['isActive']
                        ? const Color(0xFF16A34A).withOpacity(0.12)
                        : const Color(0xFF64748B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    team['status'],
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: team['isActive'] ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(
              'TEAM LEAD & NODAL OFFICER',
              style: GoogleFonts.notoSans(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            _memberTile(Icons.medical_services_rounded, team['lead'], 'Team Lead (Doctor)', AppColors.primary),
            _memberTile(Icons.admin_panel_settings_rounded, team['nodal'], 'Nodal Officer', const Color(0xFF0284C7)),
            const SizedBox(height: 16),
            Text(
              'ASSIGNED MEMBERS ROSTER (${team['membersCount']})',
              style: GoogleFonts.notoSans(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: members.isEmpty
                  ? Center(
                      child: Text(
                        'Standard Roster: 1 Optometrist, 2 Vision Technicians, 1 Field Coordinator',
                        style: GoogleFonts.notoSans(fontSize: 12, color: const Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (ctx, idx) {
                        final m = members[idx];
                        final name = m['user_name'] ?? m['name'] ?? 'Member';
                        final emp = m['emp_no'] ?? m['employee_no'] ?? 'EMP-${idx + 10}';
                        final uid = m['user_id']?.toString() ?? '';
                        return _memberTile(Icons.badge_outlined, name, 'ID: $uid • Emp No: $emp', const Color(0xFF64748B));
                      },
                    ),
            ),
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

  Widget _memberTile(IconData icon, String name, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.notoSans(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
                Text(subtitle, style: GoogleFonts.notoSans(fontSize: 11, color: const Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showToggleStatusDialog(Map<String, dynamic> team) {
    final reasonCtrl = TextEditingController();
    final isCurrentlyActive = team['isActive'] as bool;
    final nextStatus = isCurrentlyActive ? 'Deactivate' : 'Activate';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isCurrentlyActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
              color: isCurrentlyActive ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
              size: 28,
            ),
            const SizedBox(width: 8),
            Text('$nextStatus Team', style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to $nextStatus team "${team['name']}"? Enter a mandatory reason below.',
              style: GoogleFonts.notoSans(fontSize: 13, color: const Color(0xFF475569)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Reason for status change (required)...',
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
              final teamCode = team['team_code'] as int;
              final ok = await MobileApiService().toggleTeamStatus(
                teamCode,
                isCurrentlyActive ? 0 : 1,
                reasonCtrl.text.trim(),
                menuId: widget.menuId,
                moduleId: widget.moduleId,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Team status updated' : 'Failed to update team status'),
                    backgroundColor: ok ? const Color(0xFF16A34A) : Colors.red,
                  ),
                );
                _loadTeamsFromApi();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentlyActive ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
            ),
            child: Text('Confirm $nextStatus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: const StaffAppDrawer(currentRoute: '/portal/teams'),
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
              'Teams',
              style: GoogleFonts.notoSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Screening Team Rosters & Allocations',
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
            tooltip: 'Refresh /camps/screening-team (VIEW)',
            onPressed: _loadTeamsFromApi,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.notoSans(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by team name, lead doctor, code, district...',
                    hintStyle: GoogleFonts.notoSans(color: const Color(0xFF94A3B8), fontSize: 13),
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
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: ['All', 'Active', 'Inactive'].map((status) {
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
              ],
            ),
          ),

          // Teams List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTeams.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.groups_outlined, size: 48, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 12),
                            Text(
                              'No screening teams found',
                              style: GoogleFonts.notoSans(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredTeams.length,
                        itemBuilder: (context, index) {
                          final team = _filteredTeams[index];
                          final isActive = team['isActive'] as bool;

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
                                          color: isActive
                                              ? const Color(0xFF16A34A).withOpacity(0.12)
                                              : const Color(0xFF64748B).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          team['status'],
                                          style: GoogleFonts.notoSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isActive ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Team #${team['id']}',
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
                                    team['name'],
                                    style: GoogleFonts.notoSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_pin_circle_outlined, size: 15, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          'Lead: ${team['lead']}',
                                          style: GoogleFonts.notoSans(fontSize: 13, color: const Color(0xFF475569), fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.map_outlined, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(
                                        team['district'],
                                        style: GoogleFonts.notoSans(fontSize: 12, color: const Color(0xFF64748B)),
                                      ),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.group_outlined, size: 14, color: Color(0xFF64748B)),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${team['membersCount']} Members',
                                        style: GoogleFonts.notoSans(fontSize: 12, color: const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _showTeamRosterDialog(team),
                                        icon: const Icon(Icons.visibility_outlined, size: 14),
                                        label: const Text('View Roster'),
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton.icon(
                                        onPressed: () => _showToggleStatusDialog(team),
                                        icon: Icon(
                                          isActive ? Icons.power_settings_new_rounded : Icons.play_arrow_rounded,
                                          size: 14,
                                          color: isActive ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                                        ),
                                        label: Text(
                                          isActive ? 'Deactivate' : 'Activate',
                                          style: TextStyle(color: isActive ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: isActive ? const Color(0xFFDC2626) : const Color(0xFF16A34A)),
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
