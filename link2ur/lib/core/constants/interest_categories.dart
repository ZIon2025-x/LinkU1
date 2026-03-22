import 'package:flutter/material.dart';

/// 兴趣分类常量，用于引导页和偏好设置页
class InterestCategory {
  final String key;
  final IconData icon;
  final String zh;
  final String en;

  const InterestCategory({
    required this.key,
    required this.icon,
    required this.zh,
    required this.en,
  });

  String label(String locale) => locale == 'zh' ? zh : en;
}

class InterestCategories {
  InterestCategories._();

  static const List<InterestCategory> all = [
    InterestCategory(key: 'moving_home', icon: Icons.home_rounded, zh: '搬家/家居', en: 'Moving & Home'),
    InterestCategory(key: 'housing', icon: Icons.vpn_key_rounded, zh: '租房/住宿', en: 'Housing'),
    InterestCategory(key: 'food_cooking', icon: Icons.restaurant_rounded, zh: '美食/烹饪', en: 'Food & Cooking'),
    InterestCategory(key: 'transport', icon: Icons.directions_car_rounded, zh: '出行/驾驶', en: 'Transport & Driving'),
    InterestCategory(key: 'study_tutoring', icon: Icons.menu_book_rounded, zh: '学习/辅导', en: 'Study & Tutoring'),
    InterestCategory(key: 'photo_video', icon: Icons.camera_alt_rounded, zh: '摄影/视频', en: 'Photo & Video'),
    InterestCategory(key: 'sports_fitness', icon: Icons.fitness_center_rounded, zh: '运动/健身', en: 'Sports & Fitness'),
    InterestCategory(key: 'travel', icon: Icons.flight_rounded, zh: '旅行/探索', en: 'Travel & Explore'),
    InterestCategory(key: 'shopping', icon: Icons.shopping_bag_rounded, zh: '代购/购物', en: 'Shopping'),
    InterestCategory(key: 'social', icon: Icons.people_rounded, zh: '社交/陪同', en: 'Social & Companion'),
    InterestCategory(key: 'pets', icon: Icons.pets_rounded, zh: '宠物', en: 'Pets'),
    InterestCategory(key: 'tech_it', icon: Icons.computer_rounded, zh: '技术/IT', en: 'Tech & IT'),
    InterestCategory(key: 'art_design', icon: Icons.palette_rounded, zh: '艺术/设计', en: 'Art & Design'),
    InterestCategory(key: 'gaming', icon: Icons.sports_esports_rounded, zh: '游戏/陪玩', en: 'Gaming'),
  ];
}
