import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/home_providers.dart';

class SponsorsTicker extends ConsumerWidget {
  const SponsorsTicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(sponsorsProvider)
        .when(
          data: (result) => result.data.isEmpty
              ? const SizedBox.shrink()
              : _Marquee(items: [for (final s in result.data) s.textAr]),
          loading: () => const SkeletonBox(height: 40, radius: 10),
          // قسم غير حرج: يُخفى عند الفشل.
          error: (error, stack) => const SizedBox.shrink(),
        );
  }
}

class _Marquee extends StatefulWidget {
  const _Marquee({required this.items});

  final List<String> items;

  @override
  State<_Marquee> createState() => _MarqueeState();
}

class _MarqueeState extends State<_Marquee> {
  final ScrollController _controller = ScrollController();
  Timer? _timer;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (_reduceMotion || !_controller.hasClients) return;
      _controller.jumpTo(_controller.offset + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    final joined = widget.items.join('، ');

    return Semantics(
      container: true,
      label: joined,
      child: ExcludeSemantics(
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          ),
          child: _reduceMotion
              ? Center(
                  child: Text(
                    joined,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.gold),
                  ),
                )
              : ListView.builder(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, i) => Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '✦  ${widget.items[i % widget.items.length]}',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
