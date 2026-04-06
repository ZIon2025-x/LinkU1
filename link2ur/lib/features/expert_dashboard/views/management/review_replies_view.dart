import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/utils/error_localizer.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../data/repositories/expert_team_repository.dart';
import '../../../../data/services/api_service.dart';

/// 评价回复页面
/// 后端：
/// - GET /api/experts/{id}/reviews
/// - POST /api/reviews/{review_id}/reply
class ReviewRepliesView extends StatefulWidget {
  const ReviewRepliesView({super.key, required this.expertId});
  final String expertId;

  @override
  State<ReviewRepliesView> createState() => _ReviewRepliesViewState();
}

class _ReviewRepliesViewState extends State<ReviewRepliesView> {
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await context.read<ApiService>().get<dynamic>(
            ApiEndpoints.taskExpertReviews(widget.expertId),
            queryParameters: {'limit': 50, 'offset': 0},
          );
      if (!response.isSuccess || response.data == null) {
        throw Exception(response.message ?? 'load_failed');
      }
      if (!mounted) return;
      final raw = response.data;
      final List<dynamic> list;
      if (raw is List) {
        list = raw;
      } else if (raw is Map<String, dynamic>) {
        list = (raw['items'] as List<dynamic>?) ?? [];
      } else {
        list = [];
      }
      setState(() {
        _reviews = list.map((e) => e as Map<String, dynamic>).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _reply(int reviewId, String content) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await context.read<ExpertTeamRepository>().replyToReview(reviewId, content);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.expertReviewReplySent)));
      _loadReviews();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.expertManagementReviewReplies)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(context.localizeError(_error!)))
              : _reviews.isEmpty
                  ? Center(child: Text(context.l10n.expertReviewNoReviews))
                  : RefreshIndicator(
                      onRefresh: _loadReviews,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _reviews.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final review = _reviews[index];
                          return _ReviewCard(
                            review: review,
                            onReply: (content) =>
                                _reply(review['id'] as int, content),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review, required this.onReply});
  final Map<String, dynamic> review;
  final Future<void> Function(String content) onReply;

  @override
  Widget build(BuildContext context) {
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final comment = review['comment'] as String? ?? '';
    final replyContent = review['reply_content'] as String?;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(
                5,
                (i) => Icon(
                  i < rating ? Icons.star : Icons.star_border,
                  size: 18,
                  color: Colors.amber,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(comment),
            const SizedBox(height: 8),
            if (replyContent != null && replyContent.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${context.l10n.expertReviewReplyLabel}: $replyContent',
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _showReplyDialog(context),
                  child: Text(context.l10n.expertReviewReplyButton),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showReplyDialog(BuildContext context) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    try {
      final result = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.expertReviewReplyButton),
          content: TextField(
            controller: controller,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: l10n.expertReviewReplyHint,
              border: const OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) Navigator.of(ctx).pop(text);
              },
              child: Text(l10n.commonSubmit),
            ),
          ],
        ),
      );
      if (result != null) {
        await onReply(result);
      }
    } finally {
      controller.dispose();
    }
  }
}
