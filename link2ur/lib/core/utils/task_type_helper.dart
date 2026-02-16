import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 统一的任务类型图标与国际化文案映射
///
/// 后端 task_type 字段有多种格式：
/// - 老格式（展示名）: "Housekeeping", "Campus Life", "Errand Running" 等
/// - 新格式（纯英文小写）: "delivery", "shopping", "tutoring" 等
/// - 达人任务可能是中文: "其他"
///
/// 此工具类统一覆盖所有变体，避免各个卡片组件各自维护映射导致遗漏。
class TaskTypeHelper {
  TaskTypeHelper._();

  /// 根据 taskType 获取国际化显示文案（随 locale 切换）
  static String getLocalizedLabel(String taskType, AppLocalizations l10n) {
    final key = _labelKeyMap[taskType] ?? _labelKeyMap[taskType.toLowerCase()];
    if (key != null) return key(l10n);
    return taskType;
  }

  static final Map<String, String Function(AppLocalizations)> _labelKeyMap = {
    'Housekeeping': (l) => l.taskTypeHousekeeping,
    'Campus Life': (l) => l.taskTypeCampusLife,
    'Second-hand & Rental': (l) => l.taskTypeSecondHandRental,
    'Errand Running': (l) => l.taskTypeErrandRunning,
    'Skill Service': (l) => l.taskTypeSkillService,
    'Social Help': (l) => l.taskTypeSocialHelp,
    'Transportation': (l) => l.taskTypeTransportation,
    'Pet Care': (l) => l.taskTypePetCare,
    'Life Convenience': (l) => l.taskTypeLifeConvenience,
    'Other': (l) => l.taskTypeOther,
    'housekeeping': (l) => l.taskTypeHousekeeping,
    'campus life': (l) => l.taskTypeCampusLife,
    'campus': (l) => l.taskTypeCampusLife,
    'second-hand & rental': (l) => l.taskTypeSecondHandRental,
    'secondhand': (l) => l.taskTypeSecondHandRental,
    'errand running': (l) => l.taskTypeErrandRunning,
    'skill service': (l) => l.taskTypeSkillService,
    'skill': (l) => l.taskTypeSkillService,
    'social help': (l) => l.taskTypeSocialHelp,
    'social': (l) => l.taskTypeSocialHelp,
    'transportation': (l) => l.taskTypeTransportation,
    'transport': (l) => l.taskTypeTransportation,
    'pet care': (l) => l.taskTypePetCare,
    'pet_care': (l) => l.taskTypePetCare,
    'life convenience': (l) => l.taskTypeLifeConvenience,
    'life': (l) => l.taskTypeLifeConvenience,
    'other': (l) => l.taskTypeOther,
    'delivery': (l) => l.createTaskCategoryDelivery,
    'shopping': (l) => l.createTaskCategoryShopping,
    'tutoring': (l) => l.createTaskCategoryTutoring,
    'translation': (l) => l.createTaskCategoryTranslation,
    'design': (l) => l.createTaskCategoryDesign,
    'programming': (l) => l.createTaskCategoryProgramming,
    'writing': (l) => l.createTaskCategoryWriting,
    'photography': (l) => l.taskTypeSkillService,
    'moving': (l) => l.taskTypeTransportation,
    'cleaning': (l) => l.taskTypeHousekeeping,
    'repair': (l) => l.taskTypeSkillService,
    'errand': (l) => l.taskTypeErrandRunning,
    '其他': (l) => l.taskTypeOther,
  };

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
