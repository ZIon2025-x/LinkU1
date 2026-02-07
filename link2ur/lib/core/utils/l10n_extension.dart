import 'package:flutter/widgets.dart';
import '../../l10n/app_localizations.dart';

/// 便捷扩展 - 通过 context.l10n 快速访问 AppLocalizations
extension L10nExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}
