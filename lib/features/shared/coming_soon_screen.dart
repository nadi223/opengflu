import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../home/data/home_providers.dart';

/// شاشة مؤقتة للأقسام التي تُبنى في المراحل القادمة.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(context.tr('coming_soon'), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

/// صفحة منصة مؤقتة: الاسم من القاعدة، والشبكة الفعلية للإعلانات في المرحلة 2.
class PlatformPlaceholderScreen extends ConsumerWidget {
  const PlatformPlaceholderScreen({super.key, required this.platformKey});

  final String platformKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platforms = ref.watch(platformsProvider).value?.data ?? const [];
    String? name;
    for (final p in platforms) {
      if (p.key == platformKey) name = p.nameAr;
    }
    return ComingSoonScreen(title: name ?? context.tr('platforms'));
  }
}
