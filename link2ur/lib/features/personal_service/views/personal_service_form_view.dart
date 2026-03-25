import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/expert_constants.dart';
import '../../../core/utils/service_category_helper.dart';
import '../../../core/widgets/cross_platform_image.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/personal_service_repository.dart';
import '../../../data/services/api_service.dart';
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
  final _nameEnController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _descriptionEnController = TextEditingController();
  final _priceController = TextEditingController();

  String? _category;
  String _pricingType = 'fixed';
  String _locationType = 'online';
  String? _location;
  double? _latitude;
  double? _longitude;

  final List<XFile> _newImages = [];
  final List<String> _existingImageUrls = [];
  final _imagePicker = ImagePicker();
  bool _isUploadingImages = false;
  static const _maxImages = 6;

  bool get _isEditMode => widget.serviceData != null && widget.serviceData!['id'] != null;

  @override
  void initState() {
    super.initState();
    if (widget.serviceData != null) {
      final data = widget.serviceData!;
      _nameController.text = (data['service_name'] as String?) ?? '';
      _nameEnController.text = (data['service_name_en'] as String?) ?? '';
      _descriptionController.text = (data['description'] as String?) ?? '';
      _descriptionEnController.text = (data['description_en'] as String?) ?? '';
      final price = (data['base_price'] as num?)?.toDouble();
      if (price != null) {
        _priceController.text = price.toStringAsFixed(2);
      }
      _category = data['category'] as String?;
      _pricingType = (data['pricing_type'] as String?) ?? 'fixed';
      _locationType = (data['location_type'] as String?) ?? 'online';
      _location = (data['location'] as String?);
      _latitude = (data['latitude'] as num?)?.toDouble();
      _longitude = (data['longitude'] as num?)?.toDouble();
      final images = data['images'] as List<dynamic>?;
      if (images != null) {
        _existingImageUrls.addAll(images.map((e) => e.toString()));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameEnController.dispose();
    _descriptionController.dispose();
    _descriptionEnController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _existingImageUrls.length - _newImages.length;
    if (remaining <= 0) return;
    try {
      final picked = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (!mounted || picked.isEmpty) return;
      setState(() {
        for (final file in picked) {
          if (_existingImageUrls.length + _newImages.length < _maxImages) {
            _newImages.add(file);
          }
        }
      });
    } on PlatformException catch (_) {
      // Permission denied or picker error — silently ignore
    }
  }

  void _removeNewImage(int index) {
    setState(() => _newImages.removeAt(index));
  }

  void _removeExistingImage(int index) {
    setState(() => _existingImageUrls.removeAt(index));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Upload new images first
    final List<String> uploadedUrls = [];
    if (_newImages.isNotEmpty) {
      setState(() => _isUploadingImages = true);
      try {
        final apiService = context.read<ApiService>();
        for (int i = 0; i < _newImages.length; i++) {
          if (!mounted) return;
          final file = _newImages[i];
          final bytes = await file.readAsBytes();
          final name = file.name.isNotEmpty ? file.name : 'service_${i + 1}.jpg';
          final response = await apiService.uploadFileBytes<Map<String, dynamic>>(
            '${ApiEndpoints.uploadPublicImage}?category=service_image',
            bytes: bytes,
            filename: name,
            fieldName: 'image',
          );
          final url = response.data?['url'] as String?;
          if (url != null && url.isNotEmpty) uploadedUrls.add(url);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUploadingImages = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.commonImageUploadFailed(e.toString())),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      if (mounted) setState(() => _isUploadingImages = false);
    }

    final allImages = [..._existingImageUrls, ...uploadedUrls];

    final data = <String, dynamic>{
      'service_name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'pricing_type': _pricingType,
      'location_type': _locationType,
    };

    final nameEn = _nameEnController.text.trim();
    if (nameEn.isNotEmpty) data['service_name_en'] = nameEn;
    final descEn = _descriptionEnController.text.trim();
    if (descEn.isNotEmpty) data['description_en'] = descEn;

    if (_category != null) {
      data['category'] = _category;
    }

    if (_locationType != 'online') {
      if (_location != null && _location!.isNotEmpty) {
        data['location'] = _location;
      }
      if (_latitude != null) data['latitude'] = double.parse(_latitude!.toStringAsFixed(8));
      if (_longitude != null) data['longitude'] = double.parse(_longitude!.toStringAsFixed(8));
    } else if (_isEditMode) {
      // 从线下改为线上时，清除旧地址
      data['location'] = null;
      data['latitude'] = null;
      data['longitude'] = null;
    }

    // Only include price for non-negotiable types
    if (_pricingType != 'negotiable') {
      final priceText = _priceController.text.trim();
      if (priceText.isNotEmpty) {
        data['base_price'] = double.tryParse(priceText) ?? 0.0;
      }
    }

    // Always send images array — empty list clears existing images on update
    data['images'] = allImages;

    if (!mounted) return;
    final bloc = context.read<PersonalServiceBloc>();
    if (_isEditMode) {
      final id = widget.serviceData!['id']?.toString() ?? '';
      bloc.add(PersonalServiceUpdateRequested(id, data));
    } else {
      bloc.add(PersonalServiceCreateRequested(data));
    }
  }

  Widget _buildImagePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCount = _existingImageUrls.length + _newImages.length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Existing images (already uploaded)
        ..._existingImageUrls.asMap().entries.map((entry) {
          return _ImageTile(
            child: Image.network(entry.value, width: 80, height: 80, fit: BoxFit.cover),
            onRemove: () => _removeExistingImage(entry.key),
          );
        }),
        // Newly picked images (not yet uploaded)
        ..._newImages.asMap().entries.map((entry) {
          return _ImageTile(
            child: CrossPlatformImage(xFile: entry.value, width: 80, height: 80),
            onRemove: () => _removeNewImage(entry.key),
          );
        }),
        // Add button
        if (totalCount < _maxImages)
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.skeletonBase,
                borderRadius: AppRadius.allSmall,
                border: Border.all(color: AppColors.textTertiaryLight.withValues(alpha: 0.5)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_photo_alternate_outlined, size: 28, color: AppColors.textTertiaryLight),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.commonImageCount(totalCount, _maxImages),
                    style: const TextStyle(fontSize: 10, color: AppColors.textTertiaryLight),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  onPressed: (state.isSubmitting || _isUploadingImages) ? null : _submit,
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
                    hintText: context.l10n.personalServiceNameHint,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.input,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.personalServiceNameRequired;
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
                    hintText: context.l10n.personalServiceDescriptionHint,
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.input,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.personalServiceDescriptionRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Service Name (English) ──
                _SectionLabel(label: context.l10n.personalServiceNameEn),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _nameEnController,
                  maxLength: 100,
                  decoration: InputDecoration(
                    hintText: context.l10n.personalServiceNameEnHint,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.input,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Description (English) ──
                _SectionLabel(label: context.l10n.personalServiceDescriptionEn),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _descriptionEnController,
                  maxLines: 3,
                  maxLength: 2000,
                  decoration: InputDecoration(
                    hintText: context.l10n.personalServiceDescriptionEnHint,
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.input,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Category ──
                _SectionLabel(label: context.l10n.serviceCategory),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: InputDecoration(
                    hintText: context.l10n.serviceCategoryHint,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.input,
                    ),
                  ),
                  items: ExpertConstants.serviceCategoryKeys
                      .map((key) => DropdownMenuItem(
                            value: key,
                            child: Row(
                              children: [
                                Icon(ServiceCategoryHelper.getIcon(key), size: 18),
                                const SizedBox(width: 8),
                                Text(ServiceCategoryHelper.getLocalizedLabel(key, context.l10n)),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _category = value);
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
                          _pricingType == 'hourly' ? context.l10n.personalServicePerHour : null,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.input,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return context.l10n.personalServicePriceRequired;
                      }
                      final price = double.tryParse(value.trim());
                      if (price == null || price <= 0) {
                        return context.l10n.personalServicePriceInvalid;
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

                // ── Images ──
                _SectionLabel(label: context.l10n.personalServiceImages),
                const SizedBox(height: AppSpacing.sm),
                _buildImagePicker(),
                if (_isUploadingImages) ...[
                  const SizedBox(height: AppSpacing.sm),
                  const LinearProgressIndicator(),
                ],

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
                        onPressed: (state.isSubmitting || _isUploadingImages) ? null : _submit,
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
// Image tile with remove button
// =============================================================================

class _ImageTile extends StatelessWidget {
  const _ImageTile({required this.child, required this.onRemove});

  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: AppRadius.allSmall,
          child: SizedBox(width: 80, height: 80, child: child),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
