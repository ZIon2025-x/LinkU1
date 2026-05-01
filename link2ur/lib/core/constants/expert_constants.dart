class ExpertConstants {
  ExpertConstants._();

  /// Expert category keys — aligned with backend FeaturedTaskExpert.category
  static const List<String> categoryKeys = [
    'all',
    // 老 13 个
    'programming',
    'translation',
    'tutoring',
    'food',
    'beverage',
    'cake',
    'errand_transport',
    'social_entertainment',
    'beauty_skincare',
    'handicraft',
    'gaming',
    'photography',
    'housekeeping',
    // 新 17 个（与 skill_categories.task_type 同名，技能板块共有）
    'shopping',
    'design',
    'writing',
    'moving',
    'cleaning',
    'repair',
    'pickup_dropoff',
    'cooking',
    'language_help',
    'government',
    'pet_care',
    'errand',
    'accompany',
    'digital',
    'rental_housing',
    'campus_life',
    'second_hand',
  ];

  /// Service category keys (excludes 'all')
  static const List<String> serviceCategoryKeys = [
    // 老 13 个
    'programming',
    'translation',
    'tutoring',
    'food',
    'beverage',
    'cake',
    'errand_transport',
    'social_entertainment',
    'beauty_skincare',
    'handicraft',
    'gaming',
    'photography',
    'housekeeping',
    // 新 17 个
    'shopping',
    'design',
    'writing',
    'moving',
    'cleaning',
    'repair',
    'pickup_dropoff',
    'cooking',
    'language_help',
    'government',
    'pet_care',
    'errand',
    'accompany',
    'digital',
    'rental_housing',
    'campus_life',
    'second_hand',
  ];

  /// Expert service currencies
  static const List<String> serviceCurrencies = ['GBP', 'EUR'];

  /// Max images per service
  static const int serviceMaxImages = 4;
}
