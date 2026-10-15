import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_error.dart';
import '../../core/supabase/supabase_providers.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<void> signInWithEmail(String email, String password) async {
    await _client.auth.signInWithPassword(
      email: cleanEmail(email),
      password: password,
    );
  }

  Future<void> signInWithPhone(String e164Phone, String password) async {
    await _client.auth.signInWithPassword(phone: e164Phone, password: password);
  }

  /// true = بدأت الجلسة فوراً، false = يحتاج المستخدم تأكيد بريده أولاً.
  /// الهاتف اختياري، ويُرسل في metadata ليحفظه الـ trigger handle_new_user.
  /// لا إدراج يدوي في profiles أبداً: الصف يُنشأ بالـ trigger.
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? e164Phone,
  }) async {
    final res = await _client.auth.signUp(
      email: cleanEmail(email),
      password: password,
      data: {
        'full_name': fullName.trim(),
        if (e164Phone != null) 'phone': e164Phone,
      },
    );
    return res.session != null;
  }

  /// true = بدأت الجلسة فوراً، false = يحتاج رمز SMS (verifyPhone).
  Future<bool> signUpWithPhone({
    required String e164Phone,
    required String password,
    required String fullName,
  }) async {
    final res = await _client.auth.signUp(
      phone: e164Phone,
      password: password,
      data: {'full_name': fullName.trim()},
    );
    return res.session != null;
  }

  Future<void> verifyPhone(String e164Phone, String code) async {
    await _client.auth.verifyOTP(
      phone: e164Phone,
      token: code.trim(),
      type: OtpType.sms,
    );
  }

  Future<void> resendPhoneCode(String e164Phone) async {
    await _client.auth.resend(type: OtpType.sms, phone: e164Phone);
  }

  Future<void> signOut() => _client.auth.signOut();
}
