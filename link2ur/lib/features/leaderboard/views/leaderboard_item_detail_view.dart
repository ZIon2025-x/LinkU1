import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/repositories/leaderboard_repository.dart';

/// 排行榜条目详情页
/// 参考iOS LeaderboardItemDetailView.swift
class LeaderboardItemDetailView extends StatefulWidget {
  const LeaderboardItemDetailView({super.key, required this.itemId});

  final int itemId;

  @override
  State<LeaderboardItemDetailView> createState() =>
      _LeaderboardItemDetailViewState();
}

class _LeaderboardItemDetailViewState
    extends State<LeaderboardItemDetailView> {
  Map<String, dynamic>? _item;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  Future<void> _loadItem() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<LeaderboardRepository>();
      final item = await repo.getItemDetail(widget.itemId);
      if (mounted) {
        setState(() {
          _item = item;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.leaderboardItemDetail),
      ),
      body: _isLoading
          ? const LoadingView()
          : _errorMessage != null
              ? ErrorStateView(
                  message: _errorMessage!,
                  onRetry: _loadItem,
                )
              : _item == null
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 排名与得分
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primary.withOpacity(0.8),
                                ],
                              ),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.large),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildRankInfo(
                                  l10n.leaderboardRank,
                                  '#${_item!['rank'] ?? '-'}',
                                ),
                                Container(
                                  width: 1,
                                  height: 40,
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                _buildRankInfo(
                                  l10n.leaderboardScore,
                                  '${_item!['score'] ?? 0}',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // 用户信息
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.large),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage:
                                      _item!['avatar'] != null
                                          ? NetworkImage(
                                              _item!['avatar'] as String)
                                          : null,
                                  child: _item!['avatar'] == null
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _item!['name'] as String? ??
                                            '',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight:
                                                FontWeight.w600),
                                      ),
                                      if (_item!['description'] !=
                                          null)
                                        Text(
                                          _item!['description']
                                              as String,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors
                                                  .textSecondary),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildRankInfo(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8))),
      ],
    );
  }
}
