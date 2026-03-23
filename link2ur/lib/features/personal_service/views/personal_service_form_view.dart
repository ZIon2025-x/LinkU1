import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/widgets/location_picker.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/personal_service_repository.dart';
import '../bloc/personal_service_bloc.dart';

/// Create / edit form for a personal service.
///
/// * **Create mode** — `serviceData` is `null`, form is empty.
/// * **Edit mode** — `serviceData` is pre-filled from existing service.
class PersonalServiceFormView extends StatelessWidget {
  const PersonalServiceFormView({super.key, this.serviceData});

  final Map<String, dynamic>? serviceData;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PersonalServiceBloc>(
      create: (context) => PersonalServiceBloc(
        repository: context.read<PersonalServiceRepository>(),
      ),
      child: _FormContent(serviceData: serviceData),
    );
  }
}

class _FormContent extends StatefulWidget {
  const _FormContent({this.serviceData});

  final Map<String, dynamic>? serviceData;

  @override
  State<_FormContent> createState() => _FormContentState();
}

class _FormContentState extends State<_FormContent> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  String _pricingType = 'fixed';
  String _locationType = 'online';
  String? _location;
  double? _latitude;
  double? _longitude;

  bool get _isEditMode => widget.serviceData != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final data = widget.serviceData!;
      _nameController.text = (data['service_name'] as String?) ?? '';
      _descriptionController.text = (data['description'] as String?) ?? '';
      final price = (data['base_price'] as num?)?.toDouble();
      if (price != null) {
        _priceController.text = price.toStringAsFixed(2);
      }
      _pricingType = (data['pricing_type'] as String?) ?? 'fixed';
      _locationType = (data['location_type'] as String?) ?? 'online';
      _location = (data['location'] as String?);
      _latitude = (data['latitude'] as num?)?.toDouble();
      _longitude = (data['longitude'] as num?)?.toDouble();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{
      'service_name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'pricing_type': _pricingType,
      'location_type': _locationType,
    };

    if (_locationType != 'online') {
      if (_location != null && _location!.isNotEmpty) {
        data['location'] = _location;
      }
      if (_latitude != null) data['latitude'] = _latitude;
      if (_longitude != null) data['longitude'] = _longitude;
    }

    // Only include price for non-negotiable types
    if (_pricingType != 'negotiable') {
      final priceText = _priceController.text.trim();
      if (priceText.isNotEmpty) {
        data['base_price'] = double.tryParse(priceText) ?? 0.0;
      }
    }

    final bloc = context.read<PersonalServiceBloc>();
    if (_isEditMode) {
      final id = widget.serviceData!['id']?.toString() ?? '';
      bloc.add(PersonalServiceUpdateRequested(id, data));
    } else {
      bloc.add(PersonalServiceCreateRequested(data));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<PersonalServiceBloc, PersonalServiceState>(
      listenWhen: (prev, curr) =>
          (prev.actionMessage != curr.actionMessage &&
              curr.actionMessage != null) ||
          (prev.errorMessage != curr.errorMessage &&
              curr.errorMessage != null),
      listener: (context, state) {
        // Success — pop back
        if (state.actionMessage != null) {
          final messenger = ScaffoldMessenger.of(context);
          final navigator = Navigator.of(context);
          messenger.showSnackBar(
            SnackBar(
              content: Text(context.localizeError(state.actionMessage!)),
              behavior: SnackBarBehavior.floating,
            ),
          );
          navigator.pop(true); // true signals success to caller
          return;
        }
        // Error — show snackbar
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.localizeError(state.errorMessage!)),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditMode ? context.l10n.personalServiceEdit : context.l10n.personalServiceCreate),
          actions: [
            BlocBuilder<PersonalServiceBloc, PersonalServiceState>(
              buildWhen: (prev, curr) =>
                  prev.isSubmitting != curr.isSubmitting,
              builder: (context, state) {
                return TextButton(
                  onPressed: state.isSubmitting ? null : _submit,
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _isEditMode
                              ? context.l10n.commonSave
                              : context.l10n.commonSubmit,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Service Name ──
                _SectionLabel(label: context.l10n.personalServiceName),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _nameController,
                  maxLength: 100,
                  decoration: InputDecoration(
                    hintText: '输入服务名称',
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.input,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入服务名称';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Description ──
                _SectionLabel(label: context.l10n.personalServiceDescription),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 5,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    hintText: '详细描述你提供的服务内容',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.input,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入服务描述';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Pricing Type ──
                _SectionLabel(label: context.l10n.personalServicePrice),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment<String>(
                        value: 'fixed',
                        label: Text(context.l10n.personalServicePricingFixed),
                        icon: const Icon(Icons.attach_money, size: 18),
                      ),
                      ButtonSegment<String>(
                        value: 'hourly',
                        label: Text(context.l10n.personalServicePricingHourly),
                        icon: const Icon(Icons.schedule, size: 18),
                      ),
                      ButtonSegment<String>(
                        value: 'negotiable',
                        label: Text(context.l10n.personalServicePricingNegotiable),
                        icon: const Icon(Icons.handshake_outlined, size: 18),
                      ),
                    ],
                    selected: {_pricingType},
                    onSelectionChanged: (selected) {
                      setState(() => _pricingType = selected.first);
                    },
                    showSelectedIcon: false,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Price (hidden when negotiable) ──
                if (_pricingType != 'negotiable') ...[
                  _SectionLabel(
                    label: context.l10n.personalServicePrice,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: InputDecoration(
                      prefixText: '\u00A3 ', // £ symbol
                      hintText: '0.00',
                      suffixText:
                          _pricingType == 'hourly' ? '/小时' : null,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.input,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return '请输入价格';
                      }
                      final price = double.tryParse(value.trim());
                      if (price == null || price < 0) {
                        return '请输入有效价格';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // ── Location Type ──
                _SectionLabel(label: context.l10n.personalServiceLocation),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: [
                      ButtonSegment<String>(
                        value: 'online',
                        label: Text(context.l10n.personalServiceLocationOnline),
                        icon: const Icon(Icons.language, size: 18),
                      ),
                      ButtonSegment<String>(
                        value: 'in_person',
                        label: Text(context.l10n.personalServiceLocationInPerson),
                        icon: const Icon(Icons.location_on_outlined, size: 18),
                      ),
                      ButtonSegment<String>(
                        value: 'both',
                        label: Text(context.l10n.personalServiceLocationBoth),
                        icon: const Icon(Icons.swap_horiz, size: 18),
                      ),
                    ],
                    selected: {_locationType},
                    onSelectionChanged: (selected) {
                      setState(() {
                        _locationType = selected.first;
                        if (_locationType == 'online') {
                          _location = null;
                          _latitude = null;
                          _longitude = null;
                        }
                      });
                    },
                    showSelectedIcon: false,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Location (when in_person or both) ──
                if (_locationType == 'in_person' || _locationType == 'both') ...[
                  _SectionLabel(label: context.l10n.personalServiceLocation),
                  const SizedBox(height: AppSpacing.sm),
                  LocationInputField(
                    initialValue: _location,
                    initialLatitude: _latitude,
                    initialLongitude: _longitude,
                    showOnlineOption: false,
                    onChanged: (value) {
                      _location = value;
                    },
                    onLocationPicked: (address, lat, lng) {
                      _location = address;
                      _latitude = lat;
                      _longitude = lng;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // ── Images placeholder ──
                _SectionLabel(label: context.l10n.personalServiceImages),
                const SizedBox(height: AppSpacing.sm),
                _ImagePlaceholder(isDark: isDark),

                const SizedBox(height: AppSpacing.xl),

                // ── Submit button (bottom) ──
                BlocBuilder<PersonalServiceBloc, PersonalServiceState>(
                  buildWhen: (prev, curr) =>
                      prev.isSubmitting != curr.isSubmitting,
                  builder: (context, state) {
                    return SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: state.isSubmitting ? null : _submit,
                        child: state.isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEditMode ? context.l10n.commonSave : context.l10n.publishService,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Section label
// =============================================================================

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

// =============================================================================
// Image upload placeholder
// =============================================================================

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.allMedium,
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('图片上传功能即将推出'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: AppRadius.allMedium,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.12),
            width: 1.5,
          ),
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.02),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_photo_alternate_outlined,
              size: 36,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '添加服务图片',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
