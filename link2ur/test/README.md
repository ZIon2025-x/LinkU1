# Link2Ur 测试文档

本目录包含 Link2Ur Flutter 应用的自动化测试。

## 测试结构

```
test/
├── helpers/
│   └── test_helpers.dart          # 测试工具类和 Mock 对象
├── features/
│   ├── auth/
│   │   └── bloc/
│   │       └── auth_bloc_test.dart    # 认证 BLoC 测试
│   └── payment/
│       └── bloc/
│           └── payment_bloc_test.dart  # 支付 BLoC 测试
└── data/
    └── services/
        └── api_service_test.dart      # API 服务测试（框架）
```

## 运行测试

### 运行所有测试
```bash
cd link2ur
flutter test
```

### 运行特定测试文件
```bash
flutter test test/features/auth/bloc/auth_bloc_test.dart
```

### 运行测试并查看覆盖率
```bash
flutter test --coverage
```

查看覆盖率报告（需要安装 lcov）：
```bash
# Windows (使用 genhtml)
genhtml coverage/lcov.info -o coverage/html
start coverage/html/index.html

# Mac/Linux
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## 已实现的测试

### ✅ AuthBloc 测试
- 登录流程（用户名/密码、邮箱验证码）
- 登出流程
- 状态检查
- 验证码发送
- 错误处理

### ✅ PaymentBloc 测试
- 创建支付意向
- 优惠券选择/移除
- 支付方式切换
- 支付状态转换（processing → success/error）
- 支付状态查询

### 🚧 ApiService 测试（框架）
- Token 刷新逻辑（待实现）
- 并发 401 处理（待实现）
- 错误重试逻辑（待实现）

完整的 ApiService 测试需要 mock Dio 实例，推荐使用 `http_mock_adapter` 包。

## 测试依赖

已添加的测试工具：
- `flutter_test` - Flutter 测试框架
- `bloc_test` (^9.1.7) - BLoC 测试工具
- `mocktail` (^1.0.4) - Mock 对象生成

## 编写新测试

### 1. 创建 Mock 对象

在 `test/helpers/test_helpers.dart` 中添加：
```dart
class MockYourRepository extends Mock implements YourRepository {}
```

### 2. 编写 BLoC 测试

使用 `bloc_test` 包：
```dart
blocTest<YourBloc, YourState>(
  'description of the test',
  build: () {
    // Setup mocks
    when(() => mockRepo.method()).thenAnswer((_) async => result);
    return yourBloc;
  },
  act: (bloc) => bloc.add(YourEvent()),
  expect: () => [
    ExpectedState1(),
    ExpectedState2(),
  ],
);
```

### 3. 运行测试

```bash
flutter test test/path/to/your_test.dart
```

## 测试最佳实践

1. **每个测试应该独立** - 使用 `setUp()` 和 `tearDown()` 清理状态
2. **测试命名清晰** - 描述测试的行为和预期结果
3. **测试边界情况** - 成功、失败、空值、网络错误等
4. **验证副作用** - 使用 `verify()` 确认方法被调用
5. **保持测试简单** - 一个测试只验证一个行为

## 下一步

需要添加的测试：

### 高优先级
- [ ] ApiService 完整测试（使用 http_mock_adapter）
- [ ] WalletBloc 测试
- [ ] TaskDetailBloc 测试
- [ ] Widget 测试（关键 UI 组件）

### 中优先级
- [ ] Repository 集成测试
- [ ] WebSocketService 测试
- [ ] StorageService 测试
- [ ] 端到端测试（golden tests）

### 低优先级
- [ ] 其他 BLoC 测试
- [ ] 工具类单元测试
- [ ] 性能测试

## 持续集成

在 CI/CD 流程中运行测试：
```yaml
# .github/workflows/test.yml
- name: Run tests
  run: flutter test --coverage
- name: Upload coverage
  uses: codecov/codecov-action@v3
```

## 故障排查

### 测试失败：找不到 Mock 类
确保在 `test_helpers.dart` 中注册了 fallback 值：
```dart
registerFallbackValue(FakeYourType());
```

### 测试超时
增加超时时间：
```dart
testWidgets('description', (tester) async {
  // test code
}, timeout: const Timeout(Duration(seconds: 30)));
```

### Mock 不工作
检查是否正确使用 `when()` 和 `any()`/`named`:
```dart
when(() => mock.method(
  arg1: any(named: 'arg1'),
  arg2: any(named: 'arg2'),
)).thenAnswer((_) async => result);
```

## 资源

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [bloc_test Package](https://pub.dev/packages/bloc_test)
- [mocktail Package](https://pub.dev/packages/mocktail)
- [Test-Driven Development with Flutter](https://resocoder.com/flutter-tdd-clean-architecture-course/)
