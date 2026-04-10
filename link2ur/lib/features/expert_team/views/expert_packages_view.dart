import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:link2ur/core/utils/error_localizer.dart';
import 'package:link2ur/core/utils/l10n_extension.dart';
import 'package:link2ur/data/models/user_service_package.dart';
import 'package:link2ur/data/repositories/expert_team_repository.dart';
import 'package:link2ur/data/repositories/package_purchase_repository.dart';
import 'package:link2ur/features/expert_team/bloc/expert_team_bloc.dart';
import 'package:link2ur/features/expert_team/widgets/package_redemption_qr_sheet.dart';

class ExpertPackagesView extends StatelessWidget {
  const ExpertPackagesView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExpertTeamBloc(
        repository: context.read<ExpertTeamRepository>(),
      )..add(ExpertTeamLoadMyPackages()),
      child: const _PackagesBody(),
    );
  }
}

class _PackagesBody extends StatelessWidget {
  const _PackagesBody();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpertTeamBloc, ExpertTeamState>(
      listenWhen: (prev, curr) =>
          curr.actionMessage != null && curr.actionMessage != prev.actionMessage,
      listener: (context, state) {
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localizeError(state.actionMessage!))),
          );
        }
      },
      builder: (context, state) {
        final packages = state.packages;
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.expertTeamPackages)),
          body: packages.isEmpty
              ? Center(child: Text(context.l10n.expertTeamNoPackages))
              : ListView.builder(
                  itemCount: packages.length,
                  itemBuilder: (context, index) {
                    final p = packages[index];
                    final remaining = p.remainingSessions;
                    final total = p.totalSessions;
                    final status = p.status;
                    final packageId = p.id;
                    final canRedeem = status == 'active' && remaining > 0;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(context.l10n.expertPackageNumber('${p.id}'),
                                    style: Theme.of(context).textTheme.titleMedium),
                                _StatusChip(status: status),
                              ],
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: total > 0 ? (total - remaining) / total : 0,
                            ),
                            const SizedBox(height: 4),
                            Text(context.l10n.expertPackageRemainingCount(remaining, total)),
                            if (p.expiresAt != null) ...[
                              const SizedBox(height: 4),
                              Text(context.l10n.customerPackagesExpiresOn(p.expiresAt!.toIso8601String().substring(0, 10)),
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                            // Cooldown banner
                            if (p.inCooldown) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Colors.blue, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(context.l10n.packageCooldownBanner,
                                        style: Theme.of(context).textTheme.bodySmall)),
                                  ],
                                ),
                              ),
                            ],
                            // Expiry warning
                            if (_isExpiringSoon(p.expiresAt, p.remainingSessions)) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(context.l10n.packageExpirySoonBanner,
                                        style: Theme.of(context).textTheme.bodySmall)),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            // Action buttons
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (canRedeem)
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      showPackageRedemptionQrSheet(
                                        context: context,
                                        packageId: packageId,
                                        packageTitle: context.l10n
                                            .expertPackageQrTitle(packageId, remaining),
                                        repository: context
                                            .read<PackagePurchaseRepository>(),
                                      );
                                    },
                                    icon: const Icon(Icons.qr_code, size: 18),
                                    label: Text(context.l10n.expertPackageShowRedemptionCode),
                                  ),
                                if (p.canRefundFull || p.canRefundPartial)
                                  OutlinedButton.icon(
                                    onPressed: () => _confirmRefund(context, p),
                                    icon: const Icon(Icons.money_off, size: 18),
                                    label: Text(context.l10n.packageActionRefund),
                                  ),
                                if (p.canReview)
                                  OutlinedButton.icon(
                                    onPressed: () => _openReviewDialog(context, p),
                                    icon: const Icon(Icons.rate_review, size: 18),
                                    label: Text(context.l10n.packageActionReview),
                                  ),
                                if (p.canDispute)
                                  OutlinedButton.icon(
                                    onPressed: () => _openDisputeDialog(context, p),
                                    icon: const Icon(Icons.gavel, size: 18),
                                    label: Text(context.l10n.packageActionDispute),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

bool _isExpiringSoon(DateTime? expiresAt, int remaining) {
  if (expiresAt == null || remaining <= 0) return false;
  final diff = expiresAt.difference(DateTime.now().toUtc());
  return diff.inDays <= 7 && !diff.isNegative;
}

Future<void> _confirmRefund(BuildContext context, UserServicePackage p) async {
  final l10n = context.l10n;
  final isFull = p.canRefundFull;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.packageRefundConfirmTitle),
      content: Text(
        isFull
            ? l10n.packageRefundConfirmFullContent
            : l10n.packageRefundConfirmPartialContent,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.commonConfirm),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    final repo = context.read<PackagePurchaseRepository>();
    await repo.requestRefund(p.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.packageRefundSuccess)),
    );
    context.read<ExpertTeamBloc>().add(ExpertTeamLoadMyPackages());
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.localizeError(e.toString()))),
    );
  }
}

Future<void> _openReviewDialog(BuildContext context, UserServicePackage p) async {
  final l10n = context.l10n;
  int rating = 5;
  final commentController = TextEditingController();

  final submitted = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(l10n.packageActionReview),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return IconButton(
                  icon: Icon(
                    i < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () => setState(() => rating = i + 1),
                );
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: commentController,
              maxLines: 3,
              maxLength: 2000,
              decoration: InputDecoration(
                hintText: l10n.packageActionReview,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    ),
  );

  if (submitted != true || !context.mounted) {
    commentController.dispose();
    return;
  }

  try {
    final repo = context.read<PackagePurchaseRepository>();
    await repo.submitReview(
      p.id,
      rating: rating,
      comment: commentController.text,
    );
    commentController.dispose();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.packageReviewSuccess)),
    );
    context.read<ExpertTeamBloc>().add(ExpertTeamLoadMyPackages());
  } catch (e) {
    commentController.dispose();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.localizeError(e.toString()))),
    );
  }
}

Future<void> _openDisputeDialog(BuildContext context, UserServicePackage p) async {
  final l10n = context.l10n;
  final reasonController = TextEditingController();

  final submitted = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.packageActionDispute),
      content: TextField(
        controller: reasonController,
        maxLines: 4,
        maxLength: 2000,
        decoration: InputDecoration(
          hintText: l10n.packageActionDispute,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: () {
            if (reasonController.text.trim().isEmpty) return;
            Navigator.pop(ctx, true);
          },
          child: Text(l10n.commonConfirm),
        ),
      ],
    ),
  );

  if (submitted != true || !context.mounted) {
    reasonController.dispose();
    return;
  }

  try {
    final repo = context.read<PackagePurchaseRepository>();
    await repo.openDispute(
      p.id,
      reason: reasonController.text,
    );
    reasonController.dispose();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.packageDisputeSuccess)),
    );
    context.read<ExpertTeamBloc>().add(ExpertTeamLoadMyPackages());
  } catch (e) {
    reasonController.dispose();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.localizeError(e.toString()))),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Color color;
    String label;
    switch (status) {
      case 'active':
        color = Colors.green;
        label = l10n.packageStatusActive;
        break;
      case 'exhausted':
        color = Colors.orange;
        label = l10n.packageStatusExhausted;
        break;
      case 'expired':
        color = Colors.red;
        label = l10n.packageStatusExpired;
        break;
      case 'released':
        color = Colors.teal;
        label = l10n.packageStatusReleased;
        break;
      case 'refunded':
        color = Colors.blue;
        label = l10n.packageStatusRefunded;
        break;
      case 'partially_refunded':
        color = Colors.indigo;
        label = l10n.packageStatusPartiallyRefunded;
        break;
      case 'disputed':
        color = Colors.deepOrange;
        label = l10n.packageStatusDisputed;
        break;
      case 'cancelled':
        color = Colors.grey;
        label = l10n.packageStatusCancelled;
        break;
      default:
        color = Colors.grey;
        label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12)),
    );
  }
}
