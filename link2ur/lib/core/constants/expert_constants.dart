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
  ];

  /// Expert service currencies
  static const List<String> serviceCurrencies = ['GBP', 'CNY', 'USD'];

  /// Max images per service
  static const int serviceMaxImages = 4;
}
