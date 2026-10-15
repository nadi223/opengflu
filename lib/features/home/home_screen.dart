import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import 'data/home_providers.dart';
import 'widgets/app_drawer.dart';
import 'widgets/exchange_rates_bar.dart';
import 'widgets/latest_listings_strip.dart';
import 'widgets/live_auctions_banner.dart';
import 'widgets/platforms_grid.dart';
import 'widgets/social_links_row.dart';
import 'widgets/sponsors_ticker.dart';

/// الرئيسية الحية: كل قسم يُقرأ من القاعدة، وعند انقطاع الاتصال يُعرض آخر كاش.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(platformsProvider)
      ..invalidate(sponsorsProvider)
      ..invalidate(ratesProvider)
      ..invalidate(socialLinksProvider)
      ..invalidate(latestListingsProvider)
      ..invalidate(liveAuctionsProvider)
      ..invalidate(appConfigProvider);
    await Future<void>.delayed(const Duration(milliseconds: 600));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('app_name')),
        actions: [
          IconButton(
            tooltip: context.tr('settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: const [
            SponsorsTicker(),
            SizedBox(height: 16),
            ExchangeRatesBar(),
            SizedBox(height: 16),
            LiveAuctionsBanner(),
            SizedBox(height: 16),
            LatestListingsStrip(),
            SizedBox(height: 20),
            PlatformsGrid(),
            SizedBox(height: 20),
            SocialLinksRow(),
          ],
        ),
      ),
    );
  }
}
