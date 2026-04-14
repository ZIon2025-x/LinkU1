import '../models/task_question.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

class QuestionRepository {
  QuestionRepository({required ApiService apiService}) : _apiService = apiService;

  final ApiService _apiService;

  /// 获取问答列表
  Future<Map<String, dynamic>> getQuestions({
    required String targetType,
    required int targetId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get(
      ApiEndpoints.questions,
      queryParameters: {
        'target_type': targetType,
        'target_id': targetId,
        'page': page,
        'page_size': pageSize,
      },
    );
    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      final items = (data['items'] as List?)
              ?.map((e) => TaskQuestion.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      return {
        'items': items,
        'total': data['total'] as int? ?? 0,
        'page': data['page'] as int? ?? 1,
        'page_size': data['page_size'] as int? ?? 20,
      };
    }
    throw Exception(response.errorCode ?? response.message ?? 'Failed to load questions');
  }

  /// 提问
  Future<TaskQuestion> askQuestion({
    required String targetType,
    required int targetId,
    required String content,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.questions,
      data: {
        'target_type': targetType,
        'target_id': targetId,
        'content': content,
      },
    );
    if (response.isSuccess && response.data != null) {
      return TaskQuestion.fromJson(response.data!);
    }
    throw Exception(response.errorCode ?? response.message ?? 'Failed to ask question');
  }

  /// 回复问题
  Future<TaskQuestion> replyQuestion({
    required int questionId,
    required String content,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.questionReply(questionId),
      data: {'content': content},
    );
    if (response.isSuccess && response.data != null) {
      return TaskQuestion.fromJson(response.data!);
    }
    throw Exception(response.errorCode ?? response.message ?? 'Failed to reply question');
  }

  /// 删除问题
  Future<void> deleteQuestion(int questionId) async {
    final response = await _apiService.delete(
      ApiEndpoints.questionDelete(questionId),
    );
    if (!response.isSuccess) {
      throw Exception(response.errorCode ?? response.message ?? 'Failed to delete question');
    }
  }
}
