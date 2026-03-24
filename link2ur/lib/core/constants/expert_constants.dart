class ExpertConstants {
  ExpertConstants._();

  /// Expert category keys — aligned with backend FeaturedTaskExpert.category
  static const List<String> categoryKeys = [
    'all',
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
  ];

  /// Service category keys (excludes 'all')
  static const List<String> serviceCategoryKeys = [
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
  ];

  /// Expert service currencies
  static const List<String> serviceCurrencies = ['GBP', 'CNY', 'USD'];

  /// Max images per service
  static const int serviceMaxImages = 4;
}
