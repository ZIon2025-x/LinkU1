import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:link2ur/core/utils/error_localizer.dart';
import 'package:link2ur/core/utils/l10n_extension.dart';
import 'package:link2ur/data/repositories/common_repository.dart';
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

  // 《达人团队收款与责任声明》本地状态：必须在提交前加载到 _termsVersion 并由用户勾选
  bool _termsAccepted = false;
  String? _termsVersion;
  Map<String, dynamic>? _termsContent;
  bool _termsLoading = true;
  bool _termsLoadError = false;
  // TapGestureRecognizer 必须 dispose,否则 build 多次会泄漏 (Flutter 标准做法)
  late final TapGestureRecognizer _termsLinkRecognizer;

  @override
  void initState() {
    super.initState();
    _termsLinkRecognizer = TapGestureRecognizer()..onTap = _showTermsViewer;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTerms());
  }

  @override
  void dispose() {
    _termsLinkRecognizer.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadTerms() async {
    if (!mounted) return;
    setState(() {
      _termsLoading = true;
      _termsLoadError = false;
    });
    try {
      // legal_documents 仅有 zh + en；zh_Hant 回退到 zh
      final lang = Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'zh';
      final doc = await context.read<CommonRepository>().getLegalDocument(
            type: 'expert_terms',
            lang: lang,
          );
      if (!mounted) return;
      setState(() {
        _termsContent = doc['content_json'] is Map<String, dynamic>
            ? doc['content_json'] as Map<String, dynamic>
            : <String, dynamic>{};
        _termsVersion = doc['version'] as String?;
        _termsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _termsLoading = false;
        _termsLoadError = true;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted || _termsVersion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.expertTermsRequired)),
      );
      return;
    }
    context.read<ExpertTeamBloc>().add(
          ExpertTeamApplyCreate(
            expertName: _nameController.text.trim(),
            agreedTermsVersion: _termsVersion!,
            bio: _bioController.text.trim().isEmpty
                ? null
                : _bioController.text.trim(),
            message: _messageController.text.trim().isEmpty
                ? null
                : _messageController.text.trim(),
          ),
        );
  }

  void _showTermsViewer() {
    if (_termsContent == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => _TermsViewerDialog(content: _termsContent!),
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
                          return context.l10n.expertTeamCreateNameTooShort;
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
                      decoration: InputDecoration(
                        hintText: context.l10n.expertTeamCreateBioHint,
                        border: const OutlineInputBorder(),
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
                      decoration: InputDecoration(
                        hintText: context.l10n.expertTeamCreateMessageHint,
                        border: const OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 24),

                    // 《达人团队收款与责任声明》勾选 (migration 229)
                    _buildTermsCheckbox(context, isLoading),
                    const SizedBox(height: 16),

                    // Submit button — 必须 terms 加载完成且勾选才可点
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (isLoading ||
                                _termsLoading ||
                                _termsLoadError ||
                                _termsVersion == null ||
                                !_termsAccepted)
                            ? null
                            : _submit,
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
                              context.l10n.expertTeamCreateInfoNote,
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

  Widget _buildTermsCheckbox(BuildContext context, bool blocLoading) {
    final isDisabled = blocLoading || _termsLoading || _termsLoadError;
    final theme = Theme.of(context);

    if (_termsLoading) {
      return Row(
        children: const [
          SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      );
    }

    if (_termsLoadError) {
      return Row(
        children: [
          Icon(Icons.error_outline,
              size: 16, color: theme.colorScheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.expertTermsLoadFailed,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
          TextButton(
            onPressed: _loadTerms,
            child: Text(context.l10n.commonRetry),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: _termsAccepted,
            onChanged: isDisabled
                ? null
                : (v) => setState(() => _termsAccepted = v ?? false),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: isDisabled
                ? null
                : () => setState(() => _termsAccepted = !_termsAccepted),
            child: Text.rich(
              TextSpan(
                style: theme.textTheme.bodyMedium,
                children: [
                  TextSpan(text: context.l10n.expertTermsCheckboxPrefix),
                  TextSpan(
                    text: context.l10n.expertTermsCheckboxLink,
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: _termsLinkRecognizer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 《达人团队收款与责任声明》全屏阅读器
/// content_json 直接来自 backend legal_documents 表（参考 230 migration 的字段顺序）
class _TermsViewerDialog extends StatelessWidget {
  final Map<String, dynamic> content;
  const _TermsViewerDialog({required this.content});

  /// content_json 字段渲染顺序：与 backend migration 230 一致
  static const _sectionKeys = <String>[
    'intro',
    'payoutHolder',
    'internalSplit',
    'taxResponsibility',
    'stripeTerms',
    'volumeNotice',
    'contactUs',
    'importantNotice',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = (content['title'] as String?) ??
        context.l10n.expertTermsViewerTitle;
    final lastUpdated = content['lastUpdated'] as String?;
    final version = content['version'] as String?;
    final effectiveDate = content['effectiveDate'] as String?;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: context.l10n.expertTermsClose,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (lastUpdated != null || version != null || effectiveDate != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          [lastUpdated, version, effectiveDate]
                              .whereType<String>()
                              .join('  ·  '),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.grey),
                        ),
                      ),
                    for (final key in _sectionKeys)
                      if (content[key] is String && (content[key] as String).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            content[key] as String,
                            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
