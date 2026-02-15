import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/auth/bloc/auth_bloc.dart';
import 'package:link2ur/data/repositories/auth_repository.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  late MockAuthRepository mockAuthRepository;
  late AuthBloc authBloc;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    authBloc = AuthBloc(authRepository: mockAuthRepository);
    registerFallbackValues();
  });

  tearDown(() {
    authBloc.close();
  });

  group('AuthBloc', () {
    final testUser = createTestUser(
      id: '123',
      name: 'Test User',
      email: 'test@example.com',
    );

    test('initial state is correct', () {
      expect(authBloc.state, equals(const AuthState()));
      expect(authBloc.state.status, equals(AuthStatus.initial));
      expect(authBloc.state.user, isNull);
      expect(authBloc.state.errorMessage, isNull);
      expect(authBloc.state.codeSendStatus, equals(CodeSendStatus.initial));
      expect(authBloc.state.resetPasswordStatus, equals(ResetPasswordStatus.initial));
    });

    // ==================== 閭瀵嗙爜鐧诲綍 ====================

    group('AuthLoginRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [loading, authenticated] when login succeeds',
        build: () {
          when(() => mockAuthRepository.login(
                email: any(named: 'email'),
                password: any(named: 'password'),
              )).thenAnswer((_) async => testUser);
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthLoginRequested(
          email: 'test@example.com',
          password: 'password123',
        )),
        expect: () => [
          const AuthState(status: AuthStatus.loading),
          AuthState(
            status: AuthStatus.authenticated,
            user: testUser,
          ),
        ],
        verify: (_) {
          verify(() => mockAuthRepository.login(
                email: 'test@example.com',
                password: 'password123',
              )).called(1);
        },
      );

      blocTest<AuthBloc, AuthState>(
        'emits [loading, error] with AuthException message when AuthException is thrown',
        build: () {
          when(() => mockAuthRepository.login(
                email: any(named: 'email'),
                password: any(named: 'password'),
              )).thenThrow(const AuthException('invalid_credentials'));
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthLoginRequested(
          email: 'wrong@example.com',
          password: 'wrongpass',
        )),
        expect: () => [
          const AuthState(status: AuthStatus.loading),
          const AuthState(
            status: AuthStatus.error,
            errorMessage: 'invalid_credentials',
          ),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [loading, error] with generic message when unknown exception occurs',
        build: () {
          when(() => mockAuthRepository.login(
                email: any(named: 'email'),
                password: any(named: 'password'),
              )).thenThrow(Exception('Network error'));
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthLoginRequested(
          email: 'test@example.com',
          password: 'pass',
        )),
        expect: () => [
          const AuthState(status: AuthStatus.loading),
          const AuthState(
            status: AuthStatus.error,
            errorMessage: 'auth_error_login_failed',
          ),
        ],
      );
    });

    // ==================== 閭楠岃瘉鐮佺櫥褰?====================

    group('AuthLoginWithCodeRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [loading, authenticated] when email code login succeeds',
        build: () {
          when(() => mockAuthRepository.loginWithCode(
                email: any(named: 'email'),
                code: any(named: 'code'),
              )).thenAnswer((_) async => testUser);
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthLoginWithCodeRequested(
          email: 'test@example.com',
          code: '123456',
        )),
        expect: () => [
          const AuthState(status: AuthStatus.loading),
          AuthState(
            status: AuthStatus.authenticated,
            user: testUser,
          ),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [loading, error] when email code login fails',
        build: () {
          when(() => mockAuthRepository.loginWithCode(
                email: any(named: 'email'),
                code: any(named: 'code'),
              )).thenThrow(const AuthException('invalid_code'));
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthLoginWithCodeRequested(
          email: 'test@example.com',
          code: '000000',
        )),
        expect: () => [
          const AuthState(status: AuthStatus.loading),
          const AuthState(
            status: AuthStatus.error,
            errorMessage: 'invalid_code',
          ),
        ],
      );
    });

    // ==================== 鎵嬫満楠岃瘉鐮佺櫥褰?====================

    group('AuthLoginWithPhoneRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [loading, authenticated] when phone login succeeds',
        build: () {
          when(() => mockAuthRepository.loginWithPhoneCode(
                phone: any(named: 'phone'),
                code: any(named: 'code'),
              )).thenAnswer((_) async => testUser);
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthLoginWithPhoneRequested(
          phone: '13800138000',
          code: '123456',
        )),
        expect: () => [
          const AuthState(status: AuthStatus.loading),
          AuthState(
            status: AuthStatus.authenticated,
            user: testUser,
          ),
        ],
      );
    });

    // ==================== 娉ㄥ唽 ====================

    group('AuthRegisterRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [loading, authenticated] when register succeeds',
        build: () {
          when(() => mockAuthRepository.register(
                email: any(named: 'email'),
                password: any(named: 'password'),
                name: any(named: 'name'),
                code: any(named: 'code'),
              )).thenAnswer((_) async => testUser);
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthRegisterRequested(
          email: 'new@example.com',
          password: 'password123',
          name: 'New User',
          code: '123456',
        )),
        expect: () => [
          const AuthState(status: AuthStatus.loading),
          AuthState(
            status: AuthStatus.authenticated,
            user: testUser,
          ),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [loading, error] when register fails with AuthException',
        build: () {
          when(() => mockAuthRepository.register(
                email: any(named: 'email'),
                password: any(named: 'password'),
                name: any(named: 'name'),
                code: any(named: 'code'),
              )).thenThrow(const AuthException('閭宸茶娉ㄥ唽'));
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthRegisterRequested(
          email: 'existing@example.com',
          password: 'password123',
          name: 'User',
        )),
        expect: () => [
          const AuthState(status: AuthStatus.loading),
          const AuthState(
            status: AuthStatus.error,
            errorMessage: '閭宸茶娉ㄥ唽',
          ),
        ],
      );
    });

    // ==================== 鐧诲嚭 ====================

    group('AuthLogoutRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [unauthenticated] and clears user when logout',
        build: () {
          when(() => mockAuthRepository.logout()).thenAnswer((_) async {});
          return authBloc;
        },
        seed: () => AuthState(
          status: AuthStatus.authenticated,
          user: testUser,
        ),
        act: (bloc) => bloc.add(AuthLogoutRequested()),
        expect: () => [
          const AuthState(status: AuthStatus.unauthenticated),
        ],
        verify: (_) {
          verify(() => mockAuthRepository.logout()).called(1);
        },
      );

      blocTest<AuthBloc, AuthState>(
        'still emits unauthenticated even if logout API fails',
        build: () {
          when(() => mockAuthRepository.logout())
              .thenThrow(Exception('Network error'));
          return authBloc;
        },
        seed: () => AuthState(
          status: AuthStatus.authenticated,
          user: testUser,
        ),
        act: (bloc) => bloc.add(AuthLogoutRequested()),
        // 鍗充娇 logout API 澶辫触锛屼篃搴旇娓呴櫎鏈湴鐘舵€?
        expect: () => [
          const AuthState(status: AuthStatus.unauthenticated),
        ],
      );
    });

    // ==================== 妫€鏌ョ櫥褰曠姸鎬?====================

    group('AuthCheckRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [checking, authenticated] when user is logged in',
        build: () {
          when(() => mockAuthRepository.getCurrentUser())
              .thenAnswer((_) async => testUser);
          return authBloc;
        },
        act: (bloc) => bloc.add(AuthCheckRequested()),
        expect: () => [
          const AuthState(status: AuthStatus.checking),
          AuthState(
            status: AuthStatus.authenticated,
            user: testUser,
          ),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [checking, unauthenticated] when no user is logged in',
        build: () {
          when(() => mockAuthRepository.getCurrentUser())
              .thenAnswer((_) async => null);
          return authBloc;
        },
        act: (bloc) => bloc.add(AuthCheckRequested()),
        expect: () => [
          const AuthState(status: AuthStatus.checking),
          const AuthState(status: AuthStatus.unauthenticated),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [checking, unauthenticated] when check fails',
        build: () {
          when(() => mockAuthRepository.getCurrentUser())
              .thenThrow(Exception('Token expired'));
          return authBloc;
        },
        act: (bloc) => bloc.add(AuthCheckRequested()),
        expect: () => [
          const AuthState(status: AuthStatus.checking),
          const AuthState(status: AuthStatus.unauthenticated),
        ],
      );
    });

    // ==================== 鍙戦€侀偖绠遍獙璇佺爜 ====================

    group('AuthSendEmailCodeRequested', () {
      blocTest<AuthBloc, AuthState>(
        'updates codeSendStatus to sending then sent when successful',
        build: () {
          when(() => mockAuthRepository.sendEmailCode(any()))
              .thenAnswer((_) async {});
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthSendEmailCodeRequested(
          email: 'test@example.com',
        )),
        expect: () => [
          const AuthState(codeSendStatus: CodeSendStatus.sending),
          const AuthState(codeSendStatus: CodeSendStatus.sent),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'updates codeSendStatus to error with AuthException message',
        build: () {
          when(() => mockAuthRepository.sendEmailCode(any()))
              .thenThrow(const AuthException('too_many_requests'));
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthSendEmailCodeRequested(
          email: 'test@example.com',
        )),
        expect: () => [
          const AuthState(codeSendStatus: CodeSendStatus.sending),
          const AuthState(
            codeSendStatus: CodeSendStatus.error,
            errorMessage: 'too_many_requests',
          ),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'updates codeSendStatus to error with generic message on unknown exception',
        build: () {
          when(() => mockAuthRepository.sendEmailCode(any()))
              .thenThrow(Exception('Network error'));
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthSendEmailCodeRequested(
          email: 'test@example.com',
        )),
        expect: () => [
          const AuthState(codeSendStatus: CodeSendStatus.sending),
          const AuthState(
            codeSendStatus: CodeSendStatus.error,
            errorMessage: 'auth_error_send_code_failed',
          ),
        ],
      );
    });

    // ==================== 鐢ㄦ埛淇℃伅鏇存柊 ====================

    group('AuthUserUpdated', () {
      blocTest<AuthBloc, AuthState>(
        'updates user in state',
        build: () => authBloc,
        seed: () => AuthState(
          status: AuthStatus.authenticated,
          user: testUser,
        ),
        act: (bloc) {
          final updatedUser = createTestUser(
            id: '123',
            name: 'Updated Name',
            email: 'test@example.com',
          );
          bloc.add(AuthUserUpdated(user: updatedUser));
        },
        verify: (bloc) {
          expect(bloc.state.user?.name, equals('Updated Name'));
          expect(bloc.state.status, equals(AuthStatus.authenticated));
        },
      );
    });

    // ==================== 閲嶇疆瀵嗙爜 ====================

    group('AuthResetPasswordRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [loading, success] when reset password succeeds',
        build: () {
          when(() => mockAuthRepository.resetPassword(
                email: any(named: 'email'),
                code: any(named: 'code'),
                newPassword: any(named: 'newPassword'),
              )).thenAnswer((_) async {});
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthResetPasswordRequested(
          email: 'test@example.com',
          code: '123456',
          newPassword: 'newPassword123',
        )),
        expect: () => [
          const AuthState(resetPasswordStatus: ResetPasswordStatus.loading),
          const AuthState(
            resetPasswordStatus: ResetPasswordStatus.success,
            resetPasswordMessage: 'auth_reset_password_success',
          ),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [loading, error] when reset password fails',
        build: () {
          when(() => mockAuthRepository.resetPassword(
                email: any(named: 'email'),
                code: any(named: 'code'),
                newPassword: any(named: 'newPassword'),
              )).thenThrow(const AuthException('invalid_code'));
          return authBloc;
        },
        act: (bloc) => bloc.add(const AuthResetPasswordRequested(
          email: 'test@example.com',
          code: '000000',
          newPassword: 'newPassword123',
        )),
        expect: () => [
          const AuthState(resetPasswordStatus: ResetPasswordStatus.loading),
          const AuthState(
            resetPasswordStatus: ResetPasswordStatus.error,
            resetPasswordMessage: 'invalid_code',
          ),
        ],
      );
    });

    // ==================== 鐘舵€佽緟鍔╂柟娉?====================

    group('AuthState helpers', () {
      test('isAuthenticated returns true when authenticated with user', () {
        final state = AuthState(
          status: AuthStatus.authenticated,
          user: testUser,
        );
        expect(state.isAuthenticated, isTrue);
      });

      test('isAuthenticated returns false when authenticated without user', () {
        const state = AuthState(status: AuthStatus.authenticated);
        expect(state.isAuthenticated, isFalse);
      });

      test('isLoading returns true for loading status', () {
        const state = AuthState(status: AuthStatus.loading);
        expect(state.isLoading, isTrue);
      });

      test('isLoading returns true for checking status', () {
        const state = AuthState(status: AuthStatus.checking);
        expect(state.isLoading, isTrue);
      });

      test('hasError returns true when error status with message', () {
        const state = AuthState(
          status: AuthStatus.error,
          errorMessage: 'Some error',
        );
        expect(state.hasError, isTrue);
      });

      test('hasError returns false when error status without message', () {
        const state = AuthState(status: AuthStatus.error);
        expect(state.hasError, isFalse);
      });
    });
  });
}

