import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_screen.dart';
import '../../features/settings/settings_screen.dart';
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
