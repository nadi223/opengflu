import 'package:supabase_flutter/supabase_flutter.dart';

const String kOfflineMessage = 'لا يوجد اتصال بالإنترنت حالياً';
const String kGenericMessage = 'حدث خطأ غير متوقع، حاول مرة أخرى';

final RegExp _arabicLetters = RegExp(r'[\u0600-\u06FF]');

/// أخطاء الشبكة تُكتشف باسم النوع كي لا نعتمد على dart:io أو حزمة http مباشرة.
bool isNetworkError(Object error) {
  final type = error.runtimeType.toString();
  return type.contains('SocketException') ||
      type.contains('ClientException') ||
      type.contains('HandshakeException') ||
      type.contains('TimeoutException') ||
      type.contains('AuthRetryableFetchException') ||
      type.contains('WebSocketChannelException');
}

/// يحوّل أي خطأ إلى رسالة عربية آمنة للعرض.
/// لا يُعرض نص الخطأ الخام أبداً (قد يحوي رابط الخادم أو تفاصيل القاعدة).
/// الاستثناء الوحيد: رسائل raise exception العربية من القاعدة (الكود P0001)،
/// وتُعرض كما هي دون إعادة صياغة.
String friendlyMessage(Object error) {
  if (isNetworkError(error)) return kOfflineMessage;

  if (error is PostgrestException) {
    if (error.code == 'P0001' && _arabicLetters.hasMatch(error.message)) {
      return error.message;
    }
    return kGenericMessage;
  }

  if (error is AuthException) return _authMessage(error);

  return kGenericMessage;
}

String _authMessage(AuthException error) {
  final text = error.message.toLowerCase();
  if (error.statusCode == '429' ||
      text.contains('rate limit') ||
      text.contains('too many')) {
    return 'محاولات كثيرة، انتظر قليلاً ثم أعد المحاولة';
  }
  if (text.contains('invalid login credentials')) {
    return 'بيانات الدخول غير صحيحة';
  }
  if (text.contains('email not confirmed')) {
    return 'يرجى تأكيد بريدك الإلكتروني أولاً';
  }
  if (text.contains('already registered') || text.contains('already exists')) {
    return 'هذا الحساب مسجّل مسبقاً';
  }
  if (text.contains('password') &&
      (text.contains('at least') || text.contains('weak'))) {
    return 'كلمة المرور ضعيفة، استخدم 8 أحرف على الأقل';
  }
  if (text.contains('otp') || text.contains('token')) {
    return 'رمز التحقق غير صحيح أو منتهي';
  }
  if (text.contains('invalid format') || text.contains('validate email')) {
    return 'صيغة البريد الإلكتروني غير صحيحة';
  }
  return kGenericMessage;
}

/// تنظيف البريد من المسافات والمحارف غير المرئية قبل الإرسال
/// (سبب خطأ "invalid format" في نسخة أندرويد القديمة).
String cleanEmail(String input) {
  return input
      .replaceAll(RegExp(r'[\s\u200B-\u200F\u202A-\u202E\u2060\uFEFF]'), '')
      .toLowerCase();
}
