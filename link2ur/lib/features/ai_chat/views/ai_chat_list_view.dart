import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../data/models/ai_chat.dart';
import '../../../data/services/ai_chat_service.dart';
import '../bloc/ai_chat_bloc.dart';

/// AI 对话列表页面
class AIChatListView extends StatelessWidget {
  const AIChatListView({super.key});

  @override
  Widget build(BuildContext context) {
    final aiChatService = context.read<AIChatService>();

    return BlocProvider(
      create: (_) => AIChatBloc(aiChatService: aiChatService)
        ..add(const AIChatLoadConversations()),
      child: const _AIChatListContent(),
    );
  }
}

class _AIChatListContent extends StatelessWidget {
  const _AIChatListContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 助手'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/ai-chat'),
            tooltip: '新对话',
          ),
        ],
      ),
      body: BlocBuilder<AIChatBloc, AIChatState>(
        builder: (context, state) {
          if (state.status == AIChatStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.conversations.isEmpty) {
            return _EmptyState(
              onNewChat: () => context.push('/ai-chat'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: state.conversations.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: AppSpacing.md + 48,
            ),
            itemBuilder: (context, index) {
              final conv = state.conversations[index];
              return _ConversationTile(
                key: ValueKey(conv.id),
                conversation: conv,
                onTap: () => context.push('/ai-chat/${conv.id}'),
                onDelete: () {
                  context.read<AIChatBloc>().add(
                        AIChatArchiveConversation(conv.id),
                      );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onDelete,
  });

  final AIConversation conversation;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = conversation.title.isEmpty ? '新对话' : conversation.title;
    final timeStr = conversation.updatedAt != null
        ? _formatTime(conversation.updatedAt!)
        : '';

    return Dismissible(
      key: ValueKey(conversation.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: Image.asset(
            AppAssets.any,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          timeStr,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNewChat});

  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.large),
            child: Image.asset(
              AppAssets.any,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.l10n.aiChatNoConversations,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton.icon(
            onPressed: onNewChat,
            icon: const Icon(Icons.add),
            label: Text(context.l10n.aiChatStartNewConversation),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
