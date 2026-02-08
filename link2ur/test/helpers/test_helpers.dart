import 'package:mocktail/mocktail.dart';
import 'package:link2ur/data/repositories/auth_repository.dart';
import 'package:link2ur/data/repositories/forum_repository.dart';
import 'package:link2ur/data/repositories/flea_market_repository.dart';
import 'package:link2ur/data/repositories/message_repository.dart';
import 'package:link2ur/data/repositories/task_repository.dart';
import 'package:link2ur/data/repositories/payment_repository.dart';
import 'package:link2ur/data/services/api_service.dart';
import 'package:link2ur/data/services/storage_service.dart';
import 'package:link2ur/data/models/user.dart';

// Mock classes for testing

class MockAuthRepository extends Mock implements AuthRepository {}

class MockPaymentRepository extends Mock implements PaymentRepository {}

class MockForumRepository extends Mock implements ForumRepository {}

class MockFleaMarketRepository extends Mock implements FleaMarketRepository {}

class MockMessageRepository extends Mock implements MessageRepository {}

class MockTaskRepository extends Mock implements TaskRepository {}

class MockApiService extends Mock implements ApiService {}

class MockStorageService extends Mock implements StorageService {}

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
