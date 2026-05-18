import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/error_localizer.dart';
import '../../../data/repositories/ai_qa_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../bloc/ai_qa_bloc.dart';

class AiQaAnswerFormView extends StatefulWidget {
  final int qid;
  const AiQaAnswerFormView({super.key, required this.qid});

  @override
  State<AiQaAnswerFormView> createState() => _AiQaAnswerFormViewState();
}

class _AiQaAnswerFormViewState extends State<AiQaAnswerFormView> {
  final _contentCtl = TextEditingController();
  final _titleCtl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => AiQaBloc(repository: ctx.read<AiQaRepository>())
        ..add(AiQaLoadDetail(widget.qid)),
      child: BlocConsumer<AiQaBloc, AiQaState>(
        listener: (context, state) {
          final l10n = AppLocalizations.of(context)!;
          if (state.status == AiQaStatus.submitted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.aiQaAnswerSubmitted)),
            );
            Navigator.of(context).pop();
          } else if (state.status == AiQaStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text(context.localizeError(state.errorMessage ?? '')),
              ),
            );
          }
        },
        builder: (context, state) {
          final l10n = AppLocalizations.of(context)!;
          return Scaffold(
            appBar: AppBar(title: Text(l10n.aiQaAnswerButton)),
            body: state.question == null
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: Colors.blue.shade50,
                          width: double.infinity,
                          child: Text(state.question!.title),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _titleCtl,
                          decoration: InputDecoration(
                            labelText: l10n.aiQaAnswerTitleOptional,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: TextField(
                            controller: _contentCtl,
                            maxLines: null,
                            expands: true,
                            decoration: InputDecoration(
                              labelText: l10n.aiQaAnswerContentHint,
                              alignLabelWithHint: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: state.status == AiQaStatus.submitting
                                ? null
                                : () {
                                    context.read<AiQaBloc>().add(
                                          AiQaSubmitAnswer(
                                            qid: widget.qid,
                                            title: _titleCtl.text.isEmpty
                                                ? null
                                                : _titleCtl.text,
                                            content: _contentCtl.text,
                                          ),
                                        );
                                  },
                            child: state.status == AiQaStatus.submitting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(l10n.aiQaAnswerButton),
                          ),
                        ),
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _contentCtl.dispose();
    _titleCtl.dispose();
    super.dispose();
  }
}
