import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SectionSkeletonLoader extends StatefulWidget {
  final double cardWidth;
  final double cardHeight;
  final int count;

  const SectionSkeletonLoader({
    super.key,
    this.cardWidth = 195.0,
    this.cardHeight = 230.0,
    this.count = 3,
  });

  @override
  State<SectionSkeletonLoader> createState() => _SectionSkeletonLoaderState();
}

class _SectionSkeletonLoaderState extends State<SectionSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _opacityAnimation = Tween<double>(begin: 0.4, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return SizedBox(
      height: widget.cardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.count,
        itemBuilder: (context, index) {
          final card = Container(
            width: widget.cardWidth,
            height: widget.cardHeight,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.hairlineSoft, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top placeholder box
                Container(
                  height: widget.cardHeight * 0.52,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: widget.cardWidth * 0.8,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: widget.cardWidth * 0.5,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 10,
                        width: widget.cardWidth * 0.35,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          if (disableAnimations) return card;

          return FadeTransition(
            opacity: _opacityAnimation,
            child: card,
          );
        },
      ),
    );
  }
}

