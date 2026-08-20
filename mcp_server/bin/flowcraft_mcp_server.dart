import 'dart:io' as io;

import 'package:dart_mcp/stdio.dart';
import 'package:flowcraft_mcp_server/src/flowcraft_mcp_server.dart';

void main() {
  FlowcraftMcpServer(stdioChannel(input: io.stdin, output: io.stdout));
}
