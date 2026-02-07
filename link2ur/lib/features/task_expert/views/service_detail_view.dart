import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/repositories/task_expert_repository.dart';

/// 服务详情页
/// 参考iOS ServiceDetailView.swift
class ServiceDetailView extends StatefulWidget {
  const ServiceDetailView({super.key, required this.serviceId});

  final int serviceId;

  @override
  State<ServiceDetailView> createState() => _ServiceDetailViewState();
}

class _ServiceDetailViewState extends State<ServiceDetailView> {
  Map<String, dynamic>? _service;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadService();
  }

  Future<void> _loadService() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<TaskExpertRepository>();
      final service = await repo.getServiceDetail(widget.serviceId);
      if (mounted) {
        setState(() {
          _service = service;
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
        title: Text(l10n.taskExpertServiceDetail),
      ),
      body: _isLoading
          ? const LoadingView()
          : _errorMessage != null
              ? ErrorStateView(
                  message: _errorMessage!,
                  onRetry: _loadService,
                )
              : _service == null
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 服务标题
                          Text(
                            _service!['title'] as String? ?? '',
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppSpacing.md),

                          // 价格
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.medium),
                            ),
                            child: Row(
                              children: [
                                Text(l10n.taskExpertPrice,
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary)),
                                const Spacer(),
                                Text(
                                  '£${(_service!['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // 描述
                          Text(l10n.taskExpertDescription,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text(
                            _service!['description'] as String? ?? '',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                height: 1.6),
                          ),
                          const SizedBox(height: AppSpacing.lg),

                          // 类别
                          if (_service!['category'] != null) ...[
                            _buildInfoRow(
                              l10n.taskExpertCategory,
                              _service!['category'] as String,
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],

                          // 完成时间
                          if (_service!['delivery_time'] != null)
                            _buildInfoRow(
                              l10n.taskExpertDeliveryTime,
                              _service!['delivery_time'] as String,
                            ),

                          const SizedBox(height: AppSpacing.xl),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 14, color: AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
