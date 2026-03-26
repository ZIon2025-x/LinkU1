import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/utils/helpers.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../../core/utils/adaptive_dialogs.dart';
import '../../tasks/views/create_task_widgets.dart';
import '../../../core/widgets/cross_platform_image.dart';
import '../../../core/widgets/currency_selector.dart';
import '../../../core/widgets/image_remove_button.dart';
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
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  String? _category;
  String _pricingType = 'fixed';
  String _selectedCurrency = 'GBP';
  String _locationType = 'online';
  final List<String> _selectedSkills = [];
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
      _descriptionController.text = (data['description'] as String?) ?? '';
      final price = (data['base_price'] as num?)?.toDouble();
      if (price != null) {
        _priceController.text = price.toStringAsFixed(2);
      }
      _category = data['category'] as String?;
      _pricingType = (data['pricing_type'] as String?) ?? 'fixed';
      _selectedCurrency = (data['currency'] as String?) ?? 'GBP';
      _locationType = (data['location_type'] as String?) ?? 'online';
      _location = (data['location'] as String?);
      _latitude = (data['latitude'] as num?)?.toDouble();
      _longitude = (data['longitude'] as num?)?.toDouble();
      final images = data['images'] as List<dynamic>?;
      if (images != null) {
        _existingImageUrls.addAll(images.map((e) => e.toString()));
      }
      final skills = data['skills'] as List<dynamic>?;
      if (skills != null) {
        _selectedSkills.addAll(skills.whereType<String>());
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // Skill suggestions per category (same as task creation)
  static const _skillSuggestions = <String, List<String>>{
    'tutoring': ['数学', '英语', '编程', '考试辅导', '论文'],
    'translation': ['文件翻译', '口译', '字幕'],
    'design': ['Figma', 'UI设计', 'Photoshop', '海报'],
    'programming': ['Python', 'Flutter', 'React', 'JavaScript'],
    'writing': ['文案', '论文', 'SEO', '公众号'],
    'photography': ['人像', '产品', '风光', '视频'],
    'moving': ['搬家', '打包', '家具拆装'],
    'cleaning': ['日常清洁', '深度清洁', '收纳'],
    'repair': ['水电', '家电', '家具'],
    'cooking': ['中餐', '聚会餐饮', '烘焙'],
    'language_help': ['陪同翻译', '电话翻译', '信件代写'],
    'government': ['签证材料', '银行开户', 'GP注册'],
    'pet_care': ['遛狗', '寄养', '美容'],
    'digital': ['装系统', '修电脑', '网络设置'],
  };

  void _onSkillToggle(String skill) {
    setState(() {
      if (_selectedSkills.contains(skill)) {
        _selectedSkills.remove(skill);
      } else {
        _selectedSkills.add(skill);
      }
    });
  }

  Future<void> _addCustomSkill() async {
    final result = await AdaptiveDialogs.showInputDialog(
      context: context,
      title: context.l10n.createTaskAddCustomSkill,
      placeholder: context.l10n.personalServiceSkills,
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        if (!_selectedSkills.contains(result)) {
          _selectedSkills.add(result);
        }
      });
    }
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
      'currency': _selectedCurrency,
      'location_type': _locationType,
    };

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

    if (_selectedSkills.isNotEmpty) {
      data['skills'] = _selectedSkills;
    }

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
                // ── 服务名称 ──
                SectionCard(
                  label: context.l10n.personalServiceName,
                  isRequired: true,
                  child: TextFormField(
                    controller: _nameController,
                    maxLength: 100,
                    decoration: InputDecoration(
                      hintText: context.l10n.personalServiceNameHint,
                      border: OutlineInputBorder(borderRadius: AppRadius.input),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return context.l10n.personalServiceNameRequired;
                      }
                      return null;
                    },
                  ),
                ),

                // ── 分类 ──
                SectionCard(
                  label: context.l10n.serviceCategory,
                  isRequired: true,
                  child: CategoryDropdown(
                    selected: _category ?? 'other',
                    isStudentVerified: context.read<AuthBloc>().state.user?.isStudentVerified ?? false,
                    onSelected: (value) {
                      setState(() => _category = value);
                    },
                  ),
                ),

                // ── 描述 ──
                SectionCard(
                  label: context.l10n.personalServiceDescription,
                  isRequired: true,
                  child: TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      hintText: context.l10n.personalServiceDescriptionHint,
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: AppRadius.input),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return context.l10n.personalServiceDescriptionRequired;
                      }
                      return null;
                    },
                  ),
                ),

                // ── 技能标签（可选）──
                SectionCard(
                  label: context.l10n.personalServiceSkills,
                  child: SkillTagSelector(
                    selected: _selectedSkills,
                    suggestions: _skillSuggestions[_category] ?? [],
                    onToggle: _onSkillToggle,
                    onAddCustom: _addCustomSkill,
                  ),
                ),

                // ── 定价 ──
                SectionCard(
                  label: context.l10n.personalServicePrice,
                  isRequired: true,
                  child: Column(
                    children: [
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
                      if (_pricingType != 'negotiable') ...[
                        const SizedBox(height: AppSpacing.md),
                        CurrencySelector(
                          selected: _selectedCurrency,
                          onChanged: (v) => setState(() => _selectedCurrency = v),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          decoration: InputDecoration(
                            prefixText: '${Helpers.currencySymbolFor(_selectedCurrency)} ',
                            hintText: '0.00',
                            suffixText: _pricingType == 'hourly' ? context.l10n.personalServicePerHour : null,
                            border: OutlineInputBorder(borderRadius: AppRadius.input),
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
                      ],
                    ],
                  ),
                ),

                // ── 服务方式 ──
                SectionCard(
                  label: context.l10n.personalServiceLocation,
                  isRequired: true,
                  child: Column(
                    children: [
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
                      if (_locationType == 'in_person' || _locationType == 'both') ...[
                        const SizedBox(height: AppSpacing.md),
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
                      ],
                    ],
                  ),
                ),

                // ── 图片 ──
                SectionCard(
                  label: context.l10n.personalServiceImages,
                  child: Column(
                    children: [
                      _buildImagePicker(),
                      if (_isUploadingImages) ...[
                        const SizedBox(height: AppSpacing.sm),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                ),

                // ── 小贴士 ──
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.publishTipsSectionTitle,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final tip in [
                        context.l10n.publishTip1,
                        context.l10n.publishTip2,
                        context.l10n.publishTip3,
                        context.l10n.publishTip4,
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('💡', style: TextStyle(fontSize: 11)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  tip,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : const Color(0xFF666666),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // ── 提交按钮 ──
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
          top: -8,
          right: -8,
          child: ImageRemoveButton(onTap: onRemove),
        ),
      ],
    );
  }
}
