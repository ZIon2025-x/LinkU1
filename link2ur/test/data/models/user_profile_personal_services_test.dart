import 'package:flutter_test/flutter_test.dart';
import 'package:link2ur/data/models/user.dart';

void main() {
  group('UserProfileDetail.personalServices', () {
    Map<String, dynamic> baseJson() => <String, dynamic>{
      'user': <String, dynamic>{
        'id': '00000099',
        'name': '周哲',
        'avatar': null,
        'created_at': '2025-01-01T00:00:00Z',
        'is_verified': false,
        'user_level': 'vip',
        'avg_rating': 4.9,
        'task_count': 0,
        'completed_task_count': 18,
        'is_expert': false,
        'is_student_verified': true,
        'profile_views': 0,
        'bio': '测试',
        'residence_city': 'London',
        'followers_count': 0,
        'following_count': 0,
        'is_following': false,
        'displayed_badge': null,
      },
      'stats': <String, dynamic>{},
      'recent_tasks': <dynamic>[],
      'reviews': <dynamic>[],
      'recent_forum_posts': <dynamic>[],
      'sold_flea_items': <dynamic>[],
    };

    test('parses non-empty personal_services array', () {
      final json = baseJson();
      json['personal_services'] = <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 1,
          'service_name': '家教 · 小学数学',
          'service_name_en': null,
          'service_name_zh': null,
          'description': 'UCL 在读',
          'category': 'tutoring',
          'base_price': 15.0,
          'currency': 'GBP',
          'pricing_type': 'fixed',
          'location_type': 'both',
          'location': 'London',
          'images': <String>[],
          'status': 'active',
        },
      ];

      final detail = UserProfileDetail.fromJson(json);
      expect(detail.personalServices, hasLength(1));
      final s = detail.personalServices.first;
      expect(s.id, 1);
      expect(s.serviceName, '家教 · 小学数学');
      expect(s.category, 'tutoring');
      expect(s.basePrice, 15.0);
      expect(s.currency, 'GBP');
      expect(s.pricingType, 'fixed');
    });

    test('defaults to empty list when key absent', () {
      final detail = UserProfileDetail.fromJson(baseJson());
      expect(detail.personalServices, isEmpty);
    });

    test('defaults to empty list when key is null', () {
      final json = baseJson();
      json['personal_services'] = null;
      final detail = UserProfileDetail.fromJson(json);
      expect(detail.personalServices, isEmpty);
    });
  });
}
