import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// 桌面 Web 使用 ClampingScrollPhysics，贴近前端/浏览器原生滚动（无回弹），更流畅
class AppScrollBehavior extends ScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    if (kIsWeb) {
      return const ClampingScrollPhysics();
    }
    return super.getScrollPhysics(context);
  }
}
