import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:link2ur/core/utils/error_localizer.dart';
import 'package:link2ur/core/utils/l10n_extension.dart';
import 'package:link2ur/data/repositories/expert_team_repository.dart';
import 'package:link2ur/features/expert_team/bloc/expert_team_bloc.dart';

/// 创建达人团队申请页
class CreateTeamView extends StatelessWidget {
  const CreateTeamView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ExpertTeamBloc>(
      create: (context) => ExpertTeamBloc(
        repository: context.read<ExpertTeamRepository>(),
      ),
      child: const _CreateTeamContent(),
    );
  }
}

class _CreateTeamContent extends StatefulWidget {
  const _CreateTeamContent();

  @override
  State<_CreateTeamContent> createState() => _CreateTeamContentState();
}

class _CreateTeamContentState extends State<_CreateTeamContent> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _messageController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ExpertTeamBloc>().add(
          ExpertTeamApplyCreate(
            expertName: _nameController.text.trim(),
            bio: _bioController.text.trim().isEmpty
                ? null
                : _bioController.text.trim(),
            message: _messageController.text.trim().isEmpty
                ? null
                : _messageController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExpertTeamBloc, ExpertTeamState>(
      listener: (context, state) {
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localizeError(state.actionMessage!))),
          );
          context.pop();
        } else if (state.status == ExpertTeamStatus.error &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.localizeError(state.errorMessage!)),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.expertTeamCreateTeam),
        ),
        body: BlocBuilder<ExpertTeamBloc, ExpertTeamState>(
          builder: (context, state) {
            final isLoading = state.status == ExpertTeamStatus.loading;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar placeholder
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.grey.shade200,
                            child: const Icon(
                              Icons.group,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        context.l10n.expertTeamCreateAvatarPlaceholder,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Team name
                    Text(
                      context.l10n.expertTeamTeamName,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      enabled: !isLoading,
                      decoration: InputDecoration(
                        hintText: context.l10n.expertTeamTeamName,
                        border: const OutlineInputBorder(),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.l10n.expertTeamTeamName;
                        }
                        if (value.trim().length < 2) {
                          return '团队名称至少2个字符';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Bio
                    Text(
                      context.l10n.expertTeamBio,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _bioController,
                      enabled: !isLoading,
                      decoration: const InputDecoration(
                        hintText: '介绍你的团队（选填）',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // Application message
                    Text(
                      context.l10n.expertTeamApplicationMessage,
                      style: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _messageController,
                      enabled: !isLoading,
                      decoration: const InputDecoration(
                        hintText: '向管理员说明你的创建理由（选填）',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 32),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                context.l10n.expertTeamSubmit,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Info note
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '申请提交后将由管理员审核，审核通过后即可创建团队。',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
