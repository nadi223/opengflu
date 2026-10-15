import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/storage/local_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // في الإنتاج لا تُطبع الأخطاء ولا تُعرض تفاصيلها (قد تحوي معلومات تقنية).
  FlutterError.onError = (details) {
    if (kDebugMode) FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (kDebugMode) debugPrint('$error');
    return true;
  };
  if (kReleaseMode) {
    ErrorWidget.builder = (details) => const SizedBox.shrink();
  }

  final prefs = await SharedPreferences.getInstance();

  var ready = Env.isConfigured;
  if (ready) {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      );
    } catch (_) {
      ready = false;
    }
  }

  runApp(
    ProviderScope(
      // لا إعادة محاولة تلقائية: نعرض الكاش أو رسالة واضحة فوراً.
      retry: (retryCount, error) => null,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: ready ? const OpenGateApp() : const _StartupFailed(),
    ),
  );
}

class _StartupFailed extends StatelessWidget {
  const _StartupFailed();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: Center(child: Text('تعذّر تشغيل التطبيق، حاول لاحقاً')),
        ),
      ),
    );
  }
}
