// lib/core/services/session_menu_service.dart
import 'package:flutter/foundation.dart';
import '../models/mobile_menu.dart';
import 'auth_api_service.dart';

/// Centralized state service holding the dynamic menus fetched strictly from:
/// GET /api/v1/user-management/access/mobile/menus
class SessionMenuService {
  static final SessionMenuService _instance = SessionMenuService._internal();
  factory SessionMenuService() => _instance;
  SessionMenuService._internal();

  List<MobileMenu> _menus = [];
  String _staffName = 'Staff Member';
  String _username = '';
  String? _userId;

  List<MobileMenu> get menus => List.unmodifiable(_menus);
  String get staffName => _staffName;
  String get username => _username;
  String? get userId => _userId;

  void setUser({required String username, String? staffName, String? userId}) {
    _username = username;
    _staffName = staffName ?? (username.isNotEmpty ? username : 'Staff Member');
    if (userId != null && userId.trim().isNotEmpty) {
      _userId = userId.trim();
    }
  }

  void setUserId(String? id) {
    if (id != null && id.trim().isNotEmpty) {
      _userId = id.trim();
    }
  }

  void clear() {
    _menus = [];
    _staffName = 'Staff Member';
    _username = '';
    _userId = null;
  }

  /// Extracts the userId/uuid from a login or profile response body,
  /// perfectly matching ApVisionCare.Portal pickUserId.
  static String? pickUserId(Map<String, dynamic> body) {
    final nested = body['user'] ?? body['data'] ?? body['profile'];
    final nestedMap = nested is Map<String, dynamic> ? nested : null;

    final uuidLike = [
      body['uuid'],
      body['userUuid'],
      body['user_uuid'],
      body['userUUID'],
      nestedMap?['uuid'],
      nestedMap?['userUuid'],
      nestedMap?['user_uuid'],
      nestedMap?['userUUID'],
    ];

    for (final c in uuidLike) {
      if (c != null) {
        final str = c.toString().trim();
        if (str.isNotEmpty) return str;
      }
    }

    final raw = [
      body['userId'],
      body['user_id'],
      body['userid'],
      body['hnum_userid'],
      body['id'],
      body['sub'],
      nestedMap?['userId'],
      nestedMap?['user_id'],
      nestedMap?['userid'],
      nestedMap?['hnum_userid'],
      nestedMap?['id'],
      nestedMap?['sub'],
    ];

    for (final c in raw) {
      if (c != null) {
        final str = c.toString().trim();
        if (str.isNotEmpty) return str;
      }
    }
    return null;
  }

  /// Loads menus strictly from the API response (no static fallback menus)
  Future<List<MobileMenu>> loadMenus() async {
    try {
      final fetched = await AuthApiService().fetchMobileMenus();
      _menus = fetched;
      debugPrint('SessionMenuService loaded ${_menus.length} dynamic menus from API.');
      for (final m in _menus) {
        debugPrint('   • [${m.menuId}] ${m.menuName} -> ${m.routePath} (actions: ${m.actionCodes})');
      }
      return _menus;
    } catch (e) {
      debugPrint('SessionMenuService loadMenus error: $e');
      _menus = [];
      return [];
    }
  }

  /// The first menu in the response (e.g. Camps /portal/camps)
  MobileMenu? get firstMenu => _menus.isNotEmpty ? _menus.first : null;

  /// Dynamic menu for the Dashboard module if present in assigned menus
  MobileMenu? get dashboardMenu {
    // 1. Check if module name contains 'dashboard' (e.g. Dashboards -> Live Camp)
    for (final m in _menus) {
      if (m.moduleName.toLowerCase().contains('dashboard')) {
        return m;
      }
    }
    // 2. Check if route path is live-camp or contains dashboard
    for (final m in _menus) {
      if (m.routePath.toLowerCase() == '/portal/live-camp' ||
          m.routePath.toLowerCase().contains('dashboard')) {
        return m;
      }
    }
    // 3. Check if menu name contains dashboard
    for (final m in _menus) {
      if (m.menuName.toLowerCase().contains('dashboard')) {
        return m;
      }
    }
    return null;
  }

  /// Whether the user has a dashboard module menu
  bool get hasDashboardMenu => dashboardMenu != null;

  /// Returns the initial menu to open upon login:
  /// Prioritizes the dashboard module menu if present, otherwise first available menu.
  MobileMenu? get initialMenu => dashboardMenu ?? firstMenu;

  /// Set of routes assigned to the bottom navigation bar
  Set<String> get bottomNavRoutes {
    final routes = <String>{};
    final dash = dashboardMenu;
    if (dash != null) {
      routes.add(dash.routePath.toLowerCase());
    }
    routes.add('/portal/patients');
    routes.add('/portal/register-patient');
    return routes;
  }

  /// Checks if a route path is one of the bottom navigation bar tabs
  bool isBottomNavRoute(String? routePath) {
    if (routePath == null) return false;
    final r = routePath.toLowerCase();
    if (r == '/portal/patients' ||
        r == '/portal/register-patient') {
      return true;
    }
    final dash = dashboardMenu;
    if (dash != null && r == dash.routePath.toLowerCase()) {
      return true;
    }
    return false;
  }

  /// Remaining menus strictly for the side hamburger drawer (excludes bottom nav items)
  List<MobileMenu> get drawerMenus {
    final bottomRoutes = bottomNavRoutes;
    return _menus
        .where((m) => !bottomRoutes.contains(m.routePath.toLowerCase()))
        .toList();
  }

  /// Find a dynamic menu by its route path
  MobileMenu? getMenuForRoute(String routePath) {
    try {
      return _menus.firstWhere(
        (m) => m.routePath.toLowerCase() == routePath.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Get dynamic menu ID or fallback
  int getMenuId(String routePath, int fallback) {
    final menu = getMenuForRoute(routePath);
    return menu?.menuId ?? fallback;
  }

  /// Get dynamic module ID or fallback
  int getModuleId(String routePath, int fallback) {
    final menu = getMenuForRoute(routePath);
    return menu?.moduleId ?? fallback;
  }

  /// Check if action code is allowed for this route
  bool isActionAllowed(String routePath, String actionCode) {
    final menu = getMenuForRoute(routePath);
    if (menu == null) return true;
    return menu.actionCodes.any(
      (a) => a.toUpperCase() == actionCode.toUpperCase(),
    );
  }
}

