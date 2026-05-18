import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/ai_qa.dart';
import '../../../data/repositories/ai_qa_repository.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../l10n/app_localizations.dart';
import '../bloc/ai_qa_bloc.dart';

class AiQaDetailView extends StatelessWidget {
  final int qid;
  const AiQaDetailView({super.key, required this.qid});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => AiQaBloc(repository: ctx.read<AiQaRepository>())
        ..add(AiQaLoadDetail(qid)),
      child: const _Body(),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<AiQaBloc, AiQaState>(
      builder: (context, state) {
        if (state.status == AiQaStatus.loading ||
            state.status == AiQaStatus.initial) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.aiQaTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (state.status == AiQaStatus.error || state.question == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.aiQaTitle)),
            body: Center(
              child: Text(context.localizeError(state.errorMessage ?? '')),
            ),
          );
        }
        final q = state.question!;
        return Scaffold(
          appBar: AppBar(title: Text(l10n.aiQaTitle)),
          body: CustomScrollView(
            slivers: [
              if (q.status == 'canceled')
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(l10n.aiQaCanceledBanner),
                  ),
                ),
              if (q.status == 'settled')
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(l10n.aiQaSettledBanner),
                  ),
                ),
              SliverToBoxAdapter(child: _Hero(q: q)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _AnswerCard(
                    answer: state.answers[i],
                    questionStatus: q.status,
                  ),
                  childCount: state.answers.length,
                ),
              ),
            ],
          ),
          floatingActionButton: q.status == 'published'
              ? FloatingActionButton.extended(
                  onPressed: () => context.push('/ai-qa/${q.id}/answer'),
                  label: Text(l10n.aiQaAnswerButton),
                  icon: const Icon(Icons.edit),
                )
              : null,
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  final AiQuestion q;
  const _Hero({required this.q});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(q.content),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              border: Border.all(color: Colors.amber),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(l10n.aiQaPool,
                          style: const TextStyle(fontSize: 10)),
                      Text(
                        '£${(q.rewardPoolPence / 100).toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (q.deadline != null && q.status == 'published')
                  Expanded(
                    child: Column(
                      children: [
                        Text(l10n.aiQaCountdown,
                            style: const TextStyle(fontSize: 10)),
                        Text(
                          _formatCountdown(q.deadline!, l10n),
                          style: const TextStyle(
                              fontSize: 14, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCountdown(DateTime deadline, AppLocalizations l10n) {
    final diff = deadline.difference(DateTime.now());
    if (diff.isNegative) return l10n.aiQaDeadlinePassed;
    final d = diff.inDays;
    final h = diff.inHours % 24;
    return d > 0 ? '${d}d ${h}h' : '${h}h';
  }
}

class _AnswerCard extends StatelessWidget {
  final AiAnswer answer;
  final String questionStatus;
  const _AnswerCard({
    required this.answer,
    required this.questionStatus,
  });

  @override
  Widget build(BuildContext context) {
    if (answer.hideInQa) return const SizedBox.shrink();
    final isDeleted = answer.isDeleted;
    final isSettledOrCanceled =
        questionStatus == 'settled' || questionStatus == 'canceled';
    if (isDeleted && !isSettledOrCanceled) return const SizedBox.shrink();
    // top3 高亮: 新算法 (spec §2.1) 下排名前 3 但 reward_pence 被 floor 抹零为 0 的情况
    // (小池子大池子边界 case) 不应贴金边,否则会展示"#2 金边 + 无奖金"的矛盾视觉
    final isTop = (answer.rankFinal ?? 999) <= 3 &&
        answer.rewardPence > 0 &&
        questionStatus == 'settled';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDeleted ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isTop ? Border.all(color: Colors.amber, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isTop)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('#${answer.rankFinal}'),
                ),
              if (isTop) const SizedBox(width: 6),
              Text(
                answer.userName ?? answer.userId,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (isDeleted)
            const Text(
              '该答案已被删除',
              style:
                  TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            )
          else
            Text(answer.content ?? ''),
          if (answer.rewardPence > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '£${(answer.rewardPence / 100).toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.orange, fontWeight: FontWeight.w600),
              ),
            ),
          if (answer.aiGenerated == 'high' &&
              (questionStatus == 'scored' || questionStatus == 'settled'))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: Colors.grey.shade200,
                child: const Text(
                  '⚠ 可能为 AI 生成',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
