import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/user_profile_repository.dart';

// ==================== Events ====================

abstract class IdentityOnboardingEvent extends Equatable {
  const IdentityOnboardingEvent();

  @override
  List<Object?> get props => [];
}

class OnboardingSetIdentity extends IdentityOnboardingEvent {
  final String identity;
  const OnboardingSetIdentity(this.identity);

  @override
  List<Object?> get props => [identity];
}

class OnboardingSetCity extends IdentityOnboardingEvent {
  final String city;
  const OnboardingSetCity(this.city);

  @override
  List<Object?> get props => [city];
}

class OnboardingSetInterests extends IdentityOnboardingEvent {
  final List<String> interests;
  const OnboardingSetInterests(this.interests);

  @override
  List<Object?> get props => [interests];
}

class OnboardingSetProfile extends IdentityOnboardingEvent {
  const OnboardingSetProfile({this.name, this.email, this.phone});
  final String? name;
  final String? email;
  final String? phone;
  @override
  List<Object?> get props => [name, email, phone];
}

class OnboardingSubmit extends IdentityOnboardingEvent {
  const OnboardingSubmit();
}

// ==================== State ====================

class IdentityOnboardingState extends Equatable {
  final String? identity;
  final String? city;
  final String? name;
  final List<String> interests;
  final int currentStep;
  final bool isSubmitting;
  final bool isComplete;
  final String? errorMessage;

  const IdentityOnboardingState({
    this.identity,
    this.city,
    this.name,
    this.interests = const [],
    this.currentStep = 0,
    this.isSubmitting = false,
    this.isComplete = false,
    this.errorMessage,
  });

  IdentityOnboardingState copyWith({
    String? identity,
    String? city,
    String? name,
    List<String>? interests,
    int? currentStep,
    bool? isSubmitting,
    bool? isComplete,
    String? errorMessage,
  }) {
    return IdentityOnboardingState(
      identity: identity ?? this.identity,
      city: city ?? this.city,
      name: name ?? this.name,
      interests: interests ?? this.interests,
      currentStep: currentStep ?? this.currentStep,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isComplete: isComplete ?? this.isComplete,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        identity,
        city,
        name,
        interests,
        currentStep,
        isSubmitting,
        isComplete,
        errorMessage,
      ];
}

// ==================== BLoC ====================

class IdentityOnboardingBloc
    extends Bloc<IdentityOnboardingEvent, IdentityOnboardingState> {
  final UserProfileRepository _repository;

  IdentityOnboardingBloc({required UserProfileRepository repository})
      : _repository = repository,
        super(const IdentityOnboardingState()) {
    on<OnboardingSetIdentity>(_onSetIdentity);
    on<OnboardingSetCity>(_onSetCity);
    on<OnboardingSetInterests>(_onSetInterests);
    on<OnboardingSetProfile>(_onSetProfile);
    on<OnboardingSubmit>(_onSubmit);
  }

  void _onSetIdentity(
    OnboardingSetIdentity event,
    Emitter<IdentityOnboardingState> emit,
  ) {
    emit(state.copyWith(
      identity: event.identity,
      currentStep: 1,
    ));
  }

  void _onSetCity(
    OnboardingSetCity event,
    Emitter<IdentityOnboardingState> emit,
  ) {
    emit(state.copyWith(
      city: event.city,
      currentStep: 2,
    ));
  }

  void _onSetInterests(
    OnboardingSetInterests event,
    Emitter<IdentityOnboardingState> emit,
  ) {
    emit(state.copyWith(interests: event.interests));
  }

  void _onSetProfile(
    OnboardingSetProfile event,
    Emitter<IdentityOnboardingState> emit,
  ) {
    emit(state.copyWith(
      name: event.name,
    ));
  }

  Future<void> _onSubmit(
    OnboardingSubmit event,
    Emitter<IdentityOnboardingState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _repository.submitOnboarding(
        capabilities: const [],
        identity: state.identity,
        city: state.city,
        name: state.name,
        interests: state.interests,
      );
      emit(state.copyWith(
        isSubmitting: false,
        isComplete: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      ));
    }
  }
}
