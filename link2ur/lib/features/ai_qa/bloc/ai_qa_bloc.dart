import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/ai_qa.dart';
import '../../../data/repositories/ai_qa_repository.dart';

// ============================================================================
// Events
// ============================================================================

abstract class AiQaEvent extends Equatable {
  const AiQaEvent();

  @override
  List<Object?> get props => [];
}

class AiQaLoadDetail extends AiQaEvent {
  final int qid;
  const AiQaLoadDetail(this.qid);

  @override
  List<Object?> get props => [qid];
}

/// M2 列表页：拉指定 status 集合。statuses=null 拉全部。
class AiQaLoadList extends AiQaEvent {
  final List<String>? statuses;
  const AiQaLoadList({this.statuses});

  @override
  List<Object?> get props => [statuses];
}

class AiQaSubmitAnswer extends AiQaEvent {
  final int qid;
  final String? title;
  final String content;
  final List<String> images;

  const AiQaSubmitAnswer({
    required this.qid,
    this.title,
    required this.content,
    this.images = const [],
  });

  @override
  List<Object?> get props => [qid, title, content, images];
}

// ============================================================================
// State
// ============================================================================

enum AiQaStatus { initial, loading, loaded, submitting, submitted, error }

class AiQaState extends Equatable {
  final AiQaStatus status;
  final AiQuestion? question;
  final List<AiAnswer> answers;
  // M2 列表页字段：detail/answer-form 不动它。
  final List<AiQuestion> items;
  final String? errorMessage;

  const AiQaState({
    this.status = AiQaStatus.initial,
    this.question,
    this.answers = const [],
    this.items = const [],
    this.errorMessage,
  });

  AiQaState copyWith({
    AiQaStatus? status,
    AiQuestion? question,
    List<AiAnswer>? answers,
    List<AiQuestion>? items,
    String? errorMessage,
  }) =>
      AiQaState(
        status: status ?? this.status,
        question: question ?? this.question,
        answers: answers ?? this.answers,
        items: items ?? this.items,
        // errorMessage 走 replace 语义,跟其他 bloc 一致:
        // copyWith 不传 null 也会重置,与现有 AuthBloc/CouponPointsBloc 等保持一致。
        errorMessage: errorMessage,
      );

  @override
  List<Object?> get props =>
      [status, question, answers, items, errorMessage];
}

// ============================================================================
// Bloc
// ============================================================================

class AiQaBloc extends Bloc<AiQaEvent, AiQaState> {
  final AiQaRepository _repository;

  AiQaBloc({required AiQaRepository repository})
      : _repository = repository,
        super(const AiQaState()) {
    on<AiQaLoadDetail>(_onLoadDetail);
    on<AiQaLoadList>(_onLoadList);
    on<AiQaSubmitAnswer>(_onSubmit);
  }

  Future<void> _onLoadList(
    AiQaLoadList event,
    Emitter<AiQaState> emit,
  ) async {
    emit(state.copyWith(status: AiQaStatus.loading));
    try {
      final items = await _repository.listQuestions(statuses: event.statuses);
      emit(state.copyWith(status: AiQaStatus.loaded, items: items));
    } catch (err) {
      emit(state.copyWith(
        status: AiQaStatus.error,
        errorMessage: err.toString(),
      ));
    }
  }

  Future<void> _onLoadDetail(
    AiQaLoadDetail event,
    Emitter<AiQaState> emit,
  ) async {
    emit(state.copyWith(status: AiQaStatus.loading));
    try {
      final q = await _repository.getQuestion(event.qid);
      final answers = await _repository.getAnswers(event.qid);
      emit(state.copyWith(
        status: AiQaStatus.loaded,
        question: q,
        answers: answers,
      ));
    } catch (err) {
      // err 是 Exception(errorCode);err.toString() 是 "Exception: <code>"
      // 走 error_localizer.localize 映射成 l10n 文本
      emit(state.copyWith(
        status: AiQaStatus.error,
        errorMessage: err.toString(),
      ));
    }
  }

  Future<void> _onSubmit(
    AiQaSubmitAnswer event,
    Emitter<AiQaState> emit,
  ) async {
    emit(state.copyWith(status: AiQaStatus.submitting));
    try {
      await _repository.submitAnswer(
        event.qid,
        title: event.title,
        content: event.content,
        images: event.images,
      );
      emit(state.copyWith(status: AiQaStatus.submitted));
      add(AiQaLoadDetail(event.qid));
    } catch (err) {
      emit(state.copyWith(
        status: AiQaStatus.error,
        errorMessage: err.toString(),
      ));
    }
  }
}
