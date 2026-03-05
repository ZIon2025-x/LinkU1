// Stub for non-web platforms — never called at runtime

import 'package:flutter/widgets.dart';

String registerPdfIframe(String url) {
  throw UnsupportedError('PDF iframe is only supported on web');
}

Widget buildPdfWebView(String viewType) {
  throw UnsupportedError('PDF iframe is only supported on web');
}
