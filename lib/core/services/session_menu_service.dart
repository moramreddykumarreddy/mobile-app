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

  List<MobileMenu> get menus => List.unmodifiable(_menus);
  String get staffName => _staffName;
  String get username => _username;

  void setUser({required String username, String? staffName}) {
    _username = username;
    _staffName = staffName ?? (username.isNotEmpty ? username : 'Staff Member');
  }

  void clear() {
    _menus = [];
    _staffName = 'Staff Member';
    _username = '';
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
