import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/settings/bloc/settings_bloc.dart';
import 'package:link2ur/data/services/api_service.dart';

import '../../../helpers/test_helpers.dart';

void main() {
  late MockApiService mockApiService;
  late MockUserRepository mockUserRepo;
  late SettingsBloc bloc;

  setUp(() {
    mockApiService = MockApiService();
    mockUserRepo = MockUserRepository();
    bloc = SettingsBloc(
      apiService: mockApiService,
      userRepository: mockUserRepo,
    );
  });

  tearDown(() {
    bloc.close();
  });

  group('SettingsBloc', () {
    // ==================== Initial State ====================

    test('initial state has correct defaults', () {
      expect(bloc.state.themeMode, equals(ThemeMode.system));
      // locale depends on device locale; just check it's non-empty
      expect(bloc.state.locale, isNotEmpty);
      expect(bloc.state.notificationsEnabled, isTrue);
      expect(bloc.state.soundEnabled, isTrue);
      expect(bloc.state.cacheSize, equals('common_loading'));
      expect(bloc.state.appVersion, isEmpty);
      expect(bloc.state.isClearingCache, isFalse);
      expect(bloc.state.isDeletingAccount, isFalse);
      expect(bloc.state.deleteAccountError, isNull);
      expect(bloc.state.errorMessage, isNull);
    });

    test('initial state with null apiService', () {
      final blocNoApi = SettingsBloc();
      expect(blocNoApi.state.themeMode, equals(ThemeMode.system));
      expect(blocNoApi.state.isDeletingAccount, isFalse);
      expect(blocNoApi.apiService, isNull);
      blocNoApi.close();
    });

    // ==================== SettingsDeleteAccount ====================

    group('SettingsDeleteAccount', () {
      blocTest<SettingsBloc, SettingsState>(
        'emits isDeletingAccount=true then error when apiService succeeds '
        'but StorageService.instance throws',
        build: () {
          when(() => mockApiService.delete<dynamic>(
                any(),
                data: any(named: 'data'),
                queryParameters: any(named: 'queryParameters'),
                fromJson: any(named: 'fromJson'),
                options: any(named: 'options'),
                cancelToken: any(named: 'cancelToken'),
              )).thenAnswer((_) async => ApiResponse.success());
          return SettingsBloc(
            apiService: mockApiService,
            userRepository: mockUserRepo,
          );
        },
        act: (bloc) => bloc.add(const SettingsDeleteAccount()),
        expect: () => [
          // 1. isDeletingAccount = true
          isA<SettingsState>()
              .having(
                  (s) => s.isDeletingAccount, 'isDeletingAccount', isTrue)
              .having((s) => s.deleteAccountError, 'deleteAccountError',
                  isNull),
          // 2. isDeletingAccount = false with deleteAccountError
          //    (StorageService.instance.clearAll() throws because singleton
          //    is not initialized in tests)
          isA<SettingsState>()
              .having(
                  (s) => s.isDeletingAccount, 'isDeletingAccount', isFalse)
              .having((s) => s.deleteAccountError, 'deleteAccountError',
                  isNotNull),
        ],
        verify: (_) {
          verify(() => mockApiService.delete<dynamic>(
                '/api/users/me',
                data: any(named: 'data'),
                queryParameters: any(named: 'queryParameters'),
                fromJson: any(named: 'fromJson'),
                options: any(named: 'options'),
                cancelToken: any(named: 'cancelToken'),
              )).called(1);
        },
      );

      blocTest<SettingsBloc, SettingsState>(
        'emits isDeletingAccount=true then error when apiService is null '
        '(StorageService.instance throws)',
        build: () => SettingsBloc(
          apiService: null,
          userRepository: mockUserRepo,
        ),
        act: (bloc) => bloc.add(const SettingsDeleteAccount()),
        expect: () => [
          // 1. isDeletingAccount = true
          isA<SettingsState>()
              .having(
                  (s) => s.isDeletingAccount, 'isDeletingAccount', isTrue),
          // 2. isDeletingAccount = false with deleteAccountError
          //    (StorageService.instance.clearAll() throws)
          isA<SettingsState>()
              .having(
                  (s) => s.isDeletingAccount, 'isDeletingAccount', isFalse)
              .having((s) => s.deleteAccountError, 'deleteAccountError',
                  isNotNull),
        ],
      );

      blocTest<SettingsBloc, SettingsState>(
        'emits isDeletingAccount=true then error when apiService.delete throws',
        build: () {
          when(() => mockApiService.delete<dynamic>(
                any(),
                data: any(named: 'data'),
                queryParameters: any(named: 'queryParameters'),
                fromJson: any(named: 'fromJson'),
                options: any(named: 'options'),
                cancelToken: any(named: 'cancelToken'),
              )).thenThrow(Exception('Network error'));
          return SettingsBloc(
            apiService: mockApiService,
            userRepository: mockUserRepo,
          );
        },
        act: (bloc) => bloc.add(const SettingsDeleteAccount()),
        expect: () => [
          // 1. isDeletingAccount = true
          isA<SettingsState>()
              .having(
                  (s) => s.isDeletingAccount, 'isDeletingAccount', isTrue),
          // 2. isDeletingAccount = false with error from apiService throw
          isA<SettingsState>()
              .having(
                  (s) => s.isDeletingAccount, 'isDeletingAccount', isFalse)
              .having((s) => s.deleteAccountError, 'deleteAccountError',
                  contains('Network error')),
        ],
      );

      blocTest<SettingsBloc, SettingsState>(
        'double-tap guard: does nothing when isDeletingAccount is already true',
        build: () => SettingsBloc(
          apiService: mockApiService,
          userRepository: mockUserRepo,
        ),
        seed: () => const SettingsState(isDeletingAccount: true),
        act: (bloc) => bloc.add(const SettingsDeleteAccount()),
        expect: () => [],
      );
    });

    // ==================== SettingsState.copyWith ====================

    group('SettingsState.copyWith', () {
      test('copies all fields correctly', () {
        const original = SettingsState(
          themeMode: ThemeMode.dark,
          locale: 'en',
          notificationsEnabled: false,
          soundEnabled: false,
          cacheSize: '10 MB',
          appVersion: '1.0.0',
          isClearingCache: true,
          isDeletingAccount: true,
          deleteAccountError: 'some error',
          errorMessage: 'some message',
        );

        final copied = original.copyWith(
          themeMode: ThemeMode.light,
          locale: 'zh',
          notificationsEnabled: true,
          soundEnabled: true,
          cacheSize: '0 B',
          appVersion: '2.0.0',
          isClearingCache: false,
          isDeletingAccount: false,
          deleteAccountError: 'new error',
          errorMessage: 'new message',
        );

        expect(copied.themeMode, equals(ThemeMode.light));
        expect(copied.locale, equals('zh'));
        expect(copied.notificationsEnabled, isTrue);
        expect(copied.soundEnabled, isTrue);
        expect(copied.cacheSize, equals('0 B'));
        expect(copied.appVersion, equals('2.0.0'));
        expect(copied.isClearingCache, isFalse);
        expect(copied.isDeletingAccount, isFalse);
        expect(copied.deleteAccountError, equals('new error'));
        expect(copied.errorMessage, equals('new message'));
      });

      test('preserves unchanged fields when only some are specified', () {
        const original = SettingsState(
          themeMode: ThemeMode.dark,
          locale: 'en',
          notificationsEnabled: false,
          soundEnabled: false,
          cacheSize: '10 MB',
        );

        final copied = original.copyWith(themeMode: ThemeMode.light);

        expect(copied.themeMode, equals(ThemeMode.light));
        expect(copied.locale, equals('en'));
        expect(copied.notificationsEnabled, isFalse);
        expect(copied.soundEnabled, isFalse);
        expect(copied.cacheSize, equals('10 MB'));
      });

      test('deleteAccountError is replaced (not preserved) when omitted', () {
        const original = SettingsState(
          deleteAccountError: 'some error',
        );
        // copyWith without deleteAccountError sets it to null
        final copied = original.copyWith(isDeletingAccount: false);
        expect(copied.deleteAccountError, isNull);
      });

      test('errorMessage is replaced (not preserved) when omitted', () {
        const original = SettingsState(
          errorMessage: 'some error',
        );
        // copyWith without errorMessage sets it to null
        final copied = original.copyWith(isClearingCache: false);
        expect(copied.errorMessage, isNull);
      });
    });

    // ==================== SettingsEvent equality ====================

    group('SettingsEvent equality', () {
      test('SettingsLoadRequested events are equal', () {
        const a = SettingsLoadRequested();
        const b = SettingsLoadRequested();
        expect(a, equals(b));
      });

      test('SettingsThemeChanged events with same mode are equal', () {
        const a = SettingsThemeChanged(ThemeMode.dark);
        const b = SettingsThemeChanged(ThemeMode.dark);
        expect(a, equals(b));
      });

      test('SettingsThemeChanged events with different modes are not equal', () {
        const a = SettingsThemeChanged(ThemeMode.dark);
        const b = SettingsThemeChanged(ThemeMode.light);
        expect(a, isNot(equals(b)));
      });

      test('SettingsLanguageChanged events with same locale are equal', () {
        const a = SettingsLanguageChanged('en');
        const b = SettingsLanguageChanged('en');
        expect(a, equals(b));
      });

      test('SettingsLanguageChanged events with different locales are not equal',
          () {
        const a = SettingsLanguageChanged('en');
        const b = SettingsLanguageChanged('zh');
        expect(a, isNot(equals(b)));
      });

      test('SettingsNotificationToggled events with same value are equal', () {
        const a = SettingsNotificationToggled(true);
        const b = SettingsNotificationToggled(true);
        expect(a, equals(b));
      });

      test(
          'SettingsNotificationToggled events with different values are not equal',
          () {
        const a = SettingsNotificationToggled(true);
        const b = SettingsNotificationToggled(false);
        expect(a, isNot(equals(b)));
      });

      test('SettingsSoundToggled events with same value are equal', () {
        const a = SettingsSoundToggled(true);
        const b = SettingsSoundToggled(true);
        expect(a, equals(b));
      });

      test('SettingsSoundToggled events with different values are not equal',
          () {
        const a = SettingsSoundToggled(true);
        const b = SettingsSoundToggled(false);
        expect(a, isNot(equals(b)));
      });

      test('SettingsClearCache events are equal', () {
        const a = SettingsClearCache();
        const b = SettingsClearCache();
        expect(a, equals(b));
      });

      test('SettingsDeleteAccount events are equal', () {
        const a = SettingsDeleteAccount();
        const b = SettingsDeleteAccount();
        expect(a, equals(b));
      });

      test('SettingsCalculateCacheSize events are equal', () {
        const a = SettingsCalculateCacheSize();
        const b = SettingsCalculateCacheSize();
        expect(a, equals(b));
      });
    });

    // ==================== SettingsState equality ====================

    group('SettingsState equality', () {
      test('states with same values are equal', () {
        const a = SettingsState(
          themeMode: ThemeMode.dark,
          locale: 'en',
          notificationsEnabled: true,
          soundEnabled: false,
        );
        const b = SettingsState(
          themeMode: ThemeMode.dark,
          locale: 'en',
          notificationsEnabled: true,
          soundEnabled: false,
        );
        expect(a, equals(b));
      });

      test('states with different themeMode are not equal', () {
        const a = SettingsState(themeMode: ThemeMode.dark);
        const b = SettingsState(themeMode: ThemeMode.light);
        expect(a, isNot(equals(b)));
      });

      test('states with different locale are not equal', () {
        const a = SettingsState(locale: 'en');
        const b = SettingsState(locale: 'zh');
        expect(a, isNot(equals(b)));
      });

      test('states with different isDeletingAccount are not equal', () {
        const a = SettingsState(isDeletingAccount: true);
        const b = SettingsState(isDeletingAccount: false);
        expect(a, isNot(equals(b)));
      });

      test('states with different deleteAccountError are not equal', () {
        const a = SettingsState(deleteAccountError: 'error');
        const b = SettingsState(deleteAccountError: null);
        expect(a, isNot(equals(b)));
      });
    });
  });
}
