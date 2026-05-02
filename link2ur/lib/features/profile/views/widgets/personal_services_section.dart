import 'package:flutter/material.dart';

import '../../../../core/utils/helpers.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../core/widgets/async_image_view.dart';
import '../../../../data/models/user.dart' show UserProfilePersonalService;
import 'b_section_card.dart';

/// 普通用户主页的「个人服务」section（对齐 user_profile_redesign.html · Plan B）。
/// 服务列表为空时整体折叠为 SizedBox.shrink，不留空白卡。
class PersonalServicesSection extends StatelessWidget {
  const PersonalServicesSection({super.key, required this.services});

  final List<UserProfilePersonalService> services;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);

    return BSectionCard(
      title: l10n.profilePersonalServices,
      subtitle: l10n.profilePersonalServicesCount(services.length),
      children: [
        for (var i = 0; i < services.length; i++)
          Padding(
            key: ValueKey('personal_service_${services[i].id}'),
            padding: EdgeInsets.only(bottom: i == services.length - 1 ? 0 : 10),
            child: _PersonalServiceCard(
              service: services[i],
              locale: locale,
            ),
          ),
      ],
    );
  }
}

class _PersonalServiceCard extends StatelessWidget {
  const _PersonalServiceCard({
    required this.service,
    required this.locale,
  });

  final UserProfilePersonalService service;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(service.displayName(locale))),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0F1F4)),
        ),
        child: Row(
          children: [
            _Thumb(service: service),
            const SizedBox(width: 14),
            Expanded(child: _Info(service: service, locale: locale)),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.service});
  final UserProfilePersonalService service;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: _categoryGradient(service.category),
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: service.images.isNotEmpty
          ? AsyncImageView(
              imageUrl: Helpers.getThumbnailUrl(service.images.first),
              fallbackUrl: Helpers.getImageUrl(service.images.first),
              width: 68,
              height: 68,
            )
          : Icon(
              _categoryIcon(service.category),
              color: _categoryIconColor(service.category),
              size: 28,
            ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.service, required this.locale});
  final UserProfilePersonalService service;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          service.displayName(locale),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            height: 1.4,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if ((service.description ?? '').isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            service.description!,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8B929C),
              height: 1.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Wrap(
                spacing: 5,
                runSpacing: 4,
                children: [
                  if ((service.category ?? '').isNotEmpty)
                    _Pill(label: service.category!),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _PriceBlock(service: service),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFEBECEF)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          color: Color(0xFF6F767E),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.service});
  final UserProfilePersonalService service;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (service.pricingType == 'negotiable') {
      return Text(
        l10n.profileServiceNegotiable,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4F46E5),
          letterSpacing: -0.2,
        ),
      );
    }
    final symbol = Helpers.currencySymbolFor(service.currency);
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$symbol${service.basePrice.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF4F46E5),
              letterSpacing: -0.4,
            ),
          ),
          TextSpan(
            text: ' ${l10n.profileServicePriceFrom}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF9A9FA5),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _categoryIcon(String? category) {
  switch (category) {
    case 'tutoring':
      return Icons.school_outlined;
    case 'errand':
    case 'pickup_dropoff':
      return Icons.delivery_dining_outlined;
    case 'photography':
      return Icons.camera_alt_outlined;
    case 'design':
      return Icons.palette_outlined;
    case 'translation':
      return Icons.translate_outlined;
    case 'programming':
      return Icons.code_outlined;
    case 'cleaning':
      return Icons.cleaning_services_outlined;
    case 'cooking':
      return Icons.restaurant_outlined;
    case 'pet_care':
      return Icons.pets_outlined;
    default:
      return Icons.work_outline;
  }
}

Color _categoryIconColor(String? category) {
  switch (category) {
    case 'tutoring':
      return const Color(0xFF78350F);
    case 'errand':
    case 'pickup_dropoff':
      return const Color(0xFF1E3A8A);
    case 'photography':
      return const Color(0xFF831843);
    case 'design':
      return const Color(0xFF5B21B6);
    default:
      return const Color(0xFF3730A3);
  }
}

LinearGradient _categoryGradient(String? category) {
  switch (category) {
    case 'tutoring':
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
      );
    case 'errand':
    case 'pickup_dropoff':
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFBFDBFE), Color(0xFF3B82F6)],
      );
    case 'photography':
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFBCFE8), Color(0xFFEC4899)],
      );
    case 'design':
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFDDD6FE), Color(0xFF7C3AED)],
      );
    default:
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE0E7FF), Color(0xFF6366F1)],
      );
  }
}
