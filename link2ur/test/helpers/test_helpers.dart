import 'package:mocktail/mocktail.dart';
import 'package:link2ur/data/repositories/auth_repository.dart';
import 'package:link2ur/data/repositories/forum_repository.dart';
import 'package:link2ur/data/repositories/flea_market_repository.dart';
import 'package:link2ur/data/repositories/message_repository.dart';
import 'package:link2ur/data/repositories/notification_repository.dart';
import 'package:link2ur/data/repositories/task_repository.dart';
import 'package:link2ur/data/repositories/payment_repository.dart';
import 'package:link2ur/data/repositories/user_repository.dart';
import 'package:link2ur/data/repositories/coupon_points_repository.dart';
import 'package:link2ur/data/repositories/leaderboard_repository.dart';
import 'package:link2ur/data/repositories/activity_repository.dart';
import 'package:link2ur/data/repositories/student_verification_repository.dart';
import 'package:link2ur/data/repositories/task_expert_repository.dart';
import 'package:link2ur/data/repositories/common_repository.dart';
import 'package:link2ur/data/repositories/discovery_repository.dart';
import 'package:link2ur/data/repositories/personal_service_repository.dart';
import 'package:link2ur/data/repositories/question_repository.dart';
import 'package:link2ur/data/services/api_service.dart';
import 'package:link2ur/data/services/storage_service.dart';
import 'package:link2ur/data/models/user.dart';

// Mock classes for testing

class MockAuthRepository extends Mock implements AuthRepository {}

class MockPaymentRepository extends Mock implements PaymentRepository {}

class MockForumRepository extends Mock implements ForumRepository {}

class MockFleaMarketRepository extends Mock implements FleaMarketRepository {}

class MockMessageRepository extends Mock implements MessageRepository {}

class MockNotificationRepository extends Mock
    implements NotificationRepository {}

class MockTaskRepository extends Mock implements TaskRepository {}

class MockApiService extends Mock implements ApiService {}

class MockStorageService extends Mock implements StorageService {}

class MockUserRepository extends Mock implements UserRepository {}

class MockCouponPointsRepository extends Mock
    implements CouponPointsRepository {}

class MockLeaderboardRepository extends Mock
    implements LeaderboardRepository {}

class MockActivityRepository extends Mock implements ActivityRepository {}

class MockStudentVerificationRepository extends Mock
    implements StudentVerificationRepository {}

class MockTaskExpertRepository extends Mock implements TaskExpertRepository {}

class MockCommonRepository extends Mock implements CommonRepository {}

class MockDiscoveryRepository extends Mock implements DiscoveryRepository {}

class MockQuestionRepository extends Mock implements QuestionRepository {}

// Test data helpers

/// 创建测试用户对象
User createTestUser({
  String id = '1',
  String name = 'testuser',
  String? email = 'test@example.com',
  String? avatar,
  String? userLevel = 'normal',
}) {
  return User(
    id: id,
    name: name,
    email: email,
    avatar: avatar,
    userLevel: userLevel,
    createdAt: DateTime.now(),
  );
}

/// 注册 Mocktail fallback 值
void registerFallbackValues() {
  // 如果有需要的 fallback 值，在这里注册
  // 例如: registerFallbackValue(FakeUser());
}
