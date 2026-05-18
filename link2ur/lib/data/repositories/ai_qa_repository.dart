import '../models/ai_qa.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

/// AI 限时问答（悬赏）Repository
///
/// 现有 27/29 repository 都用 ({required ApiService apiService}) 命名参数;
/// ApiService 方法返回 ApiResponse<T>,必须先判 isSuccess 才能用 .data —
/// 否则 .data 是 null 时会 NPE。参考 question_repository.dart / badges_repository.dart。
class AiQaRepository {
  AiQaRepository({required ApiService apiService}) : _apiService = apiService;

  final ApiService _apiService;

  /// 获取问题详情
  Future<AiQuestion> getQuestion(int id) async {
    final resp = await _apiService.get(ApiEndpoints.aiQaDetail(id));
    if (resp.isSuccess && resp.data != null) {
      return AiQuestion.fromJson(resp.data as Map<String, dynamic>);
    }
    throw Exception(
        resp.errorCode ?? resp.message ?? 'ai_qa_load_detail_failed');
  }

  /// 获取问题的所有答案
  Future<List<AiAnswer>> getAnswers(int id) async {
    final resp = await _apiService.get(ApiEndpoints.aiQaAnswers(id));
    if (resp.isSuccess && resp.data != null) {
      final List items = resp.data as List;
      return items
          .map((j) => AiAnswer.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception(
        resp.errorCode ?? resp.message ?? 'ai_qa_load_answers_failed');
  }

  /// 提交答案
  Future<Map<String, dynamic>> submitAnswer(
    int id, {
    String? title,
    required String content,
    List<String> images = const [],
  }) async {
    final resp = await _apiService.post(
      ApiEndpoints.aiQaAnswer(id),
      data: {
        'title': title,
        'content': content,
        'images': images,
      },
    );
    if (resp.isSuccess && resp.data != null) {
      return resp.data as Map<String, dynamic>;
    }
    throw Exception(
        resp.errorCode ?? resp.message ?? 'ai_qa_submit_answer_failed');
  }
}
