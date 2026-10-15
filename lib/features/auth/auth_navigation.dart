import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// مسار شاشة الدخول مع وجهة العودة بعد النجاح.
String loginLocation({String? from}) => Uri(
  path: '/login',
  queryParameters: {if (from != null && from.isNotEmpty) 'from': from},
).toString();

String registerLocation({String? from}) => Uri(
  path: '/register',
  queryParameters: {if (from != null && from.isNotEmpty) 'from': from},
).toString();

String verifyPhoneLocation({required String phone, String? from}) => Uri(
  path: '/verify-phone',
  queryParameters: {
    'phone': phone,
    if (from != null && from.isNotEmpty) 'from': from,
  },
).toString();

/// بعد نجاح الدخول: الرئيسية ثم الوجهة المطلوبة (إن وُجدت).
void finishAuth(BuildContext context, String? from) {
  final router = GoRouter.of(context);
  router.go('/');
  if (from != null && from.isNotEmpty) router.push(from);
}
