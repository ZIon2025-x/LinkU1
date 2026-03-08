import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:link2ur/features/student_verification/bloc/student_verification_bloc.dart';
import 'package:link2ur/data/models/student_verification.dart';
import 'package:link2ur/data/repositories/student_verification_repository.dart';

class MockStudentVerificationRepository extends Mock
    implements StudentVerificationRepository {}

void main() {
  late MockStudentVerificationRepository mockRepo;
  late StudentVerificationBloc bloc;

  final testVerification = StudentVerification(
    isVerified: true,
    status: 'verified',
    email: 'student@uni.edu',
    verifiedAt: DateTime(2026, 1, 1),
    expiresAt: DateTime(2027, 1, 1),
    daysRemaining: 365,
  );

  const unverifiedStatus = StudentVerification(
    isVerified: false,
    status: 'pending',
  );

  setUp(() {
    mockRepo = MockStudentVerificationRepository();
    bloc = StudentVerificationBloc(
      verificationRepository: mockRepo,
    );
  });

  tearDown(() {
    bloc.close();
  });

  group('StudentVerificationBloc', () {
    test('initial state is correct', () {
      expect(bloc.state.status, equals(StudentVerificationStatus.initial));
      expect(bloc.state.verification, isNull);
      expect(bloc.state.isSubmitting, isFalse);
      expect(bloc.state.actionMessage, isNull);
      expect(bloc.state.errorMessage, isNull);
    });

    group('StudentVerificationLoadRequested', () {
      blocTest<StudentVerificationBloc, StudentVerificationState>(
        'emits [loading, loaded] when load succeeds',
        build: () {
          when(() => mockRepo.getVerificationStatus())
              .thenAnswer((_) async => testVerification);
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const StudentVerificationLoadRequested()),
        expect: () => [
          const StudentVerificationState(
              status: StudentVerificationStatus.loading),
          StudentVerificationState(
            status: StudentVerificationStatus.loaded,
            verification: testVerification,
          ),
        ],
      );

      blocTest<StudentVerificationBloc, StudentVerificationState>(
        'emits [loading, error] when load fails',
        build: () {
          when(() => mockRepo.getVerificationStatus())
              .thenThrow(Exception('Network error'));
          return bloc;
        },
        act: (bloc) =>
            bloc.add(const StudentVerificationLoadRequested()),
        expect: () => [
          const StudentVerificationState(
              status: StudentVerificationStatus.loading),
          isA<StudentVerificationState>()
              .having((s) => s.status, 'status',
                  StudentVerificationStatus.error)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    group('StudentVerificationSubmit', () {
      blocTest<StudentVerificationBloc, StudentVerificationState>(
        'emits submitting then loaded with verification on success',
        build: () {
          when(() => mockRepo.submitVerification(email: any(named: 'email')))
              .thenAnswer((_) async {});
          when(() => mockRepo.getVerificationStatus())
              .thenAnswer((_) async => unverifiedStatus);
          return bloc;
        },
        act: (bloc) => bloc.add(
            const StudentVerificationSubmit(email: 'student@uni.edu')),
        expect: () => [
          isA<StudentVerificationState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<StudentVerificationState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'verification_submitted'),
          // Re-load triggered internally
          isA<StudentVerificationState>()
              .having((s) => s.status, 'status',
                  StudentVerificationStatus.loading),
          isA<StudentVerificationState>()
              .having((s) => s.status, 'status',
                  StudentVerificationStatus.loaded),
        ],
      );

      blocTest<StudentVerificationBloc, StudentVerificationState>(
        'emits error on failure',
        build: () {
          when(() => mockRepo.submitVerification(email: any(named: 'email')))
              .thenThrow(Exception('Submit failed'));
          return bloc;
        },
        act: (bloc) => bloc.add(
            const StudentVerificationSubmit(email: 'student@uni.edu')),
        expect: () => [
          isA<StudentVerificationState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<StudentVerificationState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    group('StudentVerificationVerifyEmail', () {
      blocTest<StudentVerificationBloc, StudentVerificationState>(
        'emits loaded with verified status on success',
        build: () {
          when(() => mockRepo.verifyStudentEmail(token: any(named: 'token')))
              .thenAnswer((_) async {});
          when(() => mockRepo.getVerificationStatus())
              .thenAnswer((_) async => testVerification);
          return bloc;
        },
        act: (bloc) => bloc.add(
            const StudentVerificationVerifyEmail('verify-token')),
        expect: () => [
          isA<StudentVerificationState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<StudentVerificationState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'verification_success'),
          // Re-load triggered internally
          isA<StudentVerificationState>()
              .having((s) => s.status, 'status',
                  StudentVerificationStatus.loading),
          isA<StudentVerificationState>()
              .having((s) => s.status, 'status',
                  StudentVerificationStatus.loaded),
        ],
      );

      blocTest<StudentVerificationBloc, StudentVerificationState>(
        'emits error on verification failure',
        build: () {
          when(() => mockRepo.verifyStudentEmail(token: any(named: 'token')))
              .thenThrow(Exception('Invalid token'));
          return bloc;
        },
        act: (bloc) => bloc.add(
            const StudentVerificationVerifyEmail('bad-token')),
        expect: () => [
          isA<StudentVerificationState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<StudentVerificationState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });

    group('StudentVerificationRenew', () {
      blocTest<StudentVerificationBloc, StudentVerificationState>(
        'emits loaded with renewed verification on success',
        build: () {
          when(() => mockRepo.renewVerification(email: any(named: 'email')))
              .thenAnswer((_) async {});
          when(() => mockRepo.getVerificationStatus())
              .thenAnswer((_) async => testVerification);
          return bloc;
        },
        seed: () => StudentVerificationState(
          status: StudentVerificationStatus.loaded,
          verification: testVerification,
        ),
        act: (bloc) => bloc.add(const StudentVerificationRenew()),
        expect: () => [
          isA<StudentVerificationState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<StudentVerificationState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.actionMessage, 'actionMessage',
                  'renewal_success'),
          // Re-load triggered internally
          isA<StudentVerificationState>()
              .having((s) => s.status, 'status',
                  StudentVerificationStatus.loading),
          isA<StudentVerificationState>()
              .having((s) => s.status, 'status',
                  StudentVerificationStatus.loaded),
        ],
      );

      blocTest<StudentVerificationBloc, StudentVerificationState>(
        'emits error on renew failure',
        build: () {
          when(() => mockRepo.renewVerification(email: any(named: 'email')))
              .thenThrow(Exception('Renew failed'));
          return bloc;
        },
        seed: () => StudentVerificationState(
          status: StudentVerificationStatus.loaded,
          verification: testVerification,
        ),
        act: (bloc) => bloc.add(const StudentVerificationRenew()),
        expect: () => [
          isA<StudentVerificationState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isTrue),
          isA<StudentVerificationState>()
              .having((s) => s.isSubmitting, 'isSubmitting', isFalse)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );
    });
  });
}
