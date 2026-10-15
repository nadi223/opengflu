import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/formatters.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/widgets/section_error.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/home_models.dart';
import '../data/home_providers.dart';

/// سعران منفصلان: صنعاء وعدن (قيد في القاعدة: city in sanaa/aden).
class ExchangeRatesBar extends ConsumerWidget {
  const ExchangeRatesBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(ratesProvider)
        .when(
          data: (result) {
            final rates = result.data;
            if (rates.isEmpty) return const SizedBox.shrink();
            DateTime? latest;
            for (final r in rates) {
              final t = r.updatedAt;
              if (t != null && (latest == null || t.isAfter(latest)))
                latest = t;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('rates_title'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _CityCard(
                          title: context.tr('city_sanaa'),
                          rates: rates.where((r) => r.city == 'sanaa').toList(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CityCard(
                          title: context.tr('city_aden'),
                          rates: rates.where((r) => r.city == 'aden').toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                if (latest != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${context.tr('rates_updated')}: ${formatYemenDateTime(latest)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            );
          },
          loading: () => const SkeletonBox(height: 110),
          error: (error, stack) => SectionError(
            error: error,
            onRetry: () => ref.invalidate(ratesProvider),
          ),
        );
  }
}

class _CityCard extends StatelessWidget {
  const _CityCard({required this.title, required this.rates});

  final String title;
  final List<ExchangeRate> rates;

  num? _rate(String currency) {
    for (final r in rates) {
      if (r.currency == currency) return r.rate;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final usd = _rate('USD');
    final sar = _rate('SAR');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (usd != null)
            _line(
              context,
              context.tr('cur_usd'),
              formatNumber(usd, decimals: 0),
            ),
          if (sar != null)
            _line(
              context,
              context.tr('cur_sar'),
              formatNumber(sar, decimals: 0),
            ),
        ],
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label)),
          const SizedBox(width: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
