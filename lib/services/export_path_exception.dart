/// Why an export to a caller-chosen path was refused, phrased for a human
/// (and for an MCP client that must be able to correct its next call).
///
/// Platform-neutral so both `ExportFileSink` implementations — and callers
/// that never import `dart:io` — share the one type.
class ExportPathException implements Exception {
  const ExportPathException(this.message);

  final String message;

  @override
  String toString() => message;
}
