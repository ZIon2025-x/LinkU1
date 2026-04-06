import 'package:flutter/material.dart';

import 'expert_applications_management_view.dart';

/// Applications tab for ExpertDashboardView.
/// Embeds [ExpertApplicationsManagementView] without its own AppBar,
/// reusing the same BLoC and card logic (including the "查看任务" button).
class ExpertDashboardApplicationsTab extends StatelessWidget {
  const ExpertDashboardApplicationsTab({super.key, required this.expertId});

  final String expertId;

  @override
  Widget build(BuildContext context) {
    return ExpertApplicationsManagementView(
      expertId: expertId,
      showAppBar: false,
    );
  }
}
