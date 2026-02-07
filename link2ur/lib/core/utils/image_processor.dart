import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'logger.dart';

/// 图片处理工具
/// 对齐 iOS ImageProcessor.swift
/// 提供图片缩放、压缩、裁剪、圆角、圆形、水印等功能
class ImageProcessor {
  ImageProcessor._();

  /// 缩放图片
  /// [imageData] 原始图片数据
  /// [width] 目标宽度
  /// [height] 目标高度
  /// [quality] 输出质量（0-100，默认 100）
  static Future<Uint8List?> resize(
    Uint8List imageData, {
    required int width,
    required int height,
    int quality = 100,
  }) async {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) return null;

      final resized = img.copyResize(
        image,
        width: width,
        height: height,
        interpolation: img.Interpolation.linear,
      );

      return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    } catch (e) {
      AppLogger.error('ImageProcessor: resize failed', e);
      return null;
    }
  }

  /// 压缩图片
  /// [imageData] 原始图片数据
  /// [quality] JPEG 质量（0-100，默认 80）
  /// [maxSizeBytes] 最大文件大小（字节，默认 1MB）
  static Future<Uint8List?> compress(
    Uint8List imageData, {
    int quality = 80,
    int maxSizeBytes = 1024 * 1024,
  }) async {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) return null;

      var currentQuality = quality;
      Uint8List result;

      // 逐步降低质量直到满足大小限制
      do {
        result = Uint8List.fromList(
            img.encodeJpg(image, quality: currentQuality));
        if (result.length <= maxSizeBytes) break;
        currentQuality -= 10;
      } while (currentQuality > 10);

      return result;
    } catch (e) {
      AppLogger.error('ImageProcessor: compress failed', e);
      return null;
    }
  }

  /// 裁剪图片
  /// [imageData] 原始图片数据
  /// [x] 裁剪起始 X 坐标
  /// [y] 裁剪起始 Y 坐标
  /// [width] 裁剪宽度
  /// [height] 裁剪高度
  static Future<Uint8List?> crop(
    Uint8List imageData, {
    required int x,
    required int y,
    required int width,
    required int height,
  }) async {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) return null;

      final cropped = img.copyCrop(
        image,
        x: x,
        y: y,
        width: width,
        height: height,
      );

      return Uint8List.fromList(img.encodePng(cropped));
    } catch (e) {
      AppLogger.error('ImageProcessor: crop failed', e);
      return null;
    }
  }

  /// 添加圆角
  /// [imageData] 原始图片数据
  /// [radius] 圆角半径
  static Future<Uint8List?> roundedCorners(
    Uint8List imageData, {
    required int radius,
  }) async {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) return null;

      // 创建圆角蒙版
      final width = image.width;
      final height = image.height;
      final result = img.Image(width: width, height: height, numChannels: 4);

      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          if (_isInsideRoundedRect(x, y, width, height, radius)) {
            result.setPixel(x, y, image.getPixel(x, y));
          } else {
            result.setPixelRgba(x, y, 0, 0, 0, 0);
          }
        }
      }

      return Uint8List.fromList(img.encodePng(result));
    } catch (e) {
      AppLogger.error('ImageProcessor: roundedCorners failed', e);
      return null;
    }
  }

  /// 裁剪为圆形
  /// [imageData] 原始图片数据
  static Future<Uint8List?> circular(Uint8List imageData) async {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) return null;

      final size =
          image.width < image.height ? image.width : image.height;
      final centerX = image.width ~/ 2;
      final centerY = image.height ~/ 2;
      final radiusSquared = (size ~/ 2) * (size ~/ 2);

      // 先居中裁剪为正方形
      final cropped = img.copyCrop(
        image,
        x: centerX - size ~/ 2,
        y: centerY - size ~/ 2,
        width: size,
        height: size,
      );

      // 应用圆形蒙版
      final result = img.Image(width: size, height: size, numChannels: 4);
      final halfSize = size ~/ 2;

      for (var y = 0; y < size; y++) {
        for (var x = 0; x < size; x++) {
          final dx = x - halfSize;
          final dy = y - halfSize;
          if (dx * dx + dy * dy <= radiusSquared) {
            result.setPixel(x, y, cropped.getPixel(x, y));
          } else {
            result.setPixelRgba(x, y, 0, 0, 0, 0);
          }
        }
      }

      return Uint8List.fromList(img.encodePng(result));
    } catch (e) {
      AppLogger.error('ImageProcessor: circular failed', e);
      return null;
    }
  }

  /// 添加文字水印
  /// [imageData] 原始图片数据
  /// [text] 水印文字
  /// [x] 水印位置 X
  /// [y] 水印位置 Y
  static Future<Uint8List?> addWatermark(
    Uint8List imageData, {
    required String text,
    int x = 10,
    int y = 10,
    int fontSize = 24,
  }) async {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) return null;

      img.drawString(
        image,
        text,
        font: img.arial24,
        x: x,
        y: y,
        color: img.ColorRgba8(255, 255, 255, 128),
      );

      return Uint8List.fromList(img.encodeJpg(image, quality: 95));
    } catch (e) {
      AppLogger.error('ImageProcessor: addWatermark failed', e);
      return null;
    }
  }

  /// 获取图片信息
  static Map<String, dynamic>? getImageInfo(Uint8List imageData) {
    try {
      final image = img.decodeImage(imageData);
      if (image == null) return null;

      return {
        'width': image.width,
        'height': image.height,
        'hasAlpha': image.numChannels == 4,
        'sizeBytes': imageData.length,
      };
    } catch (e) {
      AppLogger.error('ImageProcessor: getImageInfo failed', e);
      return null;
    }
  }

  // ==================== 辅助方法 ====================

  static bool _isInsideRoundedRect(
    int x,
    int y,
    int width,
    int height,
    int radius,
  ) {
    // 四个角的检查
    if (x < radius && y < radius) {
      return _isInsideCircle(x, y, radius, radius, radius);
    }
    if (x >= width - radius && y < radius) {
      return _isInsideCircle(x, y, width - radius - 1, radius, radius);
    }
    if (x < radius && y >= height - radius) {
      return _isInsideCircle(x, y, radius, height - radius - 1, radius);
    }
    if (x >= width - radius && y >= height - radius) {
      return _isInsideCircle(
          x, y, width - radius - 1, height - radius - 1, radius);
    }
    return true;
  }

  static bool _isInsideCircle(
      int x, int y, int centerX, int centerY, int radius) {
    final dx = x - centerX;
    final dy = y - centerY;
    return dx * dx + dy * dy <= radius * radius;
  }
}
