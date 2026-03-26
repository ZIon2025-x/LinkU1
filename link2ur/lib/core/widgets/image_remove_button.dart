import 'package:flutter/material.dart';

import '../design/app_colors.dart';

/// Unified image remove button used across all publish/edit pages.
///
/// Visual size is 22×22 (red circle with white ×), but the tap target
/// is expanded to 36×36 with transparent padding for easier interaction.
/// Designed to be placed inside a [Positioned] at `top: -8, right: -8`
/// with [Stack.clipBehavior] = [Clip.none].
class ImageRemoveButton extends StatelessWidget {
  const ImageRemoveButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: 'Remove image',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                  width: 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: const Icon(Icons.close, size: 13, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
