import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kWelcomeSeenKey = 'welcome_seen';

/// يُستبدل في main() بنسخة جاهزة.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

final localStoreProvider = Provider<LocalStore>(
  (ref) => LocalStore(ref.watch(sharedPreferencesProvider)),
);

/// تخزين JSON بسيط للكاش المحلي (المنصات، التصنيفات، الحقول، آخر إعلانات).
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  Object? readJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(String key, Object value) =>
      _prefs.setString(key, jsonEncode(value));
}

class CachedResult<T> {
  const CachedResult(this.data, {required this.fromCache});

  final T data;

  /// true = البيانات من آخر نسخة محفوظة (وضع عدم الاتصال).
  final bool fromCache;
}

/// يجلب من الشبكة ويحفظ النسخة، وعند الفشل يعيد آخر نسخة إن وُجدت.
Future<CachedResult<T>> cachedFetch<T>({
  required LocalStore store,
  required String key,
  required Future<Object> Function() fetch,
  required T Function(Object json) parse,
}) async {
  try {
    final json = await fetch();
    final data = parse(json);
    await store.writeJson(key, json);
    return CachedResult(data, fromCache: false);
  } catch (_) {
    final cached = store.readJson(key);
    if (cached != null) {
      return CachedResult(parse(cached), fromCache: true);
    }
    rethrow;
  }
}
