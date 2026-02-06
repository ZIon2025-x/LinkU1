import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/empty_state_view.dart';

/// 任务列表页
/// 参考iOS TasksView.swift
class TasksView extends StatefulWidget {
  const TasksView({super.key});

  @override
  State<TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<TasksView> {
  String _selectedCategory = 'all';
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _categories = [
    {'key': 'all', 'label': '全部'},
    {'key': 'delivery', 'label': '代取代送'},
    {'key': 'shopping', 'label': '代购'},
    {'key': 'tutoring', 'label': '辅导'},
    {'key': 'translation', 'label': '翻译'},
    {'key': 'other', 'label': '其他'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务列表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: 显示筛选
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          _buildSearchBar(),

          // 分类标签
          _buildCategoryTabs(),

          // 任务列表
          Expanded(
            child: _buildTaskList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/tasks/create');
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: AppSpacing.allMd,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索任务...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
              : null,
        ),
        onChanged: (value) {
          setState(() {});
        },
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.horizontalMd,
        itemCount: _categories.length,
        separatorBuilder: (context, index) => AppSpacing.hSm,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category['key'];

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategory = category['key'] as String;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: AppRadius.allPill,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.dividerLight,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                category['label'] as String,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondaryLight,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskList() {
    // TODO: 从Bloc获取任务列表
    final tasks = List.generate(10, (index) => index);

    if (tasks.isEmpty) {
      return EmptyStateView.noTasks(
        actionText: '发布任务',
        onAction: () {
          context.push('/tasks/create');
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // TODO: 刷新
        await Future.delayed(const Duration(seconds: 1));
      },
      child: ListView.separated(
        padding: AppSpacing.allMd,
        itemCount: tasks.length,
        separatorBuilder: (context, index) => AppSpacing.vMd,
        itemBuilder: (context, index) {
          return _TaskListItem(index: index);
        },
      ),
    );
  }
}

class _TaskListItem extends StatelessWidget {
  const _TaskListItem({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {
        context.push('/tasks/${index + 1}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：用户信息和状态
          Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
              AppSpacing.hSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '用户${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '2小时前',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: AppRadius.allTiny,
                ),
                child: const Text(
                  '招募中',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vMd,

          // 标题
          Text(
            '示例任务标题 ${index + 1}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.vSm,

          // 描述
          Text(
            '这是任务的详细描述内容，可能会比较长...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryLight,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          AppSpacing.vMd,

          // 底部：价格和位置
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${(index + 1) * 15}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.textTertiaryLight,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '校园内',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
