import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../bloc/user_profile_bloc.dart';
import 'capability_edit_view.dart';
import 'preference_edit_view.dart';

class MyProfileView extends StatelessWidget {
  const MyProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => UserProfileBloc(
        repository: context.read<UserProfileRepository>(),
      ),
      child: const _MyProfileContent(),
    );
  }
}

class _MyProfileContent extends StatefulWidget {
  const _MyProfileContent();

  @override
  State<_MyProfileContent> createState() => _MyProfileContentState();
}

class _MyProfileContentState extends State<_MyProfileContent> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<UserProfileBloc>().add(const UserProfileLoadSummary());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的画像'),
      ),
      body: BlocBuilder<UserProfileBloc, UserProfileState>(
        builder: (context, state) {
          if (state.status == UserProfileStatus.loading ||
              state.status == UserProfileStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == UserProfileStatus.error) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  AppSpacing.vMd,
                  Text(
                    state.errorMessage ?? '加载失败',
                    style: const TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.vMd,
                  TextButton(
                    onPressed: () => context
                        .read<UserProfileBloc>()
                        .add(const UserProfileLoadSummary()),
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          final summary = state.summary;
          if (summary == null) {
            return const Center(child: Text('暂无数据'));
          }

          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<UserProfileBloc>()
                  .add(const UserProfileLoadSummary());
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.allMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CapabilityCard(capabilities: summary.capabilities),
                  AppSpacing.vMd,
                  _PreferenceCard(preference: summary.preference),
                  AppSpacing.vMd,
                  _ReliabilityCard(reliability: summary.reliability),
                  AppSpacing.vMd,
                  _DemandCard(demand: summary.demand),
                  AppSpacing.vLg,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ======================== 能力画像 ========================

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.capabilities});

  final List<UserCapability> capabilities;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '能力画像',
      icon: Icons.psychology_outlined,
      iconColor: AppColors.primary,
      action: TextButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<UserProfileBloc>(),
                child: const CapabilityEditView(),
              ),
            ),
          ).then((_) {
            if (context.mounted) {
              context.read<UserProfileBloc>().add(const UserProfileLoadSummary());
            }
          });
        },
        icon: const Icon(Icons.settings_outlined, size: 16),
        label: const Text('管理'),
      ),
      child: capabilities.isEmpty
          ? const _EmptyHint(message: '还未添加技能，点击"管理"添加')
          : Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: capabilities
                  .map((cap) => _SkillChip(capability: cap))
                  .toList(),
            ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.capability});

  final UserCapability capability;

  Color get _proficiencyColor {
    switch (capability.proficiency) {
      case 'expert':
        return AppColors.success;
      case 'intermediate':
        return AppColors.primary;
      case 'beginner':
      default:
        return AppColors.textSecondary;
    }
  }

  String get _proficiencyLabel {
    switch (capability.proficiency) {
      case 'expert':
        return '精通';
      case 'intermediate':
        return '熟练';
      case 'beginner':
      default:
        return '入门';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _proficiencyColor.withValues(alpha: 0.08),
        borderRadius: AppRadius.allMedium,
        border: Border.all(color: _proficiencyColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            capability.skillName,
            style: TextStyle(
              fontSize: 13,
              color: _proficiencyColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: _proficiencyColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _proficiencyLabel,
              style: TextStyle(
                fontSize: 10,
                color: _proficiencyColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================== 偏好画像 ========================

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({required this.preference});

  final UserProfilePreference preference;

  String _modeLabel(String mode) {
    switch (mode) {
      case 'online':
        return '线上';
      case 'offline':
        return '线下';
      case 'both':
      default:
        return '都可以';
    }
  }

  String _durationLabel(String type) {
    switch (type) {
      case 'one_time':
        return '一次性';
      case 'long_term':
        return '长期';
      case 'both':
      default:
        return '都可以';
    }
  }

  String _rewardLabel(String reward) {
    switch (reward) {
      case 'high_freq_low_amount':
        return '高频小额';
      case 'low_freq_high_amount':
        return '低频高价';
      case 'no_preference':
      default:
        return '无偏好';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '偏好画像',
      icon: Icons.tune_outlined,
      iconColor: AppColors.accent,
      action: TextButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<UserProfileBloc>(),
                child: PreferenceEditView(currentPreference: preference),
              ),
            ),
          ).then((_) {
            if (context.mounted) {
              context.read<UserProfileBloc>().add(const UserProfileLoadSummary());
            }
          });
        },
        icon: const Icon(Icons.edit_outlined, size: 16),
        label: const Text('编辑'),
      ),
      child: Column(
        children: [
          _InfoRow(label: '协作方式', value: _modeLabel(preference.mode)),
          _InfoRow(label: '任务周期', value: _durationLabel(preference.durationType)),
          _InfoRow(label: '报酬偏好', value: _rewardLabel(preference.rewardPreference)),
          if (preference.preferredTimeSlots.isNotEmpty)
            _InfoRow(
              label: '可用时段',
              value: preference.preferredTimeSlots
                  .map(_timeSlotLabel)
                  .join('、'),
            ),
        ],
      ),
    );
  }

  String _timeSlotLabel(String slot) {
    switch (slot) {
      case 'weekday_daytime':
        return '工作日白天';
      case 'weekday_evening':
        return '工作日晚上';
      case 'weekend':
        return '周末';
      case 'anytime':
        return '全天';
      default:
        return slot;
    }
  }
}

// ======================== 可靠度画像 ========================

class _ReliabilityCard extends StatelessWidget {
  const _ReliabilityCard({required this.reliability});

  final UserReliability reliability;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: '可靠度画像',
      icon: Icons.verified_outlined,
      iconColor: AppColors.success,
      child: reliability.insufficientData
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: AppColors.textSecondary),
                    SizedBox(width: 6),
                    Text(
                      '数据不足，完成更多任务后查看',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
                if (reliability.totalTasksTaken > 0) ...[
                  AppSpacing.vSm,
                  _InfoRow(
                    label: '已完成任务',
                    value: '${reliability.totalTasksTaken} 个',
                  ),
                ],
              ],
            )
          : Column(
              children: [
                if (reliability.reliabilityScore != null)
                  _ReliabilityScore(score: reliability.reliabilityScore!),
                AppSpacing.vMd,
                _InfoRow(
                  label: '完成率',
                  value:
                      '${(reliability.completionRate * 100).toStringAsFixed(0)}%',
                ),
                _InfoRow(
                  label: '准时率',
                  value:
                      '${(reliability.onTimeRate * 100).toStringAsFixed(0)}%',
                ),
                _InfoRow(
                  label: '沟通评分',
                  value: reliability.communicationScore.toStringAsFixed(1),
                ),
                _InfoRow(
                  label: '重复合作率',
                  value:
                      '${(reliability.repeatRate * 100).toStringAsFixed(0)}%',
                ),
              ],
            ),
    );
  }
}

class _ReliabilityScore extends StatelessWidget {
  const _ReliabilityScore({required this.score});

  final double score;

  Color get _scoreColor {
    if (score >= 80) return AppColors.success;
    if (score >= 60) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          '可靠度评分',
          style: TextStyle(
              fontSize: 13, color: AppColors.textSecondary),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _scoreColor.withValues(alpha: 0.1),
            borderRadius: AppRadius.allMedium,
          ),
          child: Text(
            '${score.toStringAsFixed(0)}分',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _scoreColor,
            ),
          ),
        ),
      ],
    );
  }
}

// ======================== 需求预测 ========================

class _DemandCard extends StatelessWidget {
  const _DemandCard({required this.demand});

  final UserDemand demand;

  String _stageLabel(String stage) {
    switch (stage) {
      case 'new_arrival':
        return '初来乍到';
      case 'settling_in':
        return '安顿中';
      case 'campus_active':
        return '校园活跃';
      case 'skill_building':
        return '技能成长';
      case 'experienced':
        return '经验丰富';
      default:
        return stage;
    }
  }

  Color _stageColor(String stage) {
    switch (stage) {
      case 'new_arrival':
        return AppColors.accent;
      case 'settling_in':
        return AppColors.primary;
      case 'campus_active':
        return AppColors.success;
      case 'skill_building':
        return AppColors.purple;
      case 'experienced':
        return AppColors.gold;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stageColor = _stageColor(demand.userStage);
    return _SectionCard(
      title: '需求预测',
      icon: Icons.lightbulb_outlined,
      iconColor: AppColors.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('当前阶段',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.1),
                  borderRadius: AppRadius.allMedium,
                  border: Border.all(color: stageColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _stageLabel(demand.userStage),
                  style: TextStyle(
                    fontSize: 12,
                    color: stageColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (demand.predictedNeeds.isNotEmpty) ...[
            AppSpacing.vMd,
            const Text('预测需求',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary)),
            AppSpacing.vSm,
            ...demand.predictedNeeds.map(
              (need) => _PredictedNeedRow(need: need),
            ),
          ] else ...[
            AppSpacing.vSm,
            const _EmptyHint(message: '暂无需求预测数据'),
          ],
        ],
      ),
    );
  }
}

class _PredictedNeedRow extends StatelessWidget {
  const _PredictedNeedRow({required this.need});

  final PredictedNeed need;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  need.category,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${(need.confidence * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (need.items.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: need.items
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ======================== 通用组件 ========================

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
    this.action,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (action != null) action!,
            ],
          ),
          const Divider(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
