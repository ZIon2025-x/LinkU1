
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/adaptive_dialogs.dart';
import '../../../core/widgets/app_select_sheet.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/cross_platform_image.dart';
import '../../../data/models/flea_market.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../bloc/flea_market_bloc.dart';

/// 编辑跳蚤市场商品页
/// 参考iOS EditFleaMarketItemView.swift
class EditFleaMarketItemView extends StatelessWidget {
  const EditFleaMarketItemView({
    super.key,
    required this.itemId,
    required this.item,
  });

  final String itemId;
  final FleaMarketItem item;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FleaMarketBloc(
        fleaMarketRepository: context.read<FleaMarketRepository>(),
      ),
      child: _EditFleaMarketItemViewContent(itemId: itemId, item: item),
    );
  }
}

class _EditFleaMarketItemViewContent extends StatefulWidget {
  const _EditFleaMarketItemViewContent({
    required this.itemId,
    required this.item,
  });

  final String itemId;
  final FleaMarketItem item;

  @override
  State<_EditFleaMarketItemViewContent> createState() =>
      _EditFleaMarketItemViewContentState();
}

class _EditFleaMarketItemViewContentState
    extends State<_EditFleaMarketItemViewContent> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _locationController;
  late final TextEditingController _depositController;
  late final TextEditingController _rentalPriceController;

  String _selectedCategory = '';
  late String _rentalUnit;
  List<String> _existingImageUrls = [];
  final List<XFile> _newImages = [];

  bool get _hasUnsavedChanges {
    final item = widget.item;
    if (_titleController.text != item.title ||
        _descriptionController.text != (item.description ?? '') ||
        _locationController.text != (item.location ?? 'Online') ||
        _selectedCategory != (item.category ?? '') ||
        _existingImageUrls.length != item.images.length ||
        _newImages.isNotEmpty) {
      return true;
    }
    if (item.isRental) {
      return _depositController.text != (item.deposit?.toString() ?? '') ||
          _rentalPriceController.text != (item.rentalPrice?.toString() ?? '') ||
          _rentalUnit != (item.rentalUnit ?? 'day');
    }
    return _priceController.text != item.price.toString();
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
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.title);
    _descriptionController =
        TextEditingController(text: widget.item.description ?? '');
    _priceController =
        TextEditingController(text: widget.item.price.toString());
    _locationController =
        TextEditingController(text: widget.item.location ?? 'Online');
    _depositController = TextEditingController(
        text: widget.item.deposit != null ? widget.item.deposit.toString() : '');
    _rentalPriceController = TextEditingController(
        text: widget.item.rentalPrice != null ? widget.item.rentalPrice.toString() : '');
    _rentalUnit = widget.item.rentalUnit ?? 'day';
    _selectedCategory = widget.item.category ?? '';
    _existingImageUrls = List<String>.from(widget.item.images);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _depositController.dispose();
    _rentalPriceController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final maxNew = 5 - _existingImageUrls.length - _newImages.length;
    if (maxNew <= 0) return;

    try {
      final picked = await picker.pickMultiImage(
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (!mounted) return;
      if (picked.isNotEmpty) {
        setState(() {
          _newImages.addAll(picked.take(maxNew));
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
          content: Text('${context.l10n.fleaMarketImageSelectFailed}: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _removeExistingImage(String url) {
    setState(() {
      _existingImageUrls.remove(url);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImages.removeAt(index);
    });
  }

  Future<void> _saveChanges() async {
    final title = _titleController.text.trim();
    final isRental = widget.item.isRental;

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.fleaMarketFillRequired),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (title.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.fleaMarketTitleMinLength),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Validate price fields based on listing type
    final double price;
    double? deposit;
    double? rentalPrice;
    String? rentalUnit;

    if (isRental) {
      final depositVal = double.tryParse(_depositController.text.trim());
      final rentalPriceVal = double.tryParse(_rentalPriceController.text.trim());
      if (depositVal == null || depositVal <= 0 || rentalPriceVal == null || rentalPriceVal <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.fleaMarketInvalidPrice),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      price = rentalPriceVal;
      deposit = depositVal;
      rentalPrice = rentalPriceVal;
      rentalUnit = _rentalUnit;
    } else {
      final priceText = _priceController.text.trim();
      final priceVal = double.tryParse(priceText);
      if (priceVal == null || priceVal < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.fleaMarketInvalidPrice),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      price = priceVal;
    }

    final bloc = context.read<FleaMarketBloc>();
    final newImagesToUpload = <(Uint8List, String)>[];
    for (final image in _newImages) {
      final bytes = await image.readAsBytes();
      final name = image.name.trim().isNotEmpty ? image.name : 'image.jpg';
      newImagesToUpload.add((bytes, name));
    }
    if (!mounted) return;

    // 使用 bloc 内串行「上传 + 更新」，避免 stream 竞态导致 PUT 未发送
    bloc.add(FleaMarketUploadImagesAndUpdateItem(
      itemId: widget.itemId,
      title: title,
      description: _descriptionController.text.trim(),
      price: price,
      category: _selectedCategory,
      existingImageUrls: _existingImageUrls,
      newImagesToUpload: newImagesToUpload,
      deposit: deposit,
      rentalPrice: rentalPrice,
      rentalUnit: rentalUnit,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final totalImages = _existingImageUrls.length + _newImages.length;

    return BlocListener<FleaMarketBloc, FleaMarketState>(
      listenWhen: (previous, current) =>
          current.actionMessage != previous.actionMessage ||
          current.errorMessage != previous.errorMessage,
      listener: (context, state) {
        if (state.actionMessage == 'item_updated') {
          Navigator.of(context).pop(true);
          return;
        }
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
              ? '$message: ${context.localizeError(state.errorMessage)}'
              : message;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(displayMessage),
              backgroundColor: state.actionMessage == 'item_updated'
                  ? AppColors.success
                  : AppColors.error,
            ),
          );
        } else if (state.errorMessage != null) {
          // Show error for upload/update failures
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.localizeError(state.errorMessage)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: BlocBuilder<FleaMarketBloc, FleaMarketState>(
        buildWhen: (prev, curr) =>
            prev.isSubmitting != curr.isSubmitting ||
            prev.isUploadingImage != curr.isUploadingImage ||
            prev.errorMessage != curr.errorMessage,
        builder: (context, state) {
          final isLoading = state.isSubmitting || state.isUploadingImage;
          final errorMessage = state.errorMessage;

          return PopScope(
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
              title: Text(l10n.fleaMarketEditItem),
            ),
            body: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              // 基本信息卡片
              _buildSection(
                title: l10n.fleaMarketProductInfo,
                icon: Icons.shopping_bag,
                children: [
                  _buildTextField(
                    controller: _titleController,
                    label: l10n.fleaMarketProductTitle,
                    hint: l10n.fleaMarketProductTitleHint,
                    isRequired: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildCategoryDropdown(context),
                  const SizedBox(height: AppSpacing.md),
                  _buildTextField(
                    controller: _descriptionController,
                    label: l10n.fleaMarketDescription,
                    hint: l10n.fleaMarketDescriptionHint,
                    maxLines: 5,
                    isRequired: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // 价格与交易
              _buildSection(
                title: l10n.fleaMarketPriceAndTrade,
                icon: Icons.monetization_on,
                children: [
                  if (widget.item.isRental) ...[
                    // 租赁模式：押金 + 租金 + 租期单位
                    _buildTextField(
                      controller: _depositController,
                      label: l10n.fleaMarketDeposit,
                      hint: '0.00',
                      prefix: Helpers.currencySymbolFor(widget.item.currency),
                      keyboardType: TextInputType.number,
                      isRequired: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildTextField(
                      controller: _rentalPriceController,
                      label: l10n.fleaMarketRentalPrice,
                      hint: '0.00',
                      prefix: Helpers.currencySymbolFor(widget.item.currency),
                      keyboardType: TextInputType.number,
                      isRequired: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(l10n.fleaMarketRentalUnit,
                                style: const TextStyle(
                                    fontSize: 14, color: AppColors.textSecondary)),
                            const Text(' *', style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        AppSelectField<String>(
                          value: _rentalUnit,
                          hint: l10n.fleaMarketRentalUnit,
                          sheetTitle: l10n.fleaMarketRentalUnit,
                          clearable: false,
                          options: [
                            SelectOption(value: 'day', label: l10n.fleaMarketRentalUnitDay),
                            SelectOption(value: 'week', label: l10n.fleaMarketRentalUnitWeek),
                            SelectOption(value: 'month', label: l10n.fleaMarketRentalUnitMonth),
                          ],
                          onChanged: (v) => setState(() => _rentalUnit = v ?? 'day'),
                        ),
                      ],
                    ),
                  ] else
                    _buildTextField(
                      controller: _priceController,
                      label: l10n.fleaMarketPrice,
                      hint: '0.00',
                      prefix: Helpers.currencySymbolFor(widget.item.currency),
                      keyboardType: TextInputType.number,
                      isRequired: true,
                    ),
                  const SizedBox(height: AppSpacing.md),
                  _buildTextField(
                    controller: _locationController,
                    label: l10n.fleaMarketLocation,
                    hint: 'Online',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // 图片
              _buildSection(
                title: l10n.fleaMarketProductImages,
                icon: Icons.photo_library,
                trailing: Text(
                  '$totalImages/5',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: [
                  SizedBox(
                    height: 100,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // 已有图片
                        ..._existingImageUrls.map((url) => _buildImageTile(
                              child: AsyncImageView(
                                imageUrl: url,
                                width: 90,
                                height: 90,
                              ),
                              onRemove: () => _removeExistingImage(url),
                            )),
                        // 新选图片
                        ..._newImages.asMap().entries.map((entry) =>
                            _buildImageTile(
                              child: CrossPlatformImage(
                                xFile: entry.value,
                                width: 90,
                                height: 90,
                              ),
                              onRemove: () => _removeNewImage(entry.key),
                            )),
                        // 添加按钮
                        if (totalImages < 5)
                          Semantics(
                            button: true,
                            label: 'Upload image',
                            child: GestureDetector(
                            onTap: _pickImages,
                            child: Container(
                              width: 90,
                              height: 90,
                              margin:
                                  const EdgeInsets.only(right: AppSpacing.sm),
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.medium),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                ),
                                color: AppColors.background,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_photo_alternate,
                                      color: AppColors.primary, size: 28),
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.fleaMarketAddImage,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
                    const SizedBox(height: AppSpacing.lg),

                    // 错误提示
                    if (errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.error, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage,
                                style: const TextStyle(
                                    color: AppColors.error, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: AppSpacing.xl),

                    // 保存按钮
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.large),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(l10n.fleaMarketSaveChanges,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ),
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              if (trailing != null) ...[const Spacer(), trailing],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? prefix,
    int maxLines = 1,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
            if (isRequired)
              const Text(' *', style: TextStyle(color: AppColors.error)),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  /// 分类下拉：与创建页一致用本地化 (key, label)；若当前值不在列表中则补一项，避免 assertion
  Widget _buildCategoryDropdown(BuildContext context) {
    final l10n = context.l10n;
    final categories = _getCategories(context);
    final keys = categories.map((e) => e.$1).toList();
    final value = _selectedCategory.isEmpty ? null : _selectedCategory;
    final options = categories
        .map((e) => SelectOption(value: e.$1, label: e.$2))
        .toList();
    if (value != null && !keys.contains(value)) {
      options.add(SelectOption(value: value, label: value));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.fleaMarketCategory,
            style:
                const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        AppSelectField<String>(
          value: value,
          hint: l10n.fleaMarketSelectCategory,
          sheetTitle: l10n.fleaMarketCategory,
          prefixIcon: Icons.category_outlined,
          options: options,
          onChanged: (val) {
            if (val != null) setState(() => _selectedCategory = val);
          },
        ),
      ],
    );
  }

  Widget _buildImageTile({
    required Widget child,
    required VoidCallback onRemove,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            child: SizedBox(width: 90, height: 90, child: child),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Semantics(
              button: true,
              label: 'Remove image',
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child:
                      const Icon(Icons.close, color: Colors.white, size: 14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
