import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../data/repositories/forum_repository.dart';
import '../bloc/forum_bloc.dart';
import '../../../data/models/forum.dart';

/// 创建帖子页
/// 参考iOS CreatePostView.swift
class CreatePostView extends StatefulWidget {
  const CreatePostView({super.key});

  @override
  State<CreatePostView> createState() => _CreatePostViewState();
}

class _CreatePostViewState extends State<CreatePostView> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  int? _selectedCategoryId;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      AppFeedback.showWarning(context, context.l10n.feedbackFillTitleAndContent);
      return;
    }

    if (_selectedCategoryId == null) {
      AppFeedback.showWarning(context, context.l10n.feedbackSelectCategory);
      return;
    }

    final bloc = context.read<ForumBloc>();
    bloc.add(
      ForumCreatePost(
        CreatePostRequest(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          categoryId: _selectedCategoryId!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ForumBloc(
        forumRepository: context.read<ForumRepository>(),
      )..add(const ForumLoadCategories()),
      child: BlocConsumer<ForumBloc, ForumState>(
        listener: (context, state) {
          if (state.isCreatingPost == false && state.errorMessage != null) {
            AppFeedback.showError(context, state.errorMessage!);
          } else if (state.isCreatingPost == false &&
              state.posts.isNotEmpty &&
              state.posts.first.title == _titleController.text.trim()) {
            AppFeedback.showSuccess(context, context.l10n.feedbackPostPublishSuccess);
            context.pop();
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('发布帖子'),
              actions: [
                TextButton(
                  onPressed: state.isCreatingPost
                      ? null
                      : () => _submit(context),
                  child: state.isCreatingPost
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('发布'),
                ),
              ],
            ),
            body: ListView(
              padding: AppSpacing.allMd,
              children: [
                // 分类选择
                if (state.categories.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: '选择分类',
                      border: OutlineInputBorder(),
                    ),
                    items: state.categories.map((category) {
                      return DropdownMenuItem<int>(
                        value: category.id,
                        child: Text(category.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                  ),
                  AppSpacing.vMd,
                ],
                // 标题
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    hintText: '请输入标题',
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                // 内容
                TextField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    hintText: '分享你的想法...',
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  minLines: 10,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
