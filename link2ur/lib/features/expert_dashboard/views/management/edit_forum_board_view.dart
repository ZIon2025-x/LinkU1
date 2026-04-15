import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/error_localizer.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../data/repositories/expert_team_repository.dart';

/// 编辑达人论坛板块名称和描述
class EditForumBoardView extends StatefulWidget {
  const EditForumBoardView({super.key, required this.expertId});
  final String expertId;

  @override
  State<EditForumBoardView> createState() => _EditForumBoardViewState();
}

class _EditForumBoardViewState extends State<EditForumBoardView> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  final _nameZhCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _descEnCtrl = TextEditingController();
  final _descZhCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBoard();
  }

  Future<void> _loadBoard() async {
    try {
      final repo = context.read<ExpertTeamRepository>();
      final data = await repo.getExpertBoard(widget.expertId);
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = data['name'] as String? ?? '';
        _nameEnCtrl.text = data['name_en'] as String? ?? '';
        _nameZhCtrl.text = data['name_zh'] as String? ?? '';
        _descCtrl.text = data['description'] as String? ?? '';
        _descEnCtrl.text = data['description_en'] as String? ?? '';
        _descZhCtrl.text = data['description_zh'] as String? ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final repo = context.read<ExpertTeamRepository>();
      await repo.updateExpertBoard(widget.expertId, {
        'name': _nameCtrl.text.trim(),
        'name_en': _nameEnCtrl.text.trim(),
        'name_zh': _nameZhCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'description_en': _descEnCtrl.text.trim(),
        'description_zh': _descZhCtrl.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.expertForumBoardUpdated)),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorLocalizer.localizeFromException(context, e))),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameEnCtrl.dispose();
    _nameZhCtrl.dispose();
    _descCtrl.dispose();
    _descEnCtrl.dispose();
    _descZhCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.expertEditForumBoard)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(context.localizeError(_error!)))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.expertForumBoardName,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? l10n.expertForumBoardValidateName
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameEnCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.expertForumBoardNameEn,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameZhCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.expertForumBoardNameZh,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _descCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.expertForumBoardDesc,
                            border: const OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descEnCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.expertForumBoardDescEn,
                            border: const OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descZhCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.expertForumBoardDescZh,
                            border: const OutlineInputBorder(),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 32),
                        FilledButton(
                          onPressed: _isSubmitting ? null : _submit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(l10n.actionsConfirm),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
