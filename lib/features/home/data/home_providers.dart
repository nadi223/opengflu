import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_store.dart';
import '../../../core/supabase/supabase_providers.dart';
import 'home_models.dart';

/// كل المنصات من القاعدة: لا أسماء مكتوبة في الكود. المخفية لا تظهر.
final platformsProvider = FutureProvider<CachedResult<List<PlatformInfo>>>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return cachedFetch<List<PlatformInfo>>(
    store: ref.watch(localStoreProvider),
    key: 'cache.platforms',
    fetch: () async => await client
        .from('platforms')
        .select(
          'id,key,name_ar,name_en,description_ar,icon,banner_url,sort_order,is_auction_platform',
        )
        .eq('is_visible', true)
        .order('sort_order'),
    parse: (json) => parseRows(json, PlatformInfo.fromJson),
  );
});

final sponsorsProvider = FutureProvider<CachedResult<List<Sponsor>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return cachedFetch<List<Sponsor>>(
    store: ref.watch(localStoreProvider),
    key: 'cache.sponsors',
    fetch: () async => await client
        .from('featured_sponsors')
        .select('id,text_ar,sort_order')
        .eq('is_visible', true)
        .order('sort_order'),
    parse: (json) => parseRows(json, Sponsor.fromJson),
  );
});

final ratesProvider = FutureProvider<CachedResult<List<ExchangeRate>>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return cachedFetch<List<ExchangeRate>>(
    store: ref.watch(localStoreProvider),
    key: 'cache.rates',
    fetch: () async => await client
        .from('exchange_rates')
        .select('city,currency,rate_to_yer,updated_at'),
    parse: (json) => parseRows(json, ExchangeRate.fromJson),
  );
});

/// يظهر الحساب فقط إن فعّله المالك وكانت قيمته غير فارغة.
final socialLinksProvider = FutureProvider<CachedResult<List<SocialLink>>>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return cachedFetch<List<SocialLink>>(
    store: ref.watch(localStoreProvider),
    key: 'cache.social',
    fetch: () async => await client
        .from('social_links')
        .select('key,label_ar,value,sort_order')
        .eq('is_visible', true)
        .neq('value', '')
        .order('sort_order'),
    parse: (json) => parseRows(json, SocialLink.fromJson),
  );
});

final latestListingsProvider =
    FutureProvider<CachedResult<List<LatestListing>>>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return cachedFetch<List<LatestListing>>(
        store: ref.watch(localStoreProvider),
        key: 'cache.latest',
        fetch: () async => await client
            .from('listings')
            .select(
              'id,title,price,currency,city,published_at,created_at,listing_images(url,sort_order)',
            )
            .eq('status', 'published')
            .order('published_at', ascending: false)
            .limit(10),
        parse: (json) => parseRows(json, LatestListing.fromJson),
      );
    });

/// عدد المزادات المباشرة الآن (0 = لا يظهر البانر).
final liveAuctionsProvider = FutureProvider<int>((ref) async {
  try {
    final rows = await ref
        .watch(supabaseClientProvider)
        .from('auctions')
        .select('id')
        .eq('status', 'live')
        .gt('ends_at', DateTime.now().toUtc().toIso8601String())
        .limit(50);
    return rows.length;
  } catch (_) {
    return 0;
  }
});

final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  try {
    final result = await cachedFetch<Map<String, dynamic>>(
      store: ref.watch(localStoreProvider),
      key: 'cache.app_config',
      fetch: () async => await client.from('app_config').select('key,value'),
      parse: (json) {
        final map = <String, dynamic>{};
        for (final row in json as List) {
          final r = row as Map;
          map[r['key'] as String] = r['value'];
        }
        return map;
      },
    );
    return AppConfig(result.data);
  } catch (_) {
    return const AppConfig({});
  }
});
