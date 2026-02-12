import 'package:dio/dio.dart';
import 'package:dio/browser.dart';

/// Web implementation — uses browser's native fetch/XMLHttpRequest.
void configureHttpClient(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter();
}
