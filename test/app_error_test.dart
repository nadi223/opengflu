import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_gate/core/errors/app_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('friendlyMessage', () {
    test('network errors map to the offline message', () {
      expect(friendlyMessage(TimeoutException('x')), kOfflineMessage);
    });

    test('arabic P0001 database message is shown as is', () {
      const message = 'هذا المزاد غير مباشر حالياً';
      final error = PostgrestException(message: message, code: 'P0001');
      expect(friendlyMessage(error), message);
    });

    test('technical database errors are never shown', () {
      final error = PostgrestException(
        message: 'permission denied for table profiles',
        code: '42501',
      );
      expect(friendlyMessage(error), kGenericMessage);
    });

    test('english P0001 message is not leaked', () {
      final error = PostgrestException(message: 'boom', code: 'P0001');
      expect(friendlyMessage(error), kGenericMessage);
    });

    test('auth invalid credentials is translated', () {
      expect(
        friendlyMessage(AuthException('Invalid login credentials')),
        'بيانات الدخول غير صحيحة',
      );
    });
  });

  group('cleanEmail', () {
    test('removes spaces and invisible characters', () {
      expect(cleanEmail(' A\u200Bb@Example.com\u200F '), 'ab@example.com');
    });
  });
}
