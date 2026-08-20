import 'dart:convert';
import 'dart:io';

import 'config.dart';

/// Thrown when the FlowCraft app's control server can't be reached or
/// rejects a request.
class FlowcraftUnreachable implements Exception {
  FlowcraftUnreachable(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Thin HTTP client for the FlowCraft desktop app's local control server.
///
/// The control server binds to 127.0.0.1 only and requires the shared
/// token written by the app to `~/.flowcraft/control.token` for any
/// state-changing request.
class FlowcraftBridgeClient {
  FlowcraftBridgeClient({HttpClient? httpClient})
      : _client = httpClient ?? HttpClient();

  final HttpClient _client;

  Future<bool> isReachable() async {
    try {
      final request = await _client
          .getUrl(FlowcraftConfig.controlUri('/health'))
          .timeout(const Duration(seconds: 2));
      final response =
          await request.close().timeout(const Duration(seconds: 2));
      await response.drain<void>();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> draw({
    required List<Map<String, dynamic>> elements,
    String mode = 'add',
  }) {
    return _post('/draw', {'mode': mode, 'elements': elements});
  }

  Future<Map<String, dynamic>> clear() => _post('/clear', const {});

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final token = FlowcraftConfig.readToken();
    if (token == null) {
      throw FlowcraftUnreachable(
        'No FlowCraft control token found at '
        '${FlowcraftConfig.tokenFile.path}. Is the FlowCraft desktop app '
        'running at least once on this machine?',
      );
    }

    final HttpClientResponse response;
    try {
      final request = await _client
          .postUrl(FlowcraftConfig.controlUri(path))
          .timeout(const Duration(seconds: 3));
      request.headers
        ..set('X-Flowcraft-Token', token)
        ..contentType = ContentType.json;
      request.write(jsonEncode(body));
      response = await request.close().timeout(const Duration(seconds: 5));
    } on SocketException catch (e) {
      throw FlowcraftUnreachable(
        'Could not reach the FlowCraft app on '
        '127.0.0.1:${FlowcraftConfig.controlPort}. Make sure it is '
        'running. ($e)',
      );
    }

    final responseBody = await response.transform(utf8.decoder).join();
    final decoded = responseBody.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(responseBody) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw FlowcraftUnreachable(
        'FlowCraft app returned ${response.statusCode}: '
        '${decoded['error'] ?? responseBody}',
      );
    }
    return decoded;
  }

  void close() => _client.close(force: true);
}
