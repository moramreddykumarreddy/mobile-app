// lib/core/widgets/staff_app_drawer.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/mobile_menu.dart';
import '../services/his_websocket_service.dart';
import '../services/session_menu_service.dart';
import '../theme/app_theme.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/camps/screens/camps_screen.dart';
import '../../features/camps/screens/live_camp_screen.dart';
import '../../features/camps/screens/register_camp_screen.dart';
import '../../features/patient/screens/patient_history_screen.dart';
import '../../features/patient/screens/register_patient_screen.dart';
import '../../features/patient/screens/todays_patients_screen.dart';
import '../../features/teams/screens/teams_screen.dart';
import '../../features/teleconsult/screens/teleconsult_screen.dart';

class StaffAppDrawer extends StatefulWidget {
  final String? currentRoute;

  const StaffAppDrawer({
    super.key,
    this.currentRoute,
  });

  @override
  State<StaffAppDrawer> createState() => _StaffAppDrawerState();
}

class _StaffAppDrawerState extends State<StaffAppDrawer> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (SessionMenuService().menus.isEmpty) {
      _refreshMenus();
    }
  }

  Future<void> _refreshMenus() async {
    setState(() => _isLoading = true);
    await SessionMenuService().loadMenus();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  IconData _getMenuIcon(String routePath) {
    switch (routePath) {
      case '/portal/camps':
        return Icons.holiday_village_rounded;
      case '/portal/register-camp':
        return Icons.how_to_reg_rounded;
      case '/portal/live-camp':
        return Icons.sensors_rounded;
      case '/portal/patient-history':
        return Icons.manage_search_rounded;
      case '/portal/register-patient':
        return Icons.person_add_alt_1_rounded;
      case '/portal/patients':
        return Icons.groups_2_rounded;
      case '/portal/teams':
        return Icons.badge_rounded;
      case '/portal/teleconsult':
        return Icons.video_call_rounded;
      default:
        return Icons.widgets_rounded;
    }
  }

  Color _getMenuColor(String routePath) {
    switch (routePath) {
      case '/portal/camps':
        return const Color(0xFF0284C7);
      case '/portal/register-camp':
        return const Color(0xFF0D9488);
      case '/portal/live-camp':
        return const Color(0xFFE11D48);
      case '/portal/patient-history':
        return const Color(0xFF7C3AED);
      case '/portal/register-patient':
        return const Color(0xFF059669);
      case '/portal/patients':
        return const Color(0xFFEA580C);
      case '/portal/teams':
        return const Color(0xFF4F46E5);
      case '/portal/teleconsult':
        return const Color(0xFF004990);
      default:
        return AppColors.primary;
    }
  }

  void _navigateToMenu(BuildContext context, MobileMenu menu) {
    Navigator.of(context).pop(); // Close drawer first

    if (widget.currentRoute == menu.routePath) {
      return; // Already on this screen
    }

    Widget screen;
    switch (menu.routePath) {
      case '/portal/camps':
        screen = CampsScreen(
          menuId: menu.menuId,
          moduleId: menu.moduleId,
          actionCode: 'VIEW',
        );
        break;
      case '/portal/register-camp':
        screen = RegisterPatientToCampScreen(
          menuId: menu.menuId,
          moduleId: menu.moduleId,
          actionCode: 'VIEW',
        );
        break;
      case '/portal/live-camp':
        screen = LiveCampScreen(
          menuId: menu.menuId,
          moduleId: menu.moduleId,
          actionCode: 'VIEW',
        );
        break;
      case '/portal/patient-history':
        screen = PatientHistoryScreen(
          menuId: menu.menuId,
          moduleId: menu.moduleId,
          actionCode: 'VIEW',
        );
        break;
      case '/portal/register-patient':
        screen = RegisterPatientScreen(
          menuId: menu.menuId,
          moduleId: menu.moduleId,
          actionCode: 'VIEW',
        );
        break;
      case '/portal/patients':
        screen = TodaysPatientsScreen(
          menuId: menu.menuId,
          moduleId: menu.moduleId,
          actionCode: 'VIEW',
        );
        break;
      case '/portal/teams':
        screen = TeamsScreen(
          menuId: menu.menuId,
          moduleId: menu.moduleId,
          actionCode: 'VIEW',
        );
        break;
      case '/portal/teleconsult':
        screen = TeleconsultationScreen(
          menuId: menu.menuId,
          moduleId: menu.moduleId,
          actionCode: 'VIEW',
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening ${menu.menuName}...')),
        );
        return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out',
          style: GoogleFonts.notoSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to sign out from the Staff Portal?',
          style: GoogleFonts.notoSans(fontSize: 14, color: const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.notoSans(color: const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              HisWebSocketService().disconnect();
              SessionMenuService().clear();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(90, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show only remaining menus in the drawer (bottom navbar items excluded)
    final menus = SessionMenuService().drawerMenus;
    final staffName = SessionMenuService().staffName;

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // Drawer Header with AP Govt & Staff branding
          Container(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'STAFF PORTAL',
                            style: GoogleFonts.notoSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                      tooltip: 'Close menu',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          staffName.isNotEmpty ? staffName[0].toUpperCase() : 'S',
                          style: GoogleFonts.notoSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            staffName,
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ophthalmic Staff • Hub Unit',
                            style: GoogleFonts.notoSans(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Govt. of Andhra Pradesh',
                            style: GoogleFonts.notoSans(
                              fontSize: 10,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Drawer Section Title & Refresh API action
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.apps_rounded, size: 16, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      'PORTAL MENUS',
                      style: GoogleFonts.notoSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF64748B),
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.primary),
                  tooltip: 'Refresh Menus',
                  onPressed: _refreshMenus,
                ),
              ],
            ),
          ),

          // Dynamic Menu List strictly from API
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2.5),
                        SizedBox(height: 12),
                        Text(
                          'Loading mobile menus...',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  )
                : menus.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.menu_open_rounded, size: 40, color: Color(0xFF94A3B8)),
                              const SizedBox(height: 10),
                              Text(
                                'No menus available',
                                style: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: _refreshMenus,
                                child: const Text('Reload Menus'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        itemCount: menus.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 2),
                        itemBuilder: (context, index) {
                          final menu = menus[index];
                          final isSelected = widget.currentRoute == menu.routePath;
                          final icon = _getMenuIcon(menu.routePath);
                          final color = _getMenuColor(menu.routePath);

                          return Material(
                            color: isSelected ? color.withOpacity(0.08) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: isSelected
                                    ? BorderSide(color: color.withOpacity(0.3), width: 1.5)
                                    : BorderSide.none,
                              ),
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(isSelected ? 0.2 : 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(icon, color: color, size: 20),
                              ),
                              title: Text(
                                menu.menuName,
                                style: GoogleFonts.notoSans(
                                  fontSize: 13.5,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                  color: isSelected ? color : const Color(0xFF0F172A),
                                ),
                              ),
                              subtitle: Text(
                                menu.moduleName,
                                style: GoogleFonts.notoSans(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Icon(
                                isSelected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                                size: 18,
                                color: isSelected ? color : const Color(0xFF94A3B8),
                              ),
                              onTap: () => _navigateToMenu(context, menu),
                            ),
                          );
                        },
                      ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Drawer Footer with Logout
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: InkWell(
              onTap: () => _handleLogout(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Sign Out',
                      style: GoogleFonts.notoSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
