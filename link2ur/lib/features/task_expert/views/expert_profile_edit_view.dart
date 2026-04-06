import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_spacing.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/expert_team_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../bloc/expert_dashboard_bloc.dart';

/// 达人资料编辑页 — standalone page with its own BLoC.
class ExpertProfileEditView extends StatefulWidget {
  const ExpertProfileEditView({super.key});

  @override
  State<ExpertProfileEditView> createState() => _ExpertProfileEditViewState();
}

class _ExpertProfileEditViewState extends State<ExpertProfileEditView> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;

  String? _expertId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _loadExpertId();
  }

  Future<void> _loadExpertId() async {
    try {
      final teams =
          await context.read<ExpertTeamRepository>().getMyTeams();
      if (!mounted) return;
      if (teams.isEmpty) {
        setState(() {
          _error = 'expert_team_not_found';
          _loading = false;
        });
        return;
      }
      setState(() {
        _expertId = teams.first.id;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.expertProfileEditTitle),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _expertId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.expertProfileEditTitle),
        ),
        body: Center(
          child: Text(context.localizeError(_error ?? 'expert_team_not_found')),
        ),
      );
    }

    return BlocProvider(
      create: (context) => ExpertDashboardBloc(
        repository: context.read<TaskExpertRepository>(),
        expertId: _expertId!,
      ),
      child: _ExpertProfileEditContent(
        nameController: _nameController,
        bioController: _bioController,
      ),
    );
  }
}

class _ExpertProfileEditContent extends StatelessWidget {
  const _ExpertProfileEditContent({
    required this.nameController,
    required this.bioController,
  });

  final TextEditingController nameController;
  final TextEditingController bioController;

  void _onSubmit(BuildContext context) {
    final name = nameController.text.trim();
    final bio = bioController.text.trim();
    context.read<ExpertDashboardBloc>().add(
          ExpertDashboardSubmitProfileUpdate(
            name: name.isEmpty ? null : name,
            bio: bio.isEmpty ? null : bio,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ExpertDashboardBloc, ExpertDashboardState>(
      listenWhen: (prev, curr) =>
          (curr.errorMessage != null &&
              prev.errorMessage != curr.errorMessage) ||
          (curr.actionMessage != null &&
              prev.actionMessage != curr.actionMessage),
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.localizeError(state.errorMessage!)),
            ),
          );
        }
        if (state.actionMessage == 'expertProfileUpdateSubmitted') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(context.localizeError(state.actionMessage!)),
            ),
          );
          context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.expertProfileEditTitle),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar placeholder
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.person,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    // TODO: implement avatar upload when image upload pattern is in place
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Name field
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.expertProfileEditName,
                  hintText: context.l10n.expertProfileEditNameHint,
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Bio field
              TextField(
                controller: bioController,
                decoration: InputDecoration(
                  labelText: context.l10n.expertProfileEditBio,
                  hintText: context.l10n.expertProfileEditBioHint,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                minLines: 4,
                maxLines: 8,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: AppSpacing.xl),

              // Submit button
              BlocBuilder<ExpertDashboardBloc, ExpertDashboardState>(
                buildWhen: (prev, curr) => prev.status != curr.status,
                builder: (context, state) {
                  final isSubmitting =
                      state.status == ExpertDashboardStatus.submitting;
                  return FilledButton(
                    onPressed: isSubmitting ? null : () => _onSubmit(context),
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.l10n.expertProfileEditSubmit),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
