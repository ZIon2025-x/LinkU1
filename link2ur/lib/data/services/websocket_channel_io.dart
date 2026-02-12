import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

/// IO (mobile/desktop) implementation — uses dart:io WebSocket.
WebSocketChannel createWebSocketChannel(Uri uri, Map<String, dynamic> headers) {
  return IOWebSocketChannel.connect(
    uri,
    headers: headers,
  );
}
