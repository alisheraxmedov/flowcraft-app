import 'package:flowcraft/services/mcp_http_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('constantTimeEquals', () {
    const token = 'YWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXowMTIzNDU2Nzg5';

    test('accepts the real token', () {
      expect(constantTimeEquals(token, token), isTrue);
      // A fresh string, so this cannot be passing on identity alone.
      expect(
        constantTimeEquals(String.fromCharCodes(token.codeUnits), token),
        isTrue,
      );
    });

    test('rejects wrong candidates whatever their length', () {
      for (final wrong in [
        '', // empty
        'x', // far too short
        token.substring(0, token.length - 1), // a correct prefix
        '$token=', // the token plus a byte
        '${token.substring(0, token.length - 1)}X', // one byte off at the end
        'X${token.substring(1)}', // one byte off at the start
        'x' * 4096, // far too long
      ]) {
        expect(
          constantTimeEquals(wrong, token),
          isFalse,
          reason: 'accepted a ${wrong.length}-byte candidate',
        );
      }
    });

    test('is symmetric and handles two empty strings', () {
      expect(constantTimeEquals('', ''), isTrue);
      expect(constantTimeEquals('a', ''), isFalse);
      expect(constantTimeEquals('', 'a'), isFalse);
    });

    test('compares bytes, not code units', () {
      // Same length in characters, different length in UTF-8.
      expect(constantTimeEquals('é', 'e'), isFalse);
    });
  });

  group('body limits', () {
    test('the cap is generous enough for a real diagram', () {
      // A wordy element serializes to a few hundred bytes; the cap has to
      // clear a full-size draw call by a wide margin or it becomes a bug
      // report instead of a guardrail.
      expect(maxRequestBodyBytes, greaterThan(10000 * 300));
    });

    test('the exception names the limit and nothing else', () {
      expect(
        const RequestBodyTooLargeException().toString(),
        'request body exceeds the $maxRequestBodyBytes byte limit',
      );
    });
  });
}
