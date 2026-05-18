import 'package:go_router/go_router.dart';

import '../../../features/ai_qa/views/ai_qa_answer_form_view.dart';
import '../../../features/ai_qa/views/ai_qa_detail_view.dart';
import '../app_routes.dart';

/// AI 限时问答（悬赏）路由
/// - aiQaDetail: 题目详情 + 三态(M3 published / M4 canceled / M5 settled)
/// - aiQaAnswer: 答题表单(M6)
final List<GoRoute> aiQaRoutes = [
  GoRoute(
    path: AppRoutes.aiQaDetail,
    name: 'aiQaDetail',
    builder: (ctx, st) =>
        AiQaDetailView(qid: int.parse(st.pathParameters['id']!)),
  ),
  GoRoute(
    path: AppRoutes.aiQaAnswer,
    name: 'aiQaAnswer',
    builder: (ctx, st) =>
        AiQaAnswerFormView(qid: int.parse(st.pathParameters['id']!)),
  ),
];
