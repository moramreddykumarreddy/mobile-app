// lib/features/teams/screens/teams_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/mobile_api_service.dart';
import '../../../core/services/session_menu_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/staff_app_bar.dart';
import '../../../core/widgets/staff_app_drawer.dart';
import '../../../core/widgets/staff_bottom_nav_bar.dart';

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
  String _selectedStatusTab = 'All';

  List<Map<String, dynamic>> _teams = [];

  @override
  void initState() {
    super.initState();
    _loadTeamsFromApi();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamsFromApi() async {
    setState(() => _isLoading = true);
    try {
      final dynMenu = SessionMenuService().getMenuForRoute('/portal/teams');
      final effectiveModuleId = dynMenu?.moduleId ?? widget.moduleId;
      final effectiveMenuId = dynMenu?.menuId ?? widget.menuId;

      final list = await MobileApiService().fetchScreeningTeams(
        menuId: effectiveMenuId,
        moduleId: effectiveModuleId,
        actionCode: widget.actionCode,
      );

      if (mounted) {
        setState(() {
          _teams = list.map((t) {
            final rawCode = t['team_code'] ?? t['id'];
            final codeInt = int.tryParse(rawCode?.toString() ?? '0') ?? 0;
            final isActive = (t['is_active'] == 1 ||
                t['is_active'] == '1' ||
                t['status'] == 'Active');

            final membersRaw = t['members'];
            final membersList = membersRaw is List
                ? List<Map<String, dynamic>>.from(
                    membersRaw.whereType<Map>(),
                  )
                : <Map<String, dynamic>>[];

            final leadName = t['team_lead_name']?.toString().trim();
            final nodalName = t['nodal_officer_name']?.toString().trim();
            final distName = (t['district_name'] ??
                    t['dist_name'] ??
                    t['district'] ??
                    '')
                .toString()
                .trim();
            final remarksStr = t['remarks']?.toString().trim();

            return {
              'raw': t,
              'team_code': codeInt,
              'name': t['team_name']?.toString() ??
                  t['name']?.toString() ??
                  'Screening Unit',
              'lead': (leadName != null &&
                      leadName.isNotEmpty &&
                      leadName.toLowerCase() != 'null')
                  ? leadName
                  : '—',
              'nodal': (nodalName != null &&
                      nodalName.isNotEmpty &&
                      nodalName.toLowerCase() != 'null')
                  ? nodalName
                  : '—',
              'district': distName.isNotEmpty ? distName : 'Andhra Pradesh',
              'remarks': (remarksStr != null &&
                      remarksStr.isNotEmpty &&
                      remarksStr.toLowerCase() != 'null')
                  ? remarksStr
                  : null,
              'members': membersList,
              'membersCount': membersList.isNotEmpty
                  ? membersList.length
                  : (t['member_count'] ?? t['members_count'] ?? 0),
              'isActive': isActive,
              'status': isActive ? 'Active' : 'Inactive',
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('TeamsScreen load error: $e');
      if (mounted) {
        setState(() {
          _teams = [];
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredTeams {
    return _teams.where((t) {
      // 1. Status tab filter
      if (_selectedStatusTab != 'All' && t['status'] != _selectedStatusTab) {
        return false;
      }

      // 3. Search query
      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final name = t['name'].toString().toLowerCase();
        final lead = t['lead'].toString().toLowerCase();
        final dist = t['district'].toString().toLowerCase();
        final nodal = t['nodal'].toString().toLowerCase();
        return name.contains(query) ||
            lead.contains(query) ||
            dist.contains(query) ||
            nodal.contains(query);
      }
      return true;
    }).toList();
  }

  void _showTeamRosterDialog(Map<String, dynamic> team) {
    final List<Map<String, dynamic>> members =
        team['members'] as List<Map<String, dynamic>>;
    final isActive = team['isActive'] as bool;
    final statusColor =
        isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

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
                      Text(
                        team['name'],
                        style: GoogleFonts.notoSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        team['district'],
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
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    team['status'],
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
            Text(
              'TEAM MEMBERS (${team['membersCount']})',
              style: GoogleFonts.notoSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF64748B),
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: members.isEmpty
                  ? Center(
                      child: Text(
                        'No team members registered yet.',
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          color: const Color(0xFF94A3B8),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (ctx, idx) {
                        final m = members[idx];
                        final name = m['user_name']?.toString() ??
                            m['name']?.toString() ??
                            'Member';
                        final emp = (m['emp_no'] ?? m['employee_no'] ?? '')
                            .toString()
                            .trim();

                        return _memberTile(
                          Icons.person_outline_rounded,
                          name,
                          emp.isNotEmpty ? 'Emp No: $emp' : 'Team Member',
                          const Color(0xFF64748B),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
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

  Widget _memberTile(
      IconData icon, String name, String subtitle, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.notoSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.notoSans(
                    fontSize: 11.5,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      drawer: const StaffAppDrawer(currentRoute: '/portal/teams'),
      bottomNavigationBar:
          const StaffBottomNavBar(currentRoute: '/portal/teams'),
      appBar: StaffAppBar(onOpenDrawer: widget.onOpenDrawer),
      body: Column(
        children: [
          // Search & Active/Inactive Dropdown Row + Status Tabs (Camps style)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(
              children: [
                // Full-width Search box
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: GoogleFonts.notoSans(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search teams...',
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
                      borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFFE2E8F0)),
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

                // Status Tabs: Clean, elegant pills matching Camps page
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['All', 'Active', 'Inactive'].map((status) {
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
                                horizontal: 16, vertical: 7),
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
                            child: Text(
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
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Teams List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTeams.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _loadTeamsFromApi,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height:
                                  MediaQuery.of(context).size.height * 0.15,
                            ),
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.groups_outlined,
                                    size: 48,
                                    color: Color(0xFF94A3B8),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No ${_selectedStatusTab == 'All' ? '' : '${_selectedStatusTab.toLowerCase()} '}screening teams found',
                                    style: GoogleFonts.notoSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: _loadTeamsFromApi,
                                    icon: const Icon(Icons.refresh_rounded,
                                        size: 16),
                                    label: const Text('Refresh Teams'),
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
                        onRefresh: _loadTeamsFromApi,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: _filteredTeams.length,
                          itemBuilder: (context, index) {
                            final team = _filteredTeams[index];
                            final isActive = team['isActive'] as bool;
                            final statusColor = isActive
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626);

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
                                    // Row: Active Badge Only (No team code)
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor
                                                .withOpacity(0.12),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            team['status'],
                                            style: GoogleFonts.notoSans(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Team Name
                                    Text(
                                      team['name'],
                                      style: GoogleFonts.notoSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // District & Members Count
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on_outlined,
                                            size: 15,
                                            color: Color(0xFF64748B)),
                                        const SizedBox(width: 4),
                                        Text(
                                          team['district'],
                                          style: GoogleFonts.notoSans(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF475569),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        const Icon(Icons.groups_outlined,
                                            size: 15,
                                            color: Color(0xFF64748B)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${team['membersCount']} Members',
                                          style: GoogleFonts.notoSans(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // Officer details: Nodal Officer & Team Lead
                                    Container(
                                      margin: const EdgeInsets.only(
                                          top: 10, bottom: 4),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Column(
                                        children: [
                                          // Nodal Officer
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFFEF3C7),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Icon(
                                                  Icons
                                                      .admin_panel_settings_outlined,
                                                  size: 14,
                                                  color: Color(0xFFD97706),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Nodal Officer: ',
                                                style: GoogleFonts.notoSans(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      const Color(0xFF64748B),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  team['nodal'],
                                                  style: GoogleFonts.notoSans(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: (team['nodal'] ==
                                                                'Not assigned' ||
                                                            team['nodal'] ==
                                                                '—')
                                                        ? const Color(
                                                            0xFF94A3B8)
                                                        : const Color(
                                                            0xFF0F172A),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 6),
                                            child: Divider(
                                                height: 1,
                                                color: Color(0xFFE2E8F0)),
                                          ),
                                          // Team Lead
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primary
                                                      .withOpacity(0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Icon(
                                                  Icons
                                                      .medical_services_outlined,
                                                  size: 14,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Team Lead: ',
                                                style: GoogleFonts.notoSans(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      const Color(0xFF64748B),
                                                ),
                                              ),
                                              Expanded(
                                                child: Text(
                                                  team['lead'],
                                                  style: GoogleFonts.notoSans(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: (team['lead'] ==
                                                                'Not assigned' ||
                                                            team['lead'] == '—')
                                                        ? const Color(
                                                            0xFF94A3B8)
                                                        : const Color(
                                                            0xFF0F172A),
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

                                    // Remarks (if present)
                                    if (team['remarks'] != null) ...[
                                      const SizedBox(height: 6),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.info_outline,
                                              size: 14,
                                              color: Color(0xFF64748B)),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Note: ${team['remarks']}',
                                              style: GoogleFonts.notoSans(
                                                fontSize: 11.5,
                                                fontStyle: FontStyle.italic,
                                                color: const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],

                                    const Divider(height: 20),

                                    // Action: View Members Only
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _showTeamRosterDialog(team),
                                        icon: const Icon(
                                          Icons.visibility_outlined,
                                          size: 15,
                                        ),
                                        label: Text(
                                          'View Members (${team['membersCount']})',
                                          style: GoogleFonts.notoSans(
                                            fontSize: 13,
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
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 250.ms)
                                .slideY(begin: 0.05);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
