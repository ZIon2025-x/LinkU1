import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/models/task.dart';

/// 获取发布者角色称谓
String getPosterRoleText(Task task, BuildContext context) {
  switch (task.taskSource) {
    case AppConstants.taskSourceFleaMarket:
      return context.l10n.taskDetailBuyer;
    case AppConstants.taskSourceExpertService:
      return context.l10n.taskDetailPublisher;
    case AppConstants.taskSourceExpertActivity:
      return context.l10n.taskDetailPublisher;
    default:
      return context.l10n.taskDetailPublisher;
  }
}

/// 获取接单者角色称谓
String getTakerRoleText(Task task, BuildContext context) {
  switch (task.taskSource) {
    case AppConstants.taskSourceFleaMarket:
      return context.l10n.taskDetailSeller;
    case AppConstants.taskSourceExpertService:
      return context.l10n.taskSourceExpertService;
    case AppConstants.taskSourceExpertActivity:
      return context.l10n.taskSourceExpertActivity;
    default:
      return context.l10n.actionsContactRecipient;
  }
}

/// 获取联系按钮文本
String getContactButtonText(
    Task task, bool isPoster, BuildContext context) {
  if (isPoster) {
    return task.isFleaMarketTask
        ? context.l10n.taskDetailSeller
        : context.l10n.actionsContactRecipient;
  } else {
    return task.isFleaMarketTask
        ? context.l10n.taskDetailBuyer
        : context.l10n.actionsContactPoster;
  }
}
