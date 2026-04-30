import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../core/widgets/async_image_view.dart';
import '../../../../data/models/user.dart' show UserProfilePersonalService;

/// 普通用户主页的「个人服务」section。
/// 服务列表为空时整体折叠为 SizedBox.shrink，不留空白卡。
class PersonalServicesSection extends StatelessWidget {
  const PersonalServicesSection({super.key, required this.services});

  final List<UserProfilePersonalService> services;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.workspace_premium_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(l10n.profilePersonalServices,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Text(l10n.profilePersonalServicesCount(services.length),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: AppSpacing.md),
          ...services.map((s) => Padding(
                key: ValueKey('personal_service_${s.id}'),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _PersonalServiceCard(service: s, locale: locale, isDark: isDark),
              )),
        ],
      ),
    );
  }
}

class _PersonalServiceCard extends StatelessWidget {
  const _PersonalServiceCard({
    required this.service,
    required this.locale,
    required this.isDark,
  });

  final UserProfilePersonalService service;
  final Locale locale;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final priceText = _priceText(context);

    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(service.displayName(locale))),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allMedium,
        ),
        child: Row(children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.medium),
              gradient: _categoryGradient(service.category),
            ),
            alignment: Alignment.center,
            child: service.images.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    child: AsyncImageView(
                      imageUrl: Helpers.getThumbnailUrl(service.images.first),
                      fallbackUrl: Helpers.getImageUrl(service.images.first),
                      width: 56, height: 56,
                    ),
                  )
                : Icon(_categoryIcon(service.category), color: Colors.white, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.displayName(locale),
                    style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if ((service.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(service.description!,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(priceText,
              style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary,
              )),
        ]),
      ),
    );
  }

  String _priceText(BuildContext context) {
    final l10n = context.l10n;
    if (service.pricingType == 'negotiable') return l10n.profileServiceNegotiable;
    final symbol = Helpers.currencySymbolFor(service.currency);
    return '$symbol${service.basePrice.toStringAsFixed(0)} ${l10n.profileServicePriceFrom}';
  }

  IconData _categoryIcon(String? category) {
    switch (category) {
      case 'tutoring': return Icons.school_outlined;
      case 'errand':
      case 'pickup_dropoff': return Icons.delivery_dining_outlined;
      case 'photography': return Icons.camera_alt_outlined;
      case 'design': return Icons.palette_outlined;
      case 'translation': return Icons.translate_outlined;
      case 'programming': return Icons.code_outlined;
      case 'cleaning': return Icons.cleaning_services_outlined;
      case 'cooking': return Icons.restaurant_outlined;
      case 'pet_care': return Icons.pets_outlined;
      default: return Icons.work_outline;
    }
  }

  LinearGradient _categoryGradient(String? category) {
    switch (category) {
      case 'tutoring':
        return const LinearGradient(colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)]);
      case 'errand':
      case 'pickup_dropoff':
        return const LinearGradient(colors: [Color(0xFFBFDBFE), Color(0xFF3B82F6)]);
      case 'photography':
        return const LinearGradient(colors: [Color(0xFFFBCFE8), Color(0xFFEC4899)]);
      case 'design':
        return const LinearGradient(colors: [Color(0xFFDDD6FE), Color(0xFF7C3AED)]);
      default:
        return const LinearGradient(colors: [Color(0xFFE0E7FF), Color(0xFF6366F1)]);
    }
  }
}
