// lib/core/widgets/staff_bottom_nav_bar.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/session_menu_service.dart';
import '../theme/app_theme.dart';
import '../../features/camps/screens/live_camp_screen.dart';
import '../../features/patient/screens/register_patient_screen.dart';
import '../../features/patient/screens/todays_patients_screen.dart';
import '../../features/profile/screens/profile_screen.dart';

class _NavItem {
  final String route;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavItem({
    required this.route,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class StaffBottomNavBar extends StatefulWidget {
  final String? currentRoute;

  const StaffBottomNavBar({
    super.key,
    this.currentRoute,
  });

  @override
  State<StaffBottomNavBar> createState() => _StaffBottomNavBarState();
}

class _StaffBottomNavBarState extends State<StaffBottomNavBar> {
  @override
  void initState() {
    super.initState();
    // Ensure menus are loaded so we know dynamic menu IDs & routes
    if (SessionMenuService().menus.isEmpty) {
      SessionMenuService().loadMenus().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _onItemTapped(BuildContext context, String targetRoute) {
    if (widget.currentRoute == targetRoute) return;

    Widget screen;
    switch (targetRoute) {
      case '/portal/live-camp':
        final menu = SessionMenuService().dashboardMenu;
        screen = LiveCampScreen(
          menuId: menu?.menuId ?? 255,
          moduleId: menu?.moduleId ?? 43,
          actionCode: 'VIEW',
        );
        break;
      case '/portal/patients':
        final menu = SessionMenuService().getMenuForRoute('/portal/patients');
        screen = TodaysPatientsScreen(
          menuId: menu?.menuId ?? 184,
          moduleId: menu?.moduleId ?? 29,
          actionCode: 'VIEW',
        );
        break;
      case '/portal/register-patient':
        final menu = SessionMenuService().getMenuForRoute('/portal/register-patient');
        screen = RegisterPatientScreen(
          menuId: menu?.menuId ?? 180,
          moduleId: menu?.moduleId ?? 29,
          actionCode: 'VIEW',
        );
        break;
      case '/portal/profile':
        screen = const ProfileScreen();
        break;
      default:
        return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => screen,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionMenuService();
    final dashMenu = session.dashboardMenu;

    final items = <_NavItem>[];

    // 1. Dashboard module menu (if present in menus)
    if (dashMenu != null) {
      final label = dashMenu.menuName.isNotEmpty ? dashMenu.menuName : 'Dashboard';
      items.add(
        _NavItem(
          route: dashMenu.routePath,
          label: label,
          icon: Icons.dashboard_outlined,
          activeIcon: Icons.dashboard_rounded,
        ),
      );
    }

    // 2. Today's Patient menu
    items.add(
      const _NavItem(
        route: '/portal/patients',
        label: "Today's Patient",
        icon: Icons.groups_2_outlined,
        activeIcon: Icons.groups_2_rounded,
      ),
    );

    // 3. Register Patient menu
    items.add(
      const _NavItem(
        route: '/portal/register-patient',
        label: 'Register Patient',
        icon: Icons.person_add_alt_outlined,
        activeIcon: Icons.person_add_alt_1_rounded,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: items.map((item) {
              final isSelected = widget.currentRoute == item.route;
              return Expanded(
                child: InkWell(
                  onTap: () => _onItemTapped(context, item.route),
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isSelected ? item.activeIcon : item.icon,
                            color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: GoogleFonts.notoSans(
                            fontSize: 10.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
