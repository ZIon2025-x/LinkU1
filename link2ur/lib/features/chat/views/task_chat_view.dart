import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart' as video_player;
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/logger.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/utils/task_type_helper.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/full_screen_image_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/message_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/models/expert_team.dart';
import '../../../data/repositories/expert_team_repository.dart';
import '../../../data/services/storage_service.dart';
import '../bloc/chat_bloc.dart';
import '../widgets/image_send_confirm_dialog.dart';
import '../widgets/message_group_bubble.dart';
import '../widgets/task_chat_action_menu.dart';

/// 任务聊天页
/// 参考iOS TaskChatView.swift
/// 修复：WebSocket过滤、发送/已读API、系统消息、字符限制、分页、滚动
class TaskChatView extends StatelessWidget {
  const TaskChatView({
    super.key,
    required this.taskId,
  });

  final int taskId;

  @override
  Widget build(BuildContext context) {
    final messageRepository = context.read<MessageRepository>();

    return BlocProvider(
      create: (_) => ChatBloc(messageRepository: messageRepository)
        ..add(ChatLoadMessages(userId: '', taskId: taskId)),
      child: _TaskChatContent(taskId: taskId),
    );
  }
}

/// 任务聊天内容（在 BlocProvider 内部，context 可访问 ChatBloc）
class _TaskChatContent extends StatefulWidget {
  const _TaskChatContent({required this.taskId});

  final int taskId;

  @override
  State<_TaskChatContent> createState() => _TaskChatContentState();
}

class _TaskChatContentState extends State<_TaskChatContent> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  String? _currentUserId;
  bool _showActionMenu = false;
  DateTime? _lastTypingSent;

  /// 互斥 flag: 防止用户连点照片/拍照/文件 → 弹多个 picker 叠层。
  bool _isPicking = false;

  /// 视频压缩 / 大文件上传进度反馈: 显示顶部 Banner 让用户知道在处理。
  bool _isProcessingMedia = false;
  String _processingLabel = '';

  /// 标记当前是否在视频压缩(给"取消"按钮区分:压缩阶段可 cancel,
  /// 上传阶段已上桨,不提供 cancel 避免半成品状态)。
  bool _isCompressingVideo = false;

  void _setProcessing(bool processing, [String label = '', bool isCompressing = false]) {
    if (!mounted) return;
    setState(() {
      _isProcessingMedia = processing;
      _processingLabel = processing ? label : '';
      _isCompressingVideo = processing ? isCompressing : false;
    });
  }

  /// 取消正在进行的视频压缩。由进度 Banner 的"取消"按钮触发。
  /// VideoCompress.cancelCompression() 会让 compressVideo Future 完成时 path 为 null,
  /// _handlePickedVideo 后续步骤检测到 null 自然提前 return(无副作用)。
  Future<void> _cancelVideoCompression() async {
    try {
      await VideoCompress.cancelCompression();
    } catch (e) {
      AppLogger.error('VideoCompress.cancelCompression failed', e);
    }
    _setProcessing(false);
  }

  /// 任务标题用于 AppBar，加载一次
  Future<Task?>? _taskFuture;
  bool _taskFutureInitialized = false;

  /// 字符限制 - 对齐iOS (500字符)
  static const int _maxCharacters = 500;
  static const int _showCounterThreshold = 400;

  @override
  void initState() {
    super.initState();
    _currentUserId = StorageService.instance.getUserId();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_taskFutureInitialized) {
      _taskFutureInitialized = true;
      _taskFuture = context.read<TaskRepository>().getTaskById(widget.taskId);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// reverse:true 时列表新→旧，底部=最新；往上滑接近顶部（maxScrollExtent）时加载更早
  void _onScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 50) {
      context.read<ChatBloc>().add(const ChatLoadMore());
    }
  }

  Future<void> _showInviteMemberSheet(BuildContext context) async {
    final repo = context.read<ExpertTeamRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // 从已加载的 task 拿团队 ID
    final task = await _taskFuture;
    if (task == null || task.takerDisplay == null || !task.takerDisplay!.isTeam) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatNoExpertTeamForTask)),
        );
      }
      return;
    }
    final expertId = task.takerDisplay!.entityId;

    if (!mounted) return;

    // 并行加载团队成员 + 已在聊天中的参与者
    late final List<ExpertMember> members;
    late final Map<String, dynamic> participantsData;
    try {
      final results = await Future.wait([
        repo.getMembers(expertId),
        repo.getTaskChatParticipants(widget.taskId),
      ]);
      members = results[0] as List<ExpertMember>;
      participantsData = results[1] as Map<String, dynamic>;
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.chatLoadMembersFailed(e.toString()))),
        );
      }
      return;
    }

    // 提取已在聊天中的 user_id 集合
    final participantsList = participantsData['participants'] as List<dynamic>? ?? [];
    final existingUserIds = <String>{};
    for (final p in participantsList) {
      if (p is Map<String, dynamic>) {
        final uid = p['user_id']?.toString();
        if (uid != null) existingUserIds.add(uid);
      }
    }

    // 过滤掉已在聊天中的成员
    final invitable = members.where((m) =>
        m.status == 'active' && !existingUserIds.contains(m.userId)).toList();

    if (!mounted) return;

    if (invitable.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.chatAllMembersInChat)),
      );
      return;
    }

    // 弹出成员列表 bottom sheet
    showModalBottomSheet<void>(
      context: navigator.context,
      builder: (sheetContext) => _InviteMemberList(
        members: invitable,
        onInvite: (member) async {
          Navigator.pop(sheetContext);
          try {
            await repo.inviteToTaskChat(widget.taskId, member.userId);
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text(context.l10n.chatInviteSuccess(member.userName ?? member.userId))),
              );
            }
          } catch (e) {
            if (mounted) {
              messenger.showSnackBar(
                SnackBar(content: Text(context.l10n.chatInviteFailed(e.toString()))),
              );
            }
          }
        },
      ),
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final content = _messageController.text.trim();
    context.read<ChatBloc>().add(
          ChatSendMessage(
            content: content,
            senderId: _currentUserId ?? StorageService.instance.getUserId(),
          ),
        );
    _messageController.clear();
    setState(() => _showActionMenu = false);
    // 任务聊天 reverse+新→旧 新消息已插头，无需滚；私聊不在此页
  }


  /// 相册选媒体:支持图片或视频多选(image_picker 1.x 的 pickMultipleMedia)。
  /// - 选中图片:走原图片发送流程(每张图独立 ChatSendImage)
  /// - 选中视频:走 ChatSendVideo(前端压缩 + 抽帧后并行上传)
  static const int _kMaxGalleryImages = 9;

  Future<void> _pickImage() async {
    if (_isPicking) return;
    _isPicking = true;
    try {
      final media = await _imagePicker.pickMultipleMedia(
        imageQuality: 70,
        maxWidth: 1200,
        limit: _kMaxGalleryImages,
      );
      if (media.isEmpty || !mounted) return;

      final toProcess =
          media.take(_kMaxGalleryImages).where((f) => f.path.isNotEmpty).toList();
      for (final file in toProcess) {
        if (!mounted) break;
        final mime = file.mimeType ?? '';
        final pathLower = file.path.toLowerCase();
        final isVideo = mime.startsWith('video/') ||
            pathLower.endsWith('.mp4') ||
            pathLower.endsWith('.mov') ||
            pathLower.endsWith('.m4v');
        if (isVideo) {
          await _handlePickedVideo(file.path, file.name);
        } else {
          if (!mounted) break;
          context.read<ChatBloc>().add(
                ChatSendImage(
                  bytes: await file.readAsBytes(),
                  filename: file.name,
                  senderId: _currentUserId ?? StorageService.instance.getUserId(),
                ),
              );
        }
      }
      if (mounted) setState(() => _showActionMenu = false);
    } finally {
      _isPicking = false;
    }
  }

  /// 视频处理:读元数据 -> 时长校验 -> 压缩 -> 抽首帧 -> 派发 ChatSendVideo
  Future<void> _handlePickedVideo(String filePath, String filename) async {
    final messenger = ScaffoldMessenger.of(context);
    // isCompressing=true → Banner 显示"取消"按钮(压缩阶段可中断)
    _setProcessing(true, context.l10n.chatVideoProcessing, true);
    try {
      // 1. 读取视频元数据(时长 / 尺寸)
      // 用 try/finally 确保即便 initialize 抛异常 controller 也被 dispose,防 native 资源泄漏。
      int durationMs = 0;
      int width = 0;
      int height = 0;
      final controller =
          video_player.VideoPlayerController.file(File(filePath));
      try {
        await controller.initialize();
        durationMs = controller.value.duration.inMilliseconds;
        width = controller.value.size.width.toInt();
        height = controller.value.size.height.toInt();
      } finally {
        await controller.dispose();
      }

      if (durationMs > 30000) {
        if (mounted) {
          messenger.showSnackBar(SnackBar(
            content: Text(context.localizeError('chat_video_too_long')),
          ));
        }
        return;
      }

      // 2. 压缩到 1080p(VideoCompress 内部 medium quality)
      final compressed = await VideoCompress.compressVideo(
        filePath,
        quality: VideoQuality.MediumQuality,
        includeAudio: true,
      );
      // 用户取消压缩 → VideoCompress 返回 null/失败,Banner 已被 _cancelVideoCompression
      // 清掉。这里检测后静默 return,不报错(用户主动操作)。
      if (!_isProcessingMedia) {
        AppLogger.info('Video compression cancelled by user');
        return;
      }
      final compressedPath = compressed?.path ?? filePath;
      final compressedBytes = await File(compressedPath).readAsBytes();
      if (compressedBytes.length > 30 * 1024 * 1024) {
        if (mounted) {
          messenger.showSnackBar(SnackBar(
            content: Text(context.localizeError('chat_video_too_large')),
          ));
        }
        return;
      }

      // 3. 抽首帧 -> JPEG bytes; 失败保持 null,**不** fallback Uint8List(0)
      //    避免后端入库 0 字节图,接收端纯黑无法识别。
      //    ChatSendVideo handler 已支持可空 thumbnail,attachments 动态拼。
      Uint8List? thumbBytes;
      try {
        thumbBytes = await VideoThumbnail.thumbnailData(
          video: compressedPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 540,
          quality: 70,
        );
      } catch (e) {
        AppLogger.error('Thumbnail extraction failed', e);
      }

      if (!mounted) return;
      // 4. 派发 ChatSendVideo
      final lower = filename.toLowerCase();
      final outFilename = lower.endsWith('.mp4') ||
              lower.endsWith('.mov') ||
              lower.endsWith('.m4v')
          ? filename
          : '$filename.mp4';
      context.read<ChatBloc>().add(ChatSendVideo(
            videoBytes: compressedBytes,
            videoFilename: outFilename,
            videoDurationMs: durationMs,
            videoWidth: width,
            videoHeight: height,
            thumbnailBytes:
                (thumbBytes != null && thumbBytes.isNotEmpty) ? thumbBytes : null,
            thumbnailFilename:
                (thumbBytes != null && thumbBytes.isNotEmpty) ? '$filename.thumb.jpg' : null,
            senderId: _currentUserId ?? StorageService.instance.getUserId(),
          ));
    } catch (e) {
      AppLogger.error('Video pick failed', e);
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(context.localizeError('chat_video_compress_failed')),
        ));
      }
    } finally {
      _setProcessing(false);
    }
  }

  /// 文件按钮:选 PDF。
  Future<void> _pickFile() async {
    if (_isPicking) return;
    _isPicking = true;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        messenger.showSnackBar(SnackBar(
          content: Text(context.localizeError('chat_upload_failed')),
        ));
        return;
      }
      if (bytes.length > 20 * 1024 * 1024) {
        messenger.showSnackBar(SnackBar(
          content: Text(context.localizeError('chat_file_too_large')),
        ));
        return;
      }
      // PDF 上传由 ChatBloc 触发 → state.isSending 覆盖进度,Banner 在 build() 里
      // 监听 isSending 显示"发送中…",不需要本地 _setProcessing 标记。
      context.read<ChatBloc>().add(ChatSendFile(
            bytes: bytes,
            filename: file.name,
            contentType: 'application/pdf',
            senderId: _currentUserId ?? StorageService.instance.getUserId(),
          ));
      setState(() => _showActionMenu = false);
    } finally {
      _isPicking = false;
    }
  }

  /// 拍照发送：拍完后弹出确认再发送
  Future<void> _pickCameraImage() async {
    if (_isPicking) return;
    _isPicking = true;
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1200,
      );
      if (image == null || !mounted) return;
      final confirmed = await showImageSendConfirmDialog(context, image);
      if (confirmed == true && mounted) {
        context.read<ChatBloc>().add(
              ChatSendImage(
                bytes: await image.readAsBytes(),
                filename: image.name,
                senderId: _currentUserId ?? StorageService.instance.getUserId(),
              ),
            );
        setState(() => _showActionMenu = false);
      }
    } finally {
      _isPicking = false;
    }
  }

  void _toggleActionMenu() {
    setState(() => _showActionMenu = !_showActionMenu);
    // 对齐iOS：展开操作菜单时关闭键盘
    if (_showActionMenu) {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatBloc, ChatState>(
      listenWhen: (prev, curr) => prev.errorMessage != curr.errorMessage,
      listener: (context, state) {
        if (state.errorMessage != null && state.messages.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localizeError(state.errorMessage))),
          );
          context.read<ChatBloc>().add(const ChatClearError());
        }
      },
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.messages != curr.messages ||
          prev.isSending != curr.isSending ||
          prev.isLoadingMore != curr.isLoadingMore ||
          prev.taskStatus != curr.taskStatus ||
          prev.peerIsTyping != curr.peerIsTyping,
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.backgroundFor(Theme.of(context).brightness),
          appBar: AppBar(
            title: FutureBuilder<Task?>(
              future: _taskFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Text(
                    snapshot.data!.displayTitle(Localizations.localeOf(context)),
                    overflow: TextOverflow.ellipsis,
                  );
                }
                return Text(context.l10n.chatTaskTitle(widget.taskId));
              },
            ),
            actions: [
              // 更多菜单（含任务详情等）
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'task_detail') {
                    context.safePush('/tasks/${widget.taskId}');
                  } else if (value == 'invite_member') {
                    _showInviteMemberSheet(context);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'task_detail',
                    child: Row(
                      children: [
                        const Icon(Icons.assignment_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(context.l10n.chatViewDetail),
                      ],
                    ),
                  ),
                  // 邀请团队成员（达人任务才显示）
                  PopupMenuItem(
                    value: 'invite_member',
                    child: Row(
                      children: [
                        const Icon(Icons.person_add_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(context.l10n.expertTeamInviteMember),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // 任务信息卡片
              _buildTaskInfoCard(state),

              // 媒体处理/发送进度 Banner
              // - _isProcessingMedia: 视频压缩/抽帧阶段(在 bloc 派发前)
              // - state.isSending: bloc 上传阶段(派发后)
              if (_isProcessingMedia || state.isSending)
                _buildMediaProgressBanner(state),

              // 消息列表（使用分组）
              Expanded(child: _buildGroupedMessageList(state)),

              // 任务关闭状态提示 - 对齐iOS closedTaskBar
              if (state.isTaskClosed) _buildClosedTaskBar(context),

              // 快捷操作（仅任务进行中显示）
              if (!state.isTaskClosed) _buildQuickActions(),

              // 操作菜单（可展开）
              if (!state.isTaskClosed)
                TaskChatActionMenu(
                  isExpanded: _showActionMenu,
                  onImagePicker: _pickImage,
                  onCameraPick: _pickCameraImage,
                  onFilePicker: _pickFile,
                  onTaskDetail: () {
                    context.safePush('/tasks/${widget.taskId}');
                  },
                ),

              // Typing indicator
              if (!state.isTaskClosed && state.peerIsTyping)
                _buildTypingIndicator(),

              // 输入区域
              if (!state.isTaskClosed) _buildInputArea(state),
            ],
          ),
        );
      },
    );
  }


  Widget _buildTaskInfoCard(ChatState state) {
    final statusText = _taskStatusDisplayText(context, state.taskStatus, state.isTaskClosed);
    final statusColor = state.isTaskClosed
        ? AppColors.textTertiaryLight
        : AppColors.success;

    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: const Border(
          bottom: BorderSide(color: AppColors.dividerLight),
        ),
      ),
      child: FutureBuilder<Task?>(
        future: _taskFuture,
        builder: (context, snapshot) {
          final task = snapshot.data;
          final icon = _taskCardIcon(task);
          final isGroup = task?.isMultiParticipant ?? false;
          final participantCount = task?.currentParticipants ?? 0;

          // 群聊时用 groups 图标覆盖默认图标
          final displayIcon = isGroup ? Icons.groups : icon;
          final iconColor = isGroup ? Colors.teal : AppColors.primary;

          // 状态文本：群聊时追加参与人数
          final displayStatus = isGroup && participantCount > 0
              ? '$statusText · ${context.l10n.chatParticipantCount(participantCount)}'
              : statusText;

          return Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: AppRadius.allSmall,
                ),
                child: Icon(displayIcon, color: iconColor, size: 20),
              ),
              AppSpacing.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.chatTaskTitle(widget.taskId),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      displayStatus,
                      style: TextStyle(fontSize: 12, color: statusColor),
                    ),
                  ],
                ),
              ),
              SmallActionButton(
                text: context.l10n.chatViewDetail,
                onPressed: () {
                  context.safePush('/tasks/${widget.taskId}');
                },
              ),
            ],
          );
        },
      ),
    );
  }

  /// 任务信息卡片图标：按任务来源显示（达人服务/跳蚤市场/达人活动用各自 icon，普通任务用任务类型 icon）
  IconData _taskCardIcon(Task? task) {
    if (task == null) return Icons.task_alt;
    final source = task.taskSource ?? AppConstants.taskSourceNormal;
    switch (source) {
      case AppConstants.taskSourceFleaMarket:
        return Icons.shopping_bag;
      case AppConstants.taskSourceExpertService:
        return Icons.star;
      case AppConstants.taskSourceExpertActivity:
        return Icons.groups;
      default:
        return TaskTypeHelper.getIcon(task.taskType);
    }
  }

  /// 根据 taskStatus 返回对应文案（与 AppConstants 及 l10n 对齐）
  String _taskStatusDisplayText(
    BuildContext context,
    String? taskStatus,
    bool isTaskClosed,
  ) {
    if (taskStatus == null || taskStatus.isEmpty) {
      return isTaskClosed
          ? context.l10n.chatTaskClosed
          : context.l10n.chatInProgress;
    }
    final l10n = context.l10n;
    switch (taskStatus) {
      case AppConstants.taskStatusOpen:
        return l10n.taskStatusOpen;
      case AppConstants.taskStatusInProgress:
        return l10n.taskStatusInProgress;
      case AppConstants.taskStatusPendingAcceptance:
        return l10n.taskStatusPendingAcceptance;
      case AppConstants.taskStatusCompleted:
        return l10n.taskStatusCompleted;
      case AppConstants.taskStatusCancelled:
        return l10n.taskStatusCancelled;
      case AppConstants.taskStatusPendingConfirmation:
        return l10n.taskStatusPendingConfirmation;
      case AppConstants.taskStatusPendingPayment:
        return l10n.taskStatusPendingPayment;
      case AppConstants.taskStatusDisputed:
        return l10n.taskStatusDisputed;
      case AppConstants.taskStatusConsulting:
        return l10n.taskStatusConsulting;
      case AppConstants.taskStatusNegotiating:
        return l10n.taskStatusNegotiating;
      case AppConstants.taskStatusPriceAgreed:
        return l10n.taskStatusPriceAgreed;
      case AppConstants.taskStatusExpired:
      case AppConstants.taskStatusClosed:
        return l10n.chatTaskClosed;
      default:
        return isTaskClosed ? l10n.chatTaskClosed : l10n.chatInProgress;
    }
  }

  /// 视频压缩/上传进度 Banner — 头部细条提示用户 app 在处理媒体。
  /// 视频压缩阶段(bloc 派发前)用 _processingLabel + 显示"取消"按钮;
  /// 上传阶段(state.isSending)用通用文案 chatSendingMedia,无 cancel。
  Widget _buildMediaProgressBanner(ChatState state) {
    final label = _isProcessingMedia && _processingLabel.isNotEmpty
        ? _processingLabel
        : context.l10n.chatSendingMedia;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryLight,
            ),
          ),
          if (_isCompressingVideo) ...[
            const SizedBox(width: 12),
            InkWell(
              onTap: _cancelVideoCompression,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  context.l10n.commonCancel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 任务已关闭提示栏 - 对齐iOS closedTaskStatusBar
  Widget _buildClosedTaskBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.textTertiaryLight.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline,
              size: 16, color: AppColors.textTertiaryLight),
          const SizedBox(width: 6),
          Text(
            context.l10n.chatTaskClosedHint,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textTertiaryLight,
            ),
          ),
        ],
      ),
    );
  }

  /// 快捷操作仅保留「遇到问题」，点击跳转 FAQ 页
  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _QuickActionChip(
            label: context.l10n.chatHasIssue,
            icon: Icons.help_outline,
            onTap: () => context.push(AppRoutes.faq),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedMessageList(ChatState state) {
    if (state.status == ChatStatus.loading && state.messages.isEmpty) {
      return const LoadingView();
    }

    if (state.status == ChatStatus.error && state.messages.isEmpty) {
      return ErrorStateView.loadFailed(
        message: context.localizeError(state.errorMessage ?? ''),
        onRetry: () {
          context.read<ChatBloc>().add(
                ChatLoadMessages(userId: '', taskId: widget.taskId),
              );
        },
      );
    }

    if (state.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline,
                size: 48, color: AppColors.textTertiaryLight),
            AppSpacing.vMd,
            Text(
              context.l10n.chatNoMessages,
              style: const TextStyle(color: AppColors.textSecondaryLight),
            ),
          ],
        ),
      );
    }

    // state.messages 为 新→旧，reverse:true 故视口初始在底部（最新）；加载更多在列表末尾（顶部）
    final currentUserId = _currentUserId ?? StorageService.instance.getUserId();
    final groups = groupMessages(state.messages, currentUserId);
    final showLoadMore = state.isLoadingMore;
    final groupCount = groups.length;

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      addAutomaticKeepAlives: false,
      itemCount: groupCount + (showLoadMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (showLoadMore && index == groupCount) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: LoadingIndicator(size: 20)),
          );
        }
        final group = groups[index];
        return MessageGroupBubbleView(
          group: group,
          onAvatarTap: () {
            if (group.senderId != null) {
              context.push('/user/${group.senderId}');
            }
          },
          onImageTap: (url) {
            FullScreenImageView.show(
              context,
              images: [url],
              allowSaveToAlbum: true,
            );
          },
        );
      },
    );
  }

  Widget _buildInputArea(ChatState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 使用半透明容器替代 BackdropFilter，减少滚动时的重绘开销；RepaintBoundary 减轻点击输入框卡顿
    return RepaintBoundary(
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark.withValues(alpha: 0.85)
            : AppColors.cardBackgroundLight.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                // 展开/收起操作菜单
                IconButton(
                  icon: AnimatedRotation(
                    turns: _showActionMenu ? 0.125 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.add_circle_outline),
                  ),
                  tooltip: context.l10n.chatMoreActions,
                  onPressed: _toggleActionMenu,
                  color: _showActionMenu
                      ? AppColors.primary
                      : AppColors.textSecondaryLight,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !state.isSending,
                    maxLines: 5,
                    minLines: 1,
                    maxLength: _maxCharacters,
                    buildCounter: (context,
                            {required currentLength,
                            required isFocused,
                            required maxLength}) =>
                        null, // 自定义计数器位置
                    decoration: InputDecoration(
                      hintText: context.l10n.chatInputHint,
                      filled: true,
                      fillColor: AppColors.skeletonBase,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.allPill,
                        borderSide: BorderSide.none,
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onChanged: (text) {
                      if (text.isNotEmpty) {
                        final now = DateTime.now();
                        if (_lastTypingSent == null ||
                            now.difference(_lastTypingSent!).inSeconds >= 2) {
                          _lastTypingSent = now;
                          context.read<ChatBloc>().add(const ChatSendTyping());
                        }
                      }
                    },
                    onSubmitted: (_) => _sendMessage(),
                    onTap: () {
                      if (_showActionMenu) {
                        setState(() => _showActionMenu = false);
                      }
                    },
                  ),
                ),
                AppSpacing.hSm,
                if (state.isSending)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: LoadingIndicator(),
                  )
                else
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _messageController,
                    builder: (context, value, child) {
                      return IconButton(
                        icon: const Icon(Icons.send),
                        tooltip: context.l10n.chatSendMessage,
                        onPressed: value.text.trim().isEmpty
                            ? null
                            : _sendMessage,
                        color: AppColors.primary,
                      );
                    },
                  ),
              ],
            ),
            // 字符计数器 - 对齐iOS (400+显示)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _messageController,
              builder: (context, value, child) {
                final charCount = value.text.length;
                final showCounter = charCount >= _showCounterThreshold;
                if (!showCounter) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 4, right: 8),
                  child: Text(
                    '$charCount/$_maxCharacters',
                    style: TextStyle(
                      fontSize: 11,
                      color: charCount >= _maxCharacters
                          ? AppColors.error
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 16,
            child: _TypingDotsAnimation(),
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.chatTyping,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiaryLight,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
            borderRadius: AppRadius.allPill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypingDotsAnimation extends StatefulWidget {
  @override
  State<_TypingDotsAnimation> createState() => _TypingDotsAnimationState();
}

class _TypingDotsAnimationState extends State<_TypingDotsAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = (_controller.value - delay).clamp(0.0, 1.0);
            final scale = 0.5 + 0.5 * (1 - (2 * t - 1).abs());
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.textTertiaryLight,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// 可邀请的团队成员列表 bottom sheet
class _InviteMemberList extends StatelessWidget {
  const _InviteMemberList({
    required this.members,
    required this.onInvite,
  });

  final List<ExpertMember> members;
  final void Function(ExpertMember) onInvite;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text(
                  context.l10n.expertTeamInviteMember,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${members.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: members.length,
              itemBuilder: (context, index) {
                final m = members[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: m.userAvatar != null
                        ? NetworkImage(m.userAvatar!)
                        : null,
                    child: m.userAvatar == null
                        ? Text(
                            (m.userName ?? '?')[0].toUpperCase(),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          )
                        : null,
                  ),
                  title: Text(m.userName ?? m.userId),
                  subtitle: Text(m.role.toUpperCase(),
                      style: Theme.of(context).textTheme.bodySmall),
                  trailing: FilledButton.tonal(
                    onPressed: () => onInvite(m),
                    child: Text(context.l10n.expertTeamInviteMember),
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
