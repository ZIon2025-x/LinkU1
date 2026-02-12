import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'cross_platform_image_stub.dart'
    if (dart.library.io) 'cross_platform_image_io.dart' as img_impl;

/// Cross-platform image widget that works on both mobile and web.
///
/// On mobile: Uses Image.file for efficient rendering.
/// On web: Uses Image.memory with bytes from XFile.
class CrossPlatformImage extends StatefulWidget {
  const CrossPlatformImage({
    super.key,
    required this.xFile,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final XFile xFile;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  State<CrossPlatformImage> createState() => _CrossPlatformImageState();
}

class _CrossPlatformImageState extends State<CrossPlatformImage> {
  Uint8List? _bytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _loadBytes();
    }
  }

  @override
  void didUpdateWidget(CrossPlatformImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kIsWeb && oldWidget.xFile.path != widget.xFile.path) {
      _loadBytes();
    }
  }

  Future<void> _loadBytes() async {
    if (_loading) return;
    _loading = true;
    try {
      final bytes = await widget.xFile.readAsBytes();
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      if (_bytes != null) {
        return Image.memory(
          _bytes!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
        );
      }
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // Mobile: use Image.file via conditional import
    return img_impl.buildFileImage(
      widget.xFile.path,
      widget.width,
      widget.height,
      widget.fit,
    );
  }
}
