import 'package:flutter/material.dart';

import '../errors/app_error.dart';
import '../l10n/strings.dart';

/// خطأ قسم واحد: رسالة عربية عامة بلا تفاصيل تقنية + إعادة محاولة.
class SectionError extends StatelessWidget {
  const SectionError({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.onSurface.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(friendlyMessage(error))),
          TextButton(onPressed: onRetry, child: Text(context.tr('retry'))),
        ],
      ),
    );
  }
}
