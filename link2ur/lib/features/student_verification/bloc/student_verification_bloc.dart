import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/student_verification.dart';
import '../../../data/repositories/student_verification_repository.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class StudentVerificationEvent extends Equatable {
  const StudentVerificationEvent();

  @override
  List<Object?> get props => [];
}

/// 加载认证状态
class StudentVerificationLoadRequested extends StudentVerificationEvent {
  const StudentVerificationLoadRequested();
}

/// 提交认证
class StudentVerificationSubmit extends StudentVerificationEvent {
  const StudentVerificationSubmit({
    required this.universityId,
    required this.email,
  });

  final int universityId;
  final String email;

  @override
  List<Object?> get props => [universityId, email];
}

/// 验证邮箱（输入验证码）
class StudentVerificationVerifyEmail extends StudentVerificationEvent {
  const StudentVerificationVerifyEmail(this.code);

  final String code;

  @override
  List<Object?> get props => [code];
}

/// 续期认证
class StudentVerificationRenew extends StudentVerificationEvent {
  const StudentVerificationRenew();
}

// ==================== State ====================

enum StudentVerificationStatus { initial, loading, loaded, error }

class StudentVerificationState extends Equatable {
  const StudentVerificationState({
    this.status = StudentVerificationStatus.initial,
    this.verification,
    this.errorMessage,
    this.isSubmitting = false,
    this.actionMessage,
  });

  final StudentVerificationStatus status;
  final StudentVerification? verification;
  final String? errorMessage;
  final bool isSubmitting;
  final String? actionMessage;

  bool get isLoading => status == StudentVerificationStatus.loading;

  StudentVerificationState copyWith({
    StudentVerificationStatus? status,
    StudentVerification? verification,
    String? errorMessage,
    bool? isSubmitting,
    String? actionMessage,
  }) {
    return StudentVerificationState(
      status: status ?? this.status,
      verification: verification ?? this.verification,
      errorMessage: errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        verification,
        errorMessage,
        isSubmitting,
        actionMessage,
      ];
}

// ==================== Bloc ====================

class StudentVerificationBloc
    extends Bloc<StudentVerificationEvent, StudentVerificationState> {
  StudentVerificationBloc(
      {required StudentVerificationRepository verificationRepository})
      : _repository = verificationRepository,
        super(const StudentVerificationState()) {
    on<StudentVerificationLoadRequested>(_onLoadRequested);
    on<StudentVerificationSubmit>(_onSubmit);
    on<StudentVerificationVerifyEmail>(_onVerifyEmail);
    on<StudentVerificationRenew>(_onRenew);
  }

  final StudentVerificationRepository _repository;

  Future<void> _onLoadRequested(
    StudentVerificationLoadRequested event,
    Emitter<StudentVerificationState> emit,
  ) async {
    emit(state.copyWith(status: StudentVerificationStatus.loading));

    try {
      final verification = await _repository.getVerificationStatus();
      emit(state.copyWith(
        status: StudentVerificationStatus.loaded,
        verification: verification,
      ));
    } catch (e) {
      AppLogger.error('Failed to load student verification', e);
      emit(state.copyWith(
        status: StudentVerificationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSubmit(
    StudentVerificationSubmit event,
    Emitter<StudentVerificationState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      await _repository.submitVerification(
        SubmitStudentVerificationRequest(
          universityId: event.universityId,
          email: event.email,
        ),
      );
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'verification_submitted',
      ));
      // 重新加载状态
      add(const StudentVerificationLoadRequested());
    } catch (e) {
      final errMsg = e.toString().replaceAll('StudentVerificationException: ', '');
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'submit_failed',
        errorMessage: errMsg,
      ));
    }
  }

  Future<void> _onVerifyEmail(
    StudentVerificationVerifyEmail event,
    Emitter<StudentVerificationState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      await _repository.verifyStudentEmail(code: event.code);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'verification_success',
      ));
      add(const StudentVerificationLoadRequested());
    } catch (e) {
      final errMsg = e.toString().replaceAll('StudentVerificationException: ', '');
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'verification_failed',
        errorMessage: errMsg,
      ));
    }
  }

  Future<void> _onRenew(
    StudentVerificationRenew event,
    Emitter<StudentVerificationState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      await _repository.renewVerification();
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'renewal_success',
      ));
      add(const StudentVerificationLoadRequested());
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'renewal_failed',
      ));
    }
  }
}
