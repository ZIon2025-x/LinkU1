import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:link2ur/core/utils/error_localizer.dart';
import 'package:link2ur/core/utils/l10n_extension.dart';
import 'package:link2ur/data/models/expert_team.dart';
import 'package:link2ur/data/repositories/expert_team_repository.dart';
import 'package:link2ur/features/expert_team/bloc/expert_team_bloc.dart';

class EditTeamProfileView extends StatelessWidget {
  final String expertId;
  const EditTeamProfileView({super.key, required this.expertId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExpertTeamBloc(
        repository: context.read<ExpertTeamRepository>(),
      )..add(ExpertTeamLoadDetail(expertId)),
      child: _EditBody(expertId: expertId),
    );
  }
}

class _EditBody extends StatefulWidget {
  final String expertId;
  const _EditBody({required this.expertId});

  @override
  State<_EditBody> createState() => _EditBodyState();
}

class _EditBodyState extends State<_EditBody> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _initFromTeam(ExpertTeam team) {
    if (!_initialized) {
      _nameCtrl.text = team.name;
      _bioCtrl.text = team.bio ?? '';
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpertTeamBloc, ExpertTeamState>(
      listenWhen: (prev, curr) =>
          curr.actionMessage != prev.actionMessage ||
          curr.errorMessage != prev.errorMessage,
      listener: (context, state) {
        final msg = state.actionMessage ?? state.errorMessage;
        if (msg != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localizeError(msg))),
          );
          if (state.actionMessage != null) {
            context.pop();
          }
        }
      },
      builder: (context, state) {
        final team = state.currentTeam;
        if (team != null) _initFromTeam(team);

        return Scaffold(
          appBar: AppBar(title: const Text('编辑团队信息')),
          body: team == null
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        // Avatar placeholder
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundImage: team.avatar != null
                                    ? NetworkImage(team.avatar!)
                                    : null,
                                child: team.avatar == null
                                    ? const Icon(Icons.group, size: 40)
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: context.l10n.expertTeamTeamName,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? '请输入团队名称' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _bioCtrl,
                          decoration: InputDecoration(
                            labelText: context.l10n.expertTeamBio,
                            border: const OutlineInputBorder(),
                          ),
                          maxLines: 4,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '提交后需要管理员审核',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.orange),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: state.status == ExpertTeamStatus.loading
                                ? null
                                : () {
                                    if (_formKey.currentState!.validate()) {
                                      final newName = _nameCtrl.text.trim() != team.name
                                          ? _nameCtrl.text.trim()
                                          : null;
                                      final newBio = _bioCtrl.text.trim() != (team.bio ?? '')
                                          ? _bioCtrl.text.trim()
                                          : null;
                                      if (newName == null && newBio == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('没有修改')),
                                        );
                                        return;
                                      }
                                      context.read<ExpertTeamRepository>().requestProfileUpdate(
                                        widget.expertId,
                                        newName: newName,
                                        newBio: newBio,
                                      ).then((_) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('修改申请已提交，等待管理员审核')),
                                          );
                                          context.pop();
                                        }
                                      }).catchError((e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('提交失败: $e')),
                                          );
                                        }
                                      });
                                    }
                                  },
                            child: state.status == ExpertTeamStatus.loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Text(context.l10n.expertTeamSubmit),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
