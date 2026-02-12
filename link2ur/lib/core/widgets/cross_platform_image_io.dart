import 'dart:io';
import 'package:flutter/material.dart';

/// IO implementation — uses Image.file for efficient file rendering.
Widget buildFileImage(String path, double? width, double? height, BoxFit fit) {
  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
  );
}
