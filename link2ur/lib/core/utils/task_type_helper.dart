import 'package:flutter/material.dart';

/// 统一的任务类型图标映射
///
/// 后端 task_type 字段有多种格式：
/// - 老格式（展示名）: "Housekeeping", "Campus Life", "Errand Running" 等
/// - 新格式（纯英文小写）: "delivery", "shopping", "tutoring" 等
/// - 达人任务可能是中文: "其他"
///
/// 此工具类统一覆盖所有变体，避免各个卡片组件各自维护映射导致遗漏。
class TaskTypeHelper {
  TaskTypeHelper._();

  /// 根据 taskType 获取对应的 Material Icon
  static IconData getIcon(String taskType) {
    return _iconMap[taskType] ?? _iconMap[taskType.toLowerCase()] ?? Icons.task_alt;
  }

  /// 所有 taskType → IconData 的映射
  /// 同时包含后端老格式（展示名）和新格式（小写标识符）
  static const Map<String, IconData> _iconMap = {
    // ===== 后端老格式 (TASK_TYPES in schemas.py) =====
    'Housekeeping': Icons.home_outlined,
    'Campus Life': Icons.school_outlined,
    'Second-hand & Rental': Icons.shopping_bag_outlined,
    'Errand Running': Icons.directions_run,
    'Skill Service': Icons.build_outlined,
    'Social Help': Icons.people_outlined,
    'Transportation': Icons.directions_car_outlined,
    'Pet Care': Icons.pets_outlined,
    'Life Convenience': Icons.shopping_cart_outlined,
    'Other': Icons.apps,

    // ===== 新格式 (AppConstants.taskTypes) =====
    'delivery': Icons.directions_run,
    'shopping': Icons.shopping_bag_outlined,
    'tutoring': Icons.school_outlined,
    'translation': Icons.translate,
    'design': Icons.design_services_outlined,
    'programming': Icons.code,
    'writing': Icons.edit_note,
    'photography': Icons.camera_alt_outlined,
    'moving': Icons.local_shipping_outlined,
    'cleaning': Icons.cleaning_services_outlined,
    'repair': Icons.handyman_outlined,
    'pet_care': Icons.pets_outlined,
    'errand': Icons.directions_run,
    'other': Icons.apps,

    // ===== 小写别名（防止大小写不匹配）=====
    'housekeeping': Icons.home_outlined,
    'campus life': Icons.school_outlined,
    'campus': Icons.school_outlined,
    'second-hand & rental': Icons.shopping_bag_outlined,
    'secondhand': Icons.shopping_bag_outlined,
    'errand running': Icons.directions_run,
    'skill service': Icons.build_outlined,
    'skill': Icons.build_outlined,
    'social help': Icons.people_outlined,
    'social': Icons.people_outlined,
    'transportation': Icons.directions_car_outlined,
    'transport': Icons.directions_car_outlined,
    'life convenience': Icons.shopping_cart_outlined,
    'life': Icons.shopping_cart_outlined,

    // ===== 中文变体（达人任务创建时可能使用）=====
    '其他': Icons.apps,
  };
}
