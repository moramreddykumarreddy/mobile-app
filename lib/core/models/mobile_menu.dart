// lib/core/models/mobile_menu.dart

class MobileMenu {
  final int menuId;
  final String menuName;
  final String routePath;
  final int displayOrder;
  final int moduleId;
  final String moduleName;
  final List<String> actionCodes;

  const MobileMenu({
    required this.menuId,
    required this.menuName,
    required this.routePath,
    required this.displayOrder,
    required this.moduleId,
    required this.moduleName,
    required this.actionCodes,
  });

  factory MobileMenu.fromJson(Map<String, dynamic> json) {
    return MobileMenu(
      menuId: json['menu_id'] is int
          ? json['menu_id'] as int
          : int.tryParse(json['menu_id']?.toString() ?? '0') ?? 0,
      menuName: json['menu_name']?.toString() ?? '',
      routePath: json['route_path']?.toString() ?? '',
      displayOrder: json['display_order'] is int
          ? json['display_order'] as int
          : int.tryParse(json['display_order']?.toString() ?? '1') ?? 1,
      moduleId: json['module_id'] is int
          ? json['module_id'] as int
          : int.tryParse(json['module_id']?.toString() ?? '0') ?? 0,
      moduleName: json['module_name']?.toString() ?? '',
      actionCodes: json['action_codes'] is List
          ? (json['action_codes'] as List).map((e) => e.toString().trim()).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'menu_id': menuId,
      'menu_name': menuName,
      'route_path': routePath,
      'display_order': displayOrder,
      'module_id': moduleId,
      'module_name': moduleName,
      'action_codes': actionCodes,
    };
  }

  bool hasAction(String action) =>
      actionCodes.any((a) => a.toUpperCase() == action.toUpperCase());
}
