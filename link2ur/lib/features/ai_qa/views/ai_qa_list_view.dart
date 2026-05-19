import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/error_localizer.dart';
import '../../../data/models/ai_qa.dart';
import '../../../data/repositories/ai_qa_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../bloc/ai_qa_bloc.dart';

/// M2 列表页 — 当期 / 历史 两个 tab。
/// 当期 = published + scoring + scored；历史 = settled + canceled + closed_empty。
class AiQaListView extends StatelessWidget {
  const AiQaListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => AiQaBloc(repository: ctx.read<AiQaRepository>())
        ..add(const AiQaLoadList(statuses: _currentStatuses)),
      child: const _Body(),
    );
  }
}

const List<String> _currentStatuses = ['published', 'scoring', 'scored'];
const List<String> _historyStatuses = ['settled', 'canceled', 'closed_empty'];

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  int _tab = 0; // 0 = 当期, 1 = 历史

  void _switchTab(int idx) {
    if (_tab == idx) return;
    setState(() => _tab = idx);
    context.read<AiQaBloc>().add(AiQaLoadList(
          statuses: idx == 0 ? _currentStatuses : _historyStatuses,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiQaListTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events),
            tooltip: 'Leaderboard',
            onPressed: () {
              // TODO P2 leaderboard 入口（spec M7）
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _Tabs(currentIndex: _tab, onTap: _switchTab),
          Expanded(
            child: BlocBuilder<AiQaBloc, AiQaState>(
              builder: (context, state) {
                if (state.status == AiQaStatus.loading ||
                    state.status == AiQaStatus.initial) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == AiQaStatus.error) {
                  return Center(
                    child: Text(
                      context.localizeError(state.errorMessage ?? ''),
                    ),
                  );
                }
                final items = state.items;
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      _tab == 0
                          ? l10n.aiQaListEmptyCurrent
                          : l10n.aiQaListEmptyHistory,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<AiQaBloc>().add(AiQaLoadList(
                          statuses: _tab == 0
                              ? _currentStatuses
                              : _historyStatuses,
                        ));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    itemCount: items.length,
                    itemBuilder: (_, i) => _AiQaListItem(
                      key: ValueKey(items[i].id),
                      question: items[i],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _Tabs({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final labels = [l10n.aiQaListTabCurrent, l10n.aiQaListTabHistory];
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = currentIndex == i;
          return Expanded(
            child: InkWell(
              onTap: () => onTap(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active
                          ? const Color(0xFFFF8033)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.normal,
                      color: active
                          ? const Color(0xFFFF8033)
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _AiQaListItem extends StatelessWidget {
  final AiQuestion question;
  const _AiQaListItem({super.key, required this.question});

  bool get _dim =>
      question.status == 'canceled' || question.status == 'closed_empty';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final card = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BadgeRow(question: question),
          const SizedBox(height: 8),
          Text(
            question.title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          _StatsRow(question: question),
          if (question.status == 'canceled')
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.aiQaListAdminCanceled,
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
    return InkWell(
      onTap: () => context.push('/ai-qa/${question.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: _dim ? 0.7 : 1.0,
        child: card,
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  final AiQuestion question;
  const _BadgeRow({required this.question});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pound = (question.rewardPoolPence / 100).toStringAsFixed(0);
    final isLive = question.status == 'published' ||
        question.status == 'scoring' ||
        question.status == 'scored';
    final children = <Widget>[];

    if (isLive) {
      // live 题目展示 cash + points + live 状态
      children.add(_Pill(
        text: l10n.aiQaListCash(pound),
        bg: const Color(0xFFFFEDD5),
        fg: const Color(0xFFC2410C),
      ));
      children.add(_Pill(
        text: l10n.aiQaListPoints(question.participationPoints),
        bg: const Color(0xFFDEEAFE),
        fg: const Color(0xFF1D4ED8),
      ));
      children.add(_Pill(
        text: l10n.aiQaStatusLive,
        bg: const Color(0xFFFEE2E2),
        fg: const Color(0xFFB91C1C),
      ));
    } else if (question.status == 'settled') {
      children.add(_Pill(
        text: l10n.aiQaStatusSettled,
        bg: const Color(0xFFD1FAE5),
        fg: const Color(0xFF065F46),
      ));
    } else if (question.status == 'canceled') {
      children.add(_Pill(
        text: l10n.aiQaStatusCanceled,
        bg: const Color(0xFFFEE2E2),
        fg: const Color(0xFF991B1B),
      ));
    } else if (question.status == 'closed_empty') {
      children.add(_Pill(
        text: l10n.aiQaStatusNoAnswers,
        bg: const Color(0xFFF3F4F6),
        fg: const Color(0xFF6B7280),
      ));
    }

    // 期号 + settled_at/canceled_at 日期（历史状态加副标签）
    final dateRef = question.settledAt ?? question.canceledAt;
    if (dateRef != null) {
      final ymd =
          '${dateRef.year}-${dateRef.month.toString().padLeft(2, '0')}-${dateRef.day.toString().padLeft(2, '0')}';
      children.add(Padding(
        padding: const EdgeInsets.only(left: 6),
        child: Text(
          ymd,
          style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
      ));
    }

    return Wrap(spacing: 6, runSpacing: 6, children: children);
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Pill({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: fg,
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final AiQuestion question;
  const _StatsRow({required this.question});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final widgets = <Widget>[];
    final ac = question.answerCount ?? 0;
    widgets.add(_StatChip(
      icon: '📝',
      text: l10n.aiQaListAnswerCount(ac),
    ));

    // live → 倒计时；settled → 采纳数 + 已发金额
    if (question.status == 'published' && question.deadline != null) {
      final diff = question.deadline!.difference(DateTime.now());
      String txt;
      if (diff.isNegative) {
        txt = l10n.aiQaDeadlinePassed;
      } else if (diff.inDays > 0) {
        txt = l10n.aiQaCountdownDaysHours(diff.inDays, diff.inHours % 24);
      } else {
        txt = l10n.aiQaCountdownHours(diff.inHours);
      }
      widgets.add(_StatChip(icon: '⏱', text: txt));
    }

    if (question.status == 'settled') {
      final wc = question.winnersCount ?? 0;
      widgets.add(_StatChip(
        icon: '🏆',
        text: l10n.aiQaListWinnersCount(wc),
      ));
      final pound = (question.rewardPoolPence / 100).toStringAsFixed(0);
      widgets.add(Text(
        l10n.aiQaListPayoutSent(pound),
        style: const TextStyle(
          color: Color(0xFFFF8033),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ));
    }

    return Wrap(spacing: 12, runSpacing: 4, children: widgets);
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String text;
  const _StatChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(icon, style: const TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
