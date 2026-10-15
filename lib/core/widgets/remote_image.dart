import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class RemoteImage extends StatelessWidget {
  const RemoteImage({super.key, required this.url, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (context, _) =>
          ColoredBox(color: scheme.onSurface.withValues(alpha: 0.08)),
      errorWidget: (context, _, error) => ColoredBox(
        color: scheme.onSurface.withValues(alpha: 0.08),
        child: const Center(child: Icon(Icons.image_not_supported_outlined)),
      ),
    );
  }
}
