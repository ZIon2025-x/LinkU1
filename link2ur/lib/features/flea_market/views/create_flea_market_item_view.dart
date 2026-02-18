import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/cross_platform_image.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../../../data/models/flea_market.dart';
import '../bloc/flea_market_bloc.dart';

/// 发布跳蚤市场商品页面
class CreateFleaMarketItemView extends StatelessWidget {
  const CreateFleaMarketItemView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FleaMarketBloc(
        fleaMarketRepository: context.read<FleaMarketRepository>(),
      ),
      child: const _CreateFleaMarketItemContent(),
    );
  }
}

class _CreateFleaMarketItemContent extends StatefulWidget {
  const _CreateFleaMarketItemContent();

  @override
  State<_CreateFleaMarketItemContent> createState() =>
      _CreateFleaMarketItemContentState();
}

class _CreateFleaMarketItemContentState
    extends State<_CreateFleaMarketItemContent> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  String? _location;
  double? _latitude;
  double? _longitude;
  String? _selectedCategory;
  final List<XFile> _selectedImages = [];
  final _imagePicker = ImagePicker();
  bool _isUploadingImages = false;

  List<(String, String)> _getCategories(BuildContext context) => [
    (context.l10n.fleaMarketCategoryKeyElectronics, context.l10n.fleaMarketCategoryElectronics),
    (context.l10n.fleaMarketCategoryKeyBooks, context.l10n.fleaMarketCategoryBooks),
    (context.l10n.fleaMarketCategoryKeyDaily, context.l10n.fleaMarketCategoryDailyUse),
    (context.l10n.fleaMarketCategoryKeyClothing, context.l10n.fleaMarketCategoryClothing),
    (context.l10n.fleaMarketCategoryKeySports, context.l10n.fleaMarketCategorySports),
    (context.l10n.fleaMarketCategoryKeyOther, context.l10n.fleaMarketCategoryOther),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (!mounted) return;
      if (pickedFiles.isNotEmpty) {
        setState(() {
          for (final file in pickedFiles) {
            if (_selectedImages.length < 5) {
              _selectedImages.add(file);
            }
          }
        });
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      if (e.code == 'already_active') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.fleaMarketPickImageBusy),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.fleaMarketImageSelectFailed}: ${e.message ?? e.code}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.l10n.fleaMarketImageSelectFailed}: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.fleaMarketInvalidPrice),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final repo = context.read<FleaMarketRepository>();
    final List<String> imageUrls = [];

    if (_selectedImages.isNotEmpty) {
      setState(() => _isUploadingImages = true);
      try {
        for (int i = 0; i < _selectedImages.length; i++) {
          final file = _selectedImages[i];
          final bytes = await file.readAsBytes();
          final name = file.name.isNotEmpty
              ? file.name
              : 'image_${i + 1}.jpg';
          final url = await repo.uploadImage(bytes, name);
          if (url.isNotEmpty) imageUrls.add(url);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUploadingImages = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('上传图片失败: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _isUploadingImages = false);
      }
    }

    final request = CreateFleaMarketRequest(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      price: price,
      category: _selectedCategory,
      location: _location,
      latitude: _latitude,
      longitude: _longitude,
      images: imageUrls,
    );

    if (!mounted) return;
    context.read<FleaMarketBloc>().add(FleaMarketCreateItem(request));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FleaMarketBloc, FleaMarketState>(
      listenWhen: (prev, curr) => prev.actionMessage != curr.actionMessage,
      listener: (context, state) {
        if (state.actionMessage != null) {
          final l10n = context.l10n;
          final message = switch (state.actionMessage) {
            'item_published' => l10n.actionItemPublished,
            'publish_failed' => l10n.actionPublishFailed,
            'purchase_success' => l10n.actionPurchaseSuccess,
            'purchase_failed' => l10n.actionPurchaseFailed,
            'item_updated' => l10n.actionItemUpdated,
            'update_failed' => l10n.actionUpdateFailed,
            'refresh_success' => l10n.actionRefreshSuccess,
            'refresh_failed' => l10n.actionRefreshFailed,
            _ => state.actionMessage ?? '',
          };
          final displayMessage = state.errorMessage != null
              ? '$message: ${state.errorMessage}'
              : message;
          final isSuccess = state.actionMessage == 'item_published';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(displayMessage),
              backgroundColor: isSuccess ? AppColors.success : AppColors.error,
            ),
          );
          if (isSuccess) {
            context.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.fleaMarketPublishItem),
        ),
        body: SingleChildScrollView(
          padding: AppSpacing.allMd,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 商品图片
                Text(
                  context.l10n.fleaMarketProductImages,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                AppSpacing.vSm,
                _buildImagePicker(),
                AppSpacing.vLg,

                // 商品标题
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: context.l10n.fleaMarketProductTitle,
                    hintText: context.l10n.fleaMarketProductTitlePlaceholder,
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.allMedium,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.fleaMarketTitleRequired;
                    }
                    if (value.trim().length < 2) {
                      return context.l10n.fleaMarketTitleMinLength;
                    }
                    return null;
                  },
                ),
                AppSpacing.vMd,

                // 商品描述
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: context.l10n.fleaMarketDescOptional,
                    hintText: context.l10n.fleaMarketDescHint,
                    prefixIcon: const Icon(Icons.description_outlined),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.allMedium,
                    ),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  maxLength: 500,
                ),
                AppSpacing.vMd,

                // 价格
                TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: context.l10n.fleaMarketPrice,
                    hintText: '0.00',
                    prefixIcon: const Icon(Icons.attach_money),
                    prefixText: '£ ',
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.allMedium,
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.fleaMarketPriceRequired;
                    }
                    final price = double.tryParse(value.trim());
                    if (price == null || price <= 0) {
                      return context.l10n.fleaMarketInvalidPrice;
                    }
                    return null;
                  },
                ),
                AppSpacing.vMd,

                // 分类
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: context.l10n.fleaMarketCategoryLabel,
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.allMedium,
                    ),
                  ),
                  items: _getCategories(context)
                      .map((category) => DropdownMenuItem(
                            value: category.$1,
                            child: Text(category.$2),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                  hint: Text(context.l10n.fleaMarketSelectCategory),
                ),
                AppSpacing.vMd,

                // 位置
                Text(
                  context.l10n.fleaMarketLocationOptional,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                AppSpacing.vSm,
                LocationInputField(
                  hintText: context.l10n.fleaMarketLocationHint,
                  onChanged: (address) {
                    _location = address.isNotEmpty ? address : null;
                    _latitude = null;
                    _longitude = null;
                  },
                  onLocationPicked: (address, lat, lng) {
                    _location = address.isNotEmpty ? address : null;
                    _latitude = lat;
                    _longitude = lng;
                  },
                ),
                AppSpacing.vXl,

                // 提交按钮
                BlocBuilder<FleaMarketBloc, FleaMarketState>(
                  builder: (context, state) {
                    final busy = _isUploadingImages || state.isSubmitting;
                    return SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        text: context.l10n.fleaMarketPublishItem,
                        onPressed: busy ? null : _submitForm,
                        isLoading: busy,
                      ),
                    );
                  },
                ),
                AppSpacing.vLg,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // 已选图片
        ..._selectedImages.asMap().entries.map((entry) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: AppRadius.allSmall,
                child: CrossPlatformImage(
                  xFile: entry.value,
                  width: 80,
                  height: 80,
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  onTap: () => _removeImage(entry.key),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),

        // 添加按钮（后端最多 5 张）
        if (_selectedImages.length < 5)
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.skeletonBase,
                borderRadius: AppRadius.allSmall,
                border: Border.all(
                  color: AppColors.textTertiaryLight.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 28,
                    color: AppColors.textTertiaryLight,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_selectedImages.length}/5',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
