import 'package:flutter/material.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../utils/error_localizer.dart';
import '../utils/l10n_extension.dart';
import '../utils/logger.dart';
import '../widgets/app_feedback.dart';
import '../../data/repositories/discovery_repository.dart';

/// Shared dialog for searching and linking related content (tasks, flea market items, etc.)
/// Used by both PublishView and CreatePostView.
class LinkSearchDialog extends StatefulWidget {
  const LinkSearchDialog({
    super.key,
    required this.discoveryRepo,
    required this.isDark,
  });

  final DiscoveryRepository discoveryRepo;
  final bool isDark;

  @override
  State<LinkSearchDialog> createState() => _LinkSearchDialogState();
}

class _LinkSearchDialogState extends State<LinkSearchDialog> {
  late final TextEditingController _queryCtrl;
  List<Map<String, dynamic>> _userRelated = [];
  List<Map<String, dynamic>> _results = [];
  bool _loadingRelated = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _queryCtrl = TextEditingController();
    _loadUserRelated();
  }

  Future<void> _loadUserRelated() async {
    try {
      final list = await widget.discoveryRepo.getLinkableContentForUser();
      if (mounted) {
        setState(() {
          _userRelated = list;
          _loadingRelated = false;
        });
      }
    } catch (e) {
      AppLogger.warning('Failed to load linkable content for post: $e');
      if (mounted) setState(() => _loadingRelated = false);
    }
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final list = await widget.discoveryRepo.searchLinkableContent(query: q.trim());
      if (mounted) {
        setState(() {
          _results = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppFeedback.showError(context, context.localizeError(e.toString()));
      }
    }
  }

  Widget _buildLinkableList(List<Map<String, dynamic>> list, double height) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, i) {
          final r = list[i];
          final type = r['item_type'] as String? ?? '';
          final name = r['name'] as String? ?? r['title'] as String? ?? context.l10n.commonUnnamed;
          final id = r['item_id']?.toString() ?? '';
          final subtitle = r['subtitle'] as String? ?? type;
          return ListTile(
            title: Text(name),
            subtitle: Text(subtitle),
            onTap: () {
              Navigator.of(context).pop(<String, String>{'type': type, 'id': id, 'name': name});
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return AlertDialog(
      title: Text(context.l10n.publishRelatedContent),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryCtrl,
                      decoration: InputDecoration(
                        hintText: context.l10n.publishSearchHint,
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: _runSearch,
                    ),
                  ),
                  AppSpacing.hSm,
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _runSearch(_queryCtrl.text),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loadingRelated)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_userRelated.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.publishRelatedToMe,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                AppSpacing.vXs,
                _buildLinkableList(_userRelated, 200),
                const SizedBox(height: 12),
              ],
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (!_loading && _results.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.publishSearchResults,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                AppSpacing.vXs,
                _buildLinkableList(_results, 220),
              ],
              if (!_loading && _results.isEmpty && _queryCtrl.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(context.l10n.publishNoResultsTryKeywords),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
