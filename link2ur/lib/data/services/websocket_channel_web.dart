import 'package:web_socket_channel/web_socket_channel.dart';

/// Web implementation — uses browser's native WebSocket.
/// Note: Browser WebSocket does not support custom headers,
/// so auth token is passed via query parameter.
WebSocketChannel createWebSocketChannel(Uri uri, Map<String, dynamic> headers) {
  return WebSocketChannel.connect(uri);
}
