import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../data/home_providers.dart';

/// يظهر فقط عند وجود مزاد live. الوجهة: منصة المزادات (is_auction_platform) من القاعدة.
class LiveAuctionsBanner extends ConsumerWidget {
  const LiveAuctionsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveAuctionsProvider).value ?? 0;
    if (live == 0) return const SizedBox.shrink();

    final platforms = ref.watch(platformsProvider).value?.data ?? const [];
    final auctionKeys = [
      for (final p in platforms)
        if (p.isAuctionPlatform) p.key,
    ];
    final target = auctionKeys.isEmpty
        ? '/soon?title=${Uri.encodeComponent(context.tr('live_auctions'))}'
        : '/platform/${auctionKeys.first}';

    return Semantics(
      button: true,
      label: context.tr('live_auctions'),
      child: Material(
        color: const Color(0xFFB3261E),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push(target),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('live_auctions'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_left, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
