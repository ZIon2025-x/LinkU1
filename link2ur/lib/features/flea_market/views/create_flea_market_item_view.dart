import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/widgets/image_remove_button.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/adaptive_dialogs.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/app_select_sheet.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/cross_platform_image.dart';
import '../../../core/widgets/currency_selector.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../../../data/models/flea_market.dart';
import '../../tasks/views/create_task_widgets.dart';
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
  final _depositController = TextEditingController();
  final _rentalPriceController = TextEditingController();

  String? _location;
  double? _latitude;
  double? _longitude;
  String? _selectedCategory;
  String _selectedCurrency = 'GBP';
  String _listingType = 'sale';
  String _rentalUnit = 'day';
  final List<XFile> _selectedImages = [];
  final _imagePicker = ImagePicker();
  bool _isUploadingImages = false;

  bool get _hasUnsavedChanges {
    return _titleController.text.isNotEmpty ||
        _descriptionController.text.isNotEmpty ||
        _priceController.text.isNotEmpty ||
        _selectedImages.isNotEmpty;
  }

  /// API key 使用固定英文常量（对齐后端 FLEA_MARKET_CATEGORIES），显示名使用本地化
  List<(String, String)> _getCategories(BuildContext context) => [
    ('Electronics', context.l10n.fleaMarketCategoryElectronics),
    ('Books', context.l10n.fleaMarketCategoryBooks),
    ('Home & Living', context.l10n.fleaMarketCategoryDailyUse),
    ('Clothing', context.l10n.fleaMarketCategoryClothing),
    ('Sports', context.l10n.fleaMarketCategorySports),
    ('Furniture', context.l10n.fleaMarketCategoryFurniture),
    ('Accessories', context.l10n.fleaMarketCategoryAccessories),
    ('Beauty & Personal', context.l10n.fleaMarketCategoryBeauty),
    ('Toys & Games', context.l10n.fleaMarketCategoryToysGames),
    ('Other', context.l10n.fleaMarketCategoryOther),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _depositController.dispose();
    _rentalPriceController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
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

    final isRental = _listingType == 'rental';

    // Parse price based on listing type
    final double price;
    if (isRental) {
      final rentalPrice = double.tryParse(_rentalPriceController.text.trim());
      if (rentalPrice == null || rentalPrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.fleaMarketInvalidPrice),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      price = rentalPrice;
    } else {
      final salePrice = double.tryParse(_priceController.text.trim());
      if (salePrice == null || salePrice < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.fleaMarketInvalidPrice),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      price = salePrice;
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
              content: Text(context.l10n.commonImageUploadFailed(e.toString())),
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
      currency: _selectedCurrency,
      category: _selectedCategory,
      location: _location,
      latitude: _latitude,
      longitude: _longitude,
      images: imageUrls,
      listingType: _listingType,
      deposit: isRental ? double.parse(_depositController.text.trim()) : null,
      rentalPrice: isRental ? double.parse(_rentalPriceController.text.trim()) : null,
      rentalUnit: isRental ? _rentalUnit : null,
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
          final isSuccess = state.actionMessage == 'item_published';
          final message = switch (state.actionMessage) {
            'item_published' => l10n.actionItemPublished,
            'publish_failed' => l10n.actionPublishFailed,
            _ => state.actionMessage ?? '',
          };
          final displayMessage = state.errorMessage != null
              ? '$message: ${state.errorMessage}'
              : message;
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
      child: PopScope(
        canPop: !_hasUnsavedChanges,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            AdaptiveDialogs.showConfirmDialog(
              context: context,
              title: context.l10n.commonDiscardChanges,
              content: context.l10n.commonDiscardChangesMessage,
              confirmText: context.l10n.commonDiscard,
              isDestructive: true,
            ).then((confirmed) {
              if (confirmed == true && context.mounted) Navigator.of(context).pop();
            });
          }
        },
        child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.fleaMarketPublishItem),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 商品图片
                SectionCard(
                  label: context.l10n.fleaMarketProductImages,
                  child: _buildImagePicker(),
                ),

                // 商品标题
                SectionCard(
                  label: context.l10n.fleaMarketProductTitle,
                  isRequired: true,
                  child: TextFormField(
                    controller: _titleController,
                    maxLength: 100,
                    decoration: InputDecoration(
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
                ),

                // 商品描述
                SectionCard(
                  label: context.l10n.fleaMarketDescOptional,
                  child: TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
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
                ),

                // 类型 & 币种
                SectionCard(
                  label: context.l10n.fleaMarketListingTypeSale,
                  isRequired: true,
                  child: Column(
                    children: [
                      // 出售/出租切换
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'sale',
                              icon: const Icon(Icons.sell_outlined, size: 18),
                              label: Text(context.l10n.fleaMarketListingTypeSale),
                            ),
                            ButtonSegment(
                              value: 'rental',
                              icon: const Icon(Icons.handshake_outlined, size: 18),
                              label: Text(context.l10n.fleaMarketListingTypeRental),
                            ),
                          ],
                          selected: {_listingType},
                          onSelectionChanged: (s) => setState(() => _listingType = s.first),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // 币种选择
                      CurrencySelector(
                        selected: _selectedCurrency,
                        onChanged: (v) => setState(() => _selectedCurrency = v),
                      ),
                    ],
                  ),
                ),

                // 价格
                SectionCard(
                  label: context.l10n.fleaMarketPrice,
                  isRequired: true,
                  child: _listingType == 'sale'
                      ? TextFormField(
                          controller: _priceController,
                          decoration: InputDecoration(
                            hintText: '0.00',
                            prefixIcon: const Icon(Icons.attach_money),
                            prefixText: '${Helpers.currencySymbolFor(_selectedCurrency)} ',
                            border: OutlineInputBorder(
                              borderRadius: AppRadius.allMedium,
                            ),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (_listingType != 'sale') return null;
                            if (value == null || value.trim().isEmpty) {
                              return context.l10n.fleaMarketPriceRequired;
                            }
                            final price = double.tryParse(value.trim());
                            if (price == null || price < 0) {
                              return context.l10n.fleaMarketInvalidPrice;
                            }
                            return null;
                          },
                        )
                      : Column(
                          children: [
                            // 押金
                            TextFormField(
                              controller: _depositController,
                              decoration: InputDecoration(
                                labelText: context.l10n.fleaMarketDeposit,
                                hintText: '0.00',
                                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                                prefixText: '${Helpers.currencySymbolFor(_selectedCurrency)} ',
                                border: OutlineInputBorder(
                                  borderRadius: AppRadius.allMedium,
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                                if (_listingType != 'rental') return null;
                                if (value == null || value.trim().isEmpty) {
                                  return context.l10n.fleaMarketPriceRequired;
                                }
                                final deposit = double.tryParse(value.trim());
                                if (deposit == null || deposit <= 0) {
                                  return context.l10n.fleaMarketInvalidPrice;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            // 租金
                            TextFormField(
                              controller: _rentalPriceController,
                              decoration: InputDecoration(
                                labelText: context.l10n.fleaMarketRentalPrice,
                                hintText: '0.00',
                                prefixIcon: const Icon(Icons.payments_outlined),
                                prefixText: '${Helpers.currencySymbolFor(_selectedCurrency)} ',
                                border: OutlineInputBorder(
                                  borderRadius: AppRadius.allMedium,
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(decimal: true),
                              validator: (value) {
                                if (_listingType != 'rental') return null;
                                if (value == null || value.trim().isEmpty) {
                                  return context.l10n.fleaMarketPriceRequired;
                                }
                                final rentalPrice = double.tryParse(value.trim());
                                if (rentalPrice == null || rentalPrice <= 0) {
                                  return context.l10n.fleaMarketInvalidPrice;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            // 租期单位
                            AppSelectField<String>(
                              value: _rentalUnit,
                              hint: context.l10n.fleaMarketRentalUnit,
                              sheetTitle: context.l10n.fleaMarketRentalUnit,
                              prefixIcon: Icons.schedule,
                              clearable: false,
                              options: [
                                SelectOption(value: 'day', label: context.l10n.fleaMarketRentalUnitDay),
                                SelectOption(value: 'week', label: context.l10n.fleaMarketRentalUnitWeek),
                                SelectOption(value: 'month', label: context.l10n.fleaMarketRentalUnitMonth),
                              ],
                              onChanged: (v) => setState(() => _rentalUnit = v ?? 'day'),
                            ),
                          ],
                        ),
                ),

                // 分类
                SectionCard(
                  label: context.l10n.fleaMarketCategoryLabel,
                  child: AppSelectField<String>(
                    value: _selectedCategory,
                    hint: context.l10n.fleaMarketSelectCategory,
                    sheetTitle: context.l10n.fleaMarketCategoryLabel,
                    prefixIcon: Icons.category_outlined,
                    options: _getCategories(context)
                        .map((category) => SelectOption(
                              value: category.$1,
                              label: category.$2,
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                  ),
                ),

                // 位置
                SectionCard(
                  label: context.l10n.fleaMarketLocationOptional,
                  child: LocationInputField(
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
                ),

                const SizedBox(height: 20),

                // 提交按钮
                BlocBuilder<FleaMarketBloc, FleaMarketState>(
                  buildWhen: (prev, curr) =>
                      prev.isSubmitting != curr.isSubmitting,
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
      ),
    );
  }

  Widget _buildImagePicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const imageSize = 100.0;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        // 已选图片
        ..._selectedImages.asMap().entries.map((entry) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CrossPlatformImage(
                  xFile: entry.value,
                  width: imageSize,
                  height: imageSize,
                ),
              ),
              // 序号角标
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${entry.key + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -8,
                right: -8,
                child: ImageRemoveButton(
                  onTap: () => _removeImage(entry.key),
                ),
              ),
            ],
          );
        }),

        // 添加按钮
        if (_selectedImages.length < 5)
          Semantics(
            button: true,
            label: 'Upload image',
            child: GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: imageSize,
                height: imageSize,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : AppColors.textTertiaryLight.withValues(alpha: 0.4),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 30,
                      color: isDark ? Colors.white54 : AppColors.textTertiaryLight,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.commonImageCount(_selectedImages.length, 5),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white38 : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
