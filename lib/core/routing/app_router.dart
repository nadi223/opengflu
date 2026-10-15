import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/auth/verify_phone_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shared/coming_soon_screen.dart';
import '../../features/welcome/welcome_screen.dart';
import '../l10n/strings.dart';
import '../storage/local_store.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final seenWelcome = prefs.getBool(kWelcomeSeenKey) ?? false;

  return GoRouter(
    initialLocation: seenWelcome ? '/' : '/welcome',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            LoginScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            RegisterScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/verify-phone',
        builder: (context, state) => VerifyPhoneScreen(
          phone: state.uri.queryParameters['phone'] ?? '',
          from: state.uri.queryParameters['from'],
        ),
      ),
      GoRoute(
        path: '/platform/:key',
        builder: (context, state) => PlatformPlaceholderScreen(
          platformKey: state.pathParameters['key'] ?? '',
        ),
      ),
      GoRoute(
        path: '/listing/:id',
        builder: (context, state) => const ComingSoonScreen(title: ''),
      ),
      GoRoute(
        path: '/soon',
        builder: (context, state) =>
            ComingSoonScreen(title: state.uri.queryParameters['title'] ?? ''),
      ),
    ],
    // لا نعرض تفاصيل الخطأ للمستخدم أبداً.
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('not_found')),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/'),
              child: Text(context.tr('back_home')),
            ),
          ],
        ),
      ),
    ),
  );
});
