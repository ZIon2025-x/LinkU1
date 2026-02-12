import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

/// IO (mobile/desktop) implementation — configures connection pooling and keep-alive.
void configureHttpClient(Dio dio) {
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient()
        ..maxConnectionsPerHost = 6
        ..idleTimeout = const Duration(seconds: 15)
        ..connectionTimeout = const Duration(seconds: 10);
      return client;
    },
  );
}
