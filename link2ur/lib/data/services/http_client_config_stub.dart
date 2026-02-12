import 'package:dio/dio.dart';

/// Stub implementation — used as fallback when neither dart:io nor dart:html is available.
/// This should never actually be called at runtime.
void configureHttpClient(Dio dio) {
  // No-op: default Dio adapter is used
}
