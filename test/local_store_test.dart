import 'package:flutter_test/flutter_test.dart';
import 'package:open_gate/core/storage/local_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('cachedFetch caches and falls back to cache offline', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());

    final fresh = await cachedFetch<int>(
      store: store,
      key: 'k',
      fetch: () async => 5,
      parse: (json) => json as int,
    );
    expect(fresh.data, 5);
    expect(fresh.fromCache, false);

    final cached = await cachedFetch<int>(
      store: store,
      key: 'k',
      fetch: () async => throw Exception('offline'),
      parse: (json) => json as int,
    );
    expect(cached.data, 5);
    expect(cached.fromCache, true);
  });
}
