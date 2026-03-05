// Web-only: 注册 iframe 用于嵌入 PDF
// 非 Web 平台使用 pdf_web_view_factory_stub.dart

import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;

import 'package:flutter/widgets.dart';

String registerPdfIframe(String url) {
  final viewType = 'pdf-iframe-${url.hashCode}';
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
      return iframe;
    },
  );
  return viewType;
}

Widget buildPdfWebView(String viewType) {
  return HtmlElementView(viewType: viewType);
}
