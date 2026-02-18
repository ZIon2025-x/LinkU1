import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// QR 码生成器
/// 对齐 iOS QRCodeGenerator.swift
/// 支持生成 QR 码 Widget 和图片数据
class QRCodeGenerator {
  QRCodeGenerator._();

  /// 生成 QR 码 Widget
  /// [data] 二维码内容
  /// [size] 尺寸（默认 200）
  /// [foregroundColor] 前景色（默认黑色）
  /// [backgroundColor] 背景色（默认白色）
  /// [errorCorrectionLevel] 纠错级别（默认 M）
  static Widget generateWidget({
    required String data,
    double size = 200,
    Color foregroundColor = Colors.black,
    Color backgroundColor = Colors.white,
    int errorCorrectionLevel = QrErrorCorrectLevel.M,
    EdgeInsets padding = const EdgeInsets.all(10),
    Widget? embeddedImage,
    double? embeddedImageSize,
  }) {
    return QrImageView(
      data: data,
      size: size,
      errorCorrectionLevel: errorCorrectionLevel,
      eyeStyle: QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: foregroundColor,
      ),
      dataModuleStyle: QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: foregroundColor,
      ),
      backgroundColor: backgroundColor,
      padding: padding,
      embeddedImage: embeddedImage != null ? null : null,
      embeddedImageStyle: embeddedImageSize != null
          ? QrEmbeddedImageStyle(
              size: Size(embeddedImageSize, embeddedImageSize),
            )
          : null,
    );
  }

  /// 生成带自定义颜色的 QR 码 Widget
  static Widget generateColored({
    required String data,
    double size = 200,
    Color foregroundColor = Colors.black,
    Color backgroundColor = Colors.white,
  }) {
    return generateWidget(
      data: data,
      size: size,
      foregroundColor: foregroundColor,
      backgroundColor: backgroundColor,
    );
  }

  /// 生成可分享的 QR 码容器（带标题和说明）
  static Widget generateShareCard({
    required String data,
    required String title,
    String? subtitle,
    double qrSize = 180,
    Color foregroundColor = Colors.black,
    Color backgroundColor = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 16),
          generateWidget(
            data: data,
            size: qrSize,
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor,
          ),
          const SizedBox(height: 12),
          Text(
            '扫描二维码',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
