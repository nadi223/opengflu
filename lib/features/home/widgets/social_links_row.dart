import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/strings.dart';
import '../data/home_providers.dart';
import '../data/social_url.dart';

const Map<String, IconData> _icons = {
  'instagram': Icons.camera_alt_outlined,
  'x': Icons.alternate_email,
  'snapchat': Icons.chat_bubble_outline,
  'tiktok': Icons.music_note_outlined,
  'whatsapp': Icons.phone_in_talk_outlined,
  'website': Icons.language,
};

/// لا يظهر إلا إذا فعّله المالك وكانت قيمته غير فارغة.
class SocialLinksRow extends ConsumerWidget {
  const SocialLinksRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(socialLinksProvider).value?.data ?? const [];
    final usable = [
      for (final l in links)
        if (socialUri(l.key, l.value) != null) l,
    ];
    if (usable.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('follow_us'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final l in usable)
              ActionChip(
                avatar: Icon(_icons[l.key] ?? Icons.link, size: 18),
                label: Text(l.labelAr),
                onPressed: () {
                  final uri = socialUri(l.key, l.value);
                  if (uri != null) {
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
          ],
        ),
      ],
    );
  }
}
