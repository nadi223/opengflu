import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../connectivity/connectivity_provider.dart';
import '../l10n/strings.dart';

/// شريط تنبيه عام عند انقطاع الاتصال، بلا أي تفاصيل تقنية.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityProvider).value ?? true;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        if (!online)
          Semantics(
            liveRegion: true,
            child: Material(
              color: scheme.error,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 12,
                  ),
                  child: Center(
                    child: Text(
                      context.tr('offline_banner'),
                      style: TextStyle(color: scheme.onError),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: !online,
            child: child,
          ),
        ),
      ],
    );
  }
}
