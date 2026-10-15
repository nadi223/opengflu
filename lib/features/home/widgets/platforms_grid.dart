import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_error.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/home_models.dart';
import '../data/home_providers.dart';

final RegExp _identifierLike = RegExp(r'^[A-Za-z0-9_\-\.]+$');

class PlatformsGrid extends ConsumerWidget {
  const PlatformsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = (MediaQuery.textScalerOf(context).scale(14) / 14)
        .clamp(1.0, 1.7)
        .toDouble();
    final tileHeight = 132.0 * scale;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('platforms'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        ref
            .watch(platformsProvider)
            .when(
              data: (result) => GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: result.data.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: tileHeight,
                ),
                itemBuilder: (context, i) =>
                    _PlatformTile(platform: result.data[i]),
              ),
              loading: () => GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: List.generate(
                  4,
                  (_) => const SkeletonBox(height: 120),
                ),
              ),
              error: (error, stack) => SectionError(
                error: error,
                onRetry: () => ref.invalidate(platformsProvider),
              ),
            ),
      ],
    );
  }
}

class _PlatformTile extends StatelessWidget {
  const _PlatformTile({required this.platform});

  final PlatformInfo platform;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = platform.icon;
    // الأيقونة نص يحدده المالك (إيموجي مثلاً)؛ إن كانت فارغة أو معرّفاً تقنياً نعرض أول حرف.
    final glyph =
        (icon != null && icon.isNotEmpty && !_identifierLike.hasMatch(icon))
        ? icon
        : (platform.nameAr.isEmpty ? '?' : platform.nameAr.substring(0, 1));

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/platform/${platform.key}'),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.gold.withValues(alpha: 0.18),
                child: Text(glyph, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(height: 8),
              Text(
                platform.nameAr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (platform.descriptionAr != null &&
                  platform.descriptionAr!.isNotEmpty)
                Text(
                  platform.descriptionAr!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
