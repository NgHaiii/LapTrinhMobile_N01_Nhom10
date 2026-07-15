import 'package:flutter/material.dart';

import '../../../../model/travel_place.dart';

class TravelPlaceHero extends StatefulWidget {
  const TravelPlaceHero({
    super.key,
    required this.place,
    required this.isSaved,
    required this.onToggleSaved,
  });

  final TravelPlaceModel place;
  final bool isSaved;
  final VoidCallback onToggleSaved;

  @override
  State<TravelPlaceHero> createState() => _TravelPlaceHeroState();
}

class _TravelPlaceHeroState extends State<TravelPlaceHero> {
  final PageController _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToImage(int index) {
    final images = widget.place.images;
    if (images.isEmpty) return;

    final target = index.clamp(0, images.length - 1);

    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _previousImage() {
    if (_index <= 0) return;
    _goToImage(_index - 1);
  }

  void _nextImage() {
    final images = widget.place.images;
    if (_index >= images.length - 1) return;
    _goToImage(_index + 1);
  }

  void _handleSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity < -120) {
      _nextImage();
      return;
    }

    if (velocity > 120) {
      _previousImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.place.images;
    final colors = Theme.of(context).colorScheme;
    final hasManyImages = images.length > 1;

    return SliverAppBar(
      expandedHeight: 430,
      pinned: true,
      stretch: true,
      backgroundColor: colors.surface,
      foregroundColor: Colors.white,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: IconButton.filledTonal(
            tooltip: widget.isSaved ? 'Bỏ lưu' : 'Lưu địa điểm',
            onPressed: widget.onToggleSaved,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.94),
              foregroundColor: widget.isSaved
                  ? const Color(0xFFE76F51)
                  : const Color(0xFF087F8C),
            ),
            icon: Icon(
              widget.isSaved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: hasManyImages ? _handleSwipe : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (images.isEmpty)
                _Placeholder(category: widget.place.category)
              else
                PageView.builder(
                  controller: _pageController,
                  itemCount: images.length,
                  physics: const PageScrollPhysics(),
                  pageSnapping: true,
                  onPageChanged: (value) {
                    if (!mounted) return;
                    setState(() => _index = value);
                  },
                  itemBuilder: (context, index) {
                    return Image.asset(
                      images[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return _Placeholder(category: widget.place.category);
                      },
                    );
                  },
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.30),
                      Colors.black.withValues(alpha: 0.04),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                  ),
                ),
              ),
              if (hasManyImages) ...[
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _ArrowButton(
                      icon: Icons.chevron_left_rounded,
                      enabled: _index > 0,
                      onTap: _previousImage,
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _ArrowButton(
                      icon: Icons.chevron_right_rounded,
                      enabled: _index < images.length - 1,
                      onTap: _nextImage,
                    ),
                  ),
                ),
              ],
              Positioned(
                left: 18,
                right: 18,
                bottom: 34,
                child: IgnorePointer(
                  ignoring: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CategoryBadge(category: widget.place.category),
                      const SizedBox(height: 12),
                      Text(
                        widget.place.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 31,
                          height: 1.02,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            color: Colors.white,
                            size: 17,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              widget.place.fullAddress.isEmpty
                                  ? widget.place.province
                                  : widget.place.fullAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          Expanded(
                            child: _Dots(
                              total: images.length,
                              index: _index,
                            ),
                          ),
                          if (hasManyImages)
                            _ImageCounter(
                              current: _index + 1,
                              total: images.length,
                            ),
                        ],
                      ),
                      if (hasManyImages) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Vuốt ngang trên ảnh để xem thêm',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: enabled ? 1 : 0.25,
      child: Material(
        color: Colors.black.withValues(alpha: 0.34),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onTap : null,
          child: SizedBox.square(
            dimension: 42,
            child: Icon(
              icon,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({
    required this.total,
    required this.index,
  });

  final int total;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: List.generate(total, (itemIndex) {
        final selected = itemIndex == index;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: selected ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.46),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final TravelPlaceCategory category;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconOf(category), size: 15, color: const Color(0xFF087F8C)),
            const SizedBox(width: 6),
            Text(
              category.label,
              style: const TextStyle(
                color: Color(0xFF123335),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageCounter extends StatelessWidget {
  const _ImageCounter({
    required this.current,
    required this.total,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 15,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            Text(
              '$current/$total',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.category});

  final TravelPlaceCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF087F8C),
      child: Center(
        child: Icon(
          _iconOf(category),
          size: 82,
          color: Colors.white.withValues(alpha: 0.92),
        ),
      ),
    );
  }
}

IconData _iconOf(TravelPlaceCategory category) {
  return switch (category) {
    TravelPlaceCategory.beach => Icons.beach_access_outlined,
    TravelPlaceCategory.mountain => Icons.landscape_outlined,
    TravelPlaceCategory.culture => Icons.temple_buddhist_outlined,
    TravelPlaceCategory.food => Icons.restaurant_outlined,
    TravelPlaceCategory.entertainment => Icons.attractions_outlined,
    TravelPlaceCategory.shopping => Icons.local_mall_outlined,
    TravelPlaceCategory.nature => Icons.park_outlined,
    TravelPlaceCategory.other => Icons.explore_outlined,
  };
}