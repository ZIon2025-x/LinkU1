import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/buttons.dart';
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
  final _locationController = TextEditingController();

  String? _selectedCategory;
  final List<File> _selectedImages = [];
  final _imagePicker = ImagePicker();

  static const _categories = [
    '电子产品',
    '书籍教材',
    '生活用品',
    '服饰鞋包',
    '运动户外',
    '其他',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        setState(() {
          for (final file in pickedFiles) {
            if (_selectedImages.length < 9) {
              _selectedImages.add(File(file.path));
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择图片失败: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入有效价格'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final request = CreateFleaMarketRequest(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      price: price,
      category: _selectedCategory,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      // 图片URL需要先上传，这里传空列表，实际项目中应先上传图片获取URL
      images: [],
    );

    context.read<FleaMarketBloc>().add(FleaMarketCreateItem(request));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FleaMarketBloc, FleaMarketState>(
      listenWhen: (prev, curr) => prev.actionMessage != curr.actionMessage,
      listener: (context, state) {
        if (state.actionMessage != null) {
          final isSuccess = state.actionMessage!.contains('成功');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionMessage!),
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
          title: const Text('发布商品'),
        ),
        body: SingleChildScrollView(
          padding: AppSpacing.allMd,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 商品图片
                const Text(
                  '商品图片',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                AppSpacing.vSm,
                _buildImagePicker(),
                AppSpacing.vLg,

                // 商品标题
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: '商品标题',
                    hintText: '请输入商品标题',
                    prefixIcon: const Icon(Icons.title),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.allMedium,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入商品标题';
                    }
                    if (value.trim().length < 2) {
                      return '标题至少需要2个字符';
                    }
                    return null;
                  },
                ),
                AppSpacing.vMd,

                // 商品描述
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: '商品描述（选填）',
                    hintText: '描述一下你的商品...',
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
                    labelText: '价格',
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
                      return '请输入价格';
                    }
                    final price = double.tryParse(value.trim());
                    if (price == null || price <= 0) {
                      return '请输入有效价格';
                    }
                    return null;
                  },
                ),
                AppSpacing.vMd,

                // 分类
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: '分类',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.allMedium,
                    ),
                  ),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                  hint: const Text('选择分类'),
                ),
                AppSpacing.vMd,

                // 位置
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: '位置（选填）',
                    hintText: '例如：校园北门',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.allMedium,
                    ),
                  ),
                ),
                AppSpacing.vXl,

                // 提交按钮
                BlocBuilder<FleaMarketBloc, FleaMarketState>(
                  builder: (context, state) {
                    return SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        text: '发布商品',
                        onPressed: state.isSubmitting ? null : _submitForm,
                        isLoading: state.isSubmitting,
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
                child: Image.file(
                  entry.value,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
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

        // 添加按钮
        if (_selectedImages.length < 9)
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
                  style: BorderStyle.solid,
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
                    '${_selectedImages.length}/9',
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
