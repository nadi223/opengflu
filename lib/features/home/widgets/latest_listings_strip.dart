import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/widgets/remote_image.dart';
import '../../../core/widgets/section_error.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/home_models.dart';
import '../data/home_providers.dart';

class LatestListingsStrip extends ConsumerWidget {
  const LatestListingsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 1.8).toDouble();
    final height = 215.0 * scale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('latest_listings'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        ref
            .watch(latestListingsProvider)
            .when(
              data: (result) {
                if (result.data.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(context.tr('no_listings')),
                  );
                }
                return SizedBox(
                  height: height,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: result.data.length,
                    separatorBuilder: (context, i) => const SizedBox(width: 12),
                    itemBuilder: (context, i) =>
                        _ListingCard(listing: result.data[i], seed: i),
                  ),
                );
              },
              loading: () => SizedBox(
                height: height,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  separatorBuilder: (context, i) => const SizedBox(width: 12),
                  itemBuilder: (context, i) =>
                      SkeletonBox(width: 168, height: height),
                ),
              ),
              error: (error, stack) => SectionError(
                error: error,
                onRetry: () => ref.invalidate(latestListingsProvider),
              ),
            ),
      ],
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({required this.listing, required this.seed});

  final LatestListing listing;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isNew = isNewListing(listing.publishedAt, listing.createdAt);
    final price = listing.price;

    return SizedBox(
      width: 168,
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/listing/${listing.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RotatingImage(urls: listing.imageUrls, seed: seed),
                    if (isNew)
                      PositionedDirectional(
                        top: 6,
                        start: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB3261E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            context.tr('new_badge'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price == null
                          ? context.tr('price_on_request')
                          : formatMoney(price, listing.currency),
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (listing.city != null)
                      Text(
                        listing.city!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// صور متقلبة تلقائياً بتلاشٍ ناعم؛ تتوقف عند تفعيل "تقليل الحركة".
class RotatingImage extends StatefulWidget {
  const RotatingImage({super.key, required this.urls, this.seed = 0});

  final List<String> urls;
  final int seed;

  @override
  State<RotatingImage> createState() => _RotatingImageState();
}

class _RotatingImageState extends State<RotatingImage> {
  Timer? _timer;
  int _index = 0;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    if (widget.urls.length > 1) {
      // فارق بسيط بين البطاقات كي لا تتبدل كلها في اللحظة نفسها.
      final period = Duration(milliseconds: 3000 + (widget.seed % 5) * 250);
      _timer = Timer.periodic(period, (_) {
        if (!mounted || _reduceMotion) return;
        setState(() => _index = (_index + 1) % widget.urls.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (widget.urls.isEmpty) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
        child: const Center(child: Icon(Icons.image_outlined)),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      child: KeyedSubtree(
        key: ValueKey<int>(_index),
        child: RemoteImage(url: widget.urls[_index]),
      ),
    );
  }
}
