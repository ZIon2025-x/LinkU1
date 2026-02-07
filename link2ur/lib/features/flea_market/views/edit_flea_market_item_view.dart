import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/async_image_view.dart';
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

  final int itemId;
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

  final int itemId;
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

  String _selectedCategory = '';
  List<String> _existingImageUrls = [];
  final List<XFile> _newImages = [];
  final List<String> _uploadedUrls = [];

  final _categories = [
    'Electronics', 'Clothing', 'Furniture', 'Books',
    'Sports', 'Beauty', 'Other',
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
    _selectedCategory = widget.item.category ?? '';
    _existingImageUrls = List<String>.from(widget.item.images);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final maxNew = 5 - _existingImageUrls.length - _newImages.length;
    if (maxNew <= 0) return;

    final picked = await picker.pickMultiImage(
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (picked.isNotEmpty) {
      setState(() {
        _newImages.addAll(picked.take(maxNew));
      });
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
    if (_titleController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.fleaMarketFillRequired),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final bloc = context.read<FleaMarketBloc>();

    // Upload new images first
    _uploadedUrls.clear();
    for (final image in _newImages) {
      final bytes = await image.readAsBytes();
      bloc.add(FleaMarketUploadImage(
        imageBytes: bytes,
        filename: image.name,
      ));
      // Wait for upload to complete
      await bloc.stream.firstWhere(
        (state) => !state.isUploadingImage,
      );
      if (bloc.state.uploadedImageUrl != null) {
        _uploadedUrls.add(bloc.state.uploadedImageUrl!);
      } else if (bloc.state.errorMessage != null) {
        // Upload failed, stop
        return;
      }
    }

    final allImages = [..._existingImageUrls, ..._uploadedUrls];

    // Update item
    bloc.add(FleaMarketUpdateItem(
      itemId: widget.itemId,
      title: _titleController.text,
      description: _descriptionController.text,
      price: double.tryParse(_priceController.text) ?? 0,
      category: _selectedCategory,
      images: allImages,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final totalImages = _existingImageUrls.length + _newImages.length;

    return BlocListener<FleaMarketBloc, FleaMarketState>(
      listener: (context, state) {
        if (state.actionMessage == '商品更新成功') {
          Navigator.of(context).pop(true);
        } else if (state.errorMessage != null && state.actionMessage == null) {
          // Show error for upload/update failures
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: BlocBuilder<FleaMarketBloc, FleaMarketState>(
        builder: (context, state) {
          final isLoading = state.isSubmitting || state.isUploadingImage;
          final errorMessage = state.errorMessage;

          return Scaffold(
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
                  _buildDropdown(
                    label: l10n.fleaMarketCategory,
                    value: _selectedCategory.isEmpty ? null : _selectedCategory,
                    items: _categories,
                  ),
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
                  _buildTextField(
                    controller: _priceController,
                    label: l10n.fleaMarketPrice,
                    hint: '0.00',
                    prefix: '£',
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
                                fit: BoxFit.cover,
                              ),
                              onRemove: () => _removeExistingImage(url),
                            )),
                        // 新选图片
                        ..._newImages.asMap().entries.map((entry) =>
                            _buildImageTile(
                              child: Image.file(
                                File(entry.value.path),
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                              ),
                              onRemove: () => _removeNewImage(entry.key),
                            )),
                        // 添加按钮
                        if (totalImages < 5)
                          GestureDetector(
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
                                  style: BorderStyle.solid,
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

  Widget _buildDropdown({
    required String label,
    String? value,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          items: items
              .map((item) =>
                  DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
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
        ],
      ),
    );
  }
}
