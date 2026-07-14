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

  @override
  Widget build(BuildContext context) {
    final images = widget.place.images;
    final colors = Theme.of(context).colorScheme;

    return SliverAppBar(
      expandedHeight: 330,
      pinned: true,
      stretch: true,
      backgroundColor: colors.surface,
      foregroundColor: Colors.white,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: CircleAvatar(
            backgroundColor: Colors.black.withValues(alpha: 0.35),
            child: IconButton(
              tooltip: widget.isSaved ? 'Bỏ lưu' : 'Lưu địa điểm',
              onPressed: widget.onToggleSaved,
              icon: Icon(
                widget.isSaved ? Icons.favorite : Icons.favorite_border,
                color: widget.isSaved ? const Color(0xFFFF6B6B) : Colors.white,
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (images.isEmpty)
              _Placeholder(category: widget.place.category)
            else
              PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: (value) => setState(() => _index = value),
                itemBuilder: (context, index) {
                  return Image.network(
                    images[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return _Placeholder(category: widget.place.category);
                    },
                  );
                },
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x66000000),
                    Color(0x11000000),
                    Color(0xCC000000),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryBadge(category: widget.place.category),
                  const SizedBox(height: 10),
                  Text(
                    widget.place.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        color: Colors.white70,
                        size: 17,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          widget.place.fullAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (images.length > 1)
              Positioned(
                right: 18,
                bottom: 24,
                child: _ImageCounter(
                  current: _index + 1,
                  total: images.length,
                ),
              ),
          ],
        ),
      ),
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
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconOf(category), size: 15, color: const Color(0xFF087F8C)),
            const SizedBox(width: 6),
            Text(
              _labelOf(category),
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

  static String _labelOf(TravelPlaceCategory category) {
    return switch (category) {
      TravelPlaceCategory.beach => 'Biển đảo',
      TravelPlaceCategory.mountain => 'Núi rừng',
      TravelPlaceCategory.culture => 'Văn hóa',
      TravelPlaceCategory.food => 'Ẩm thực',
      TravelPlaceCategory.entertainment => 'Giải trí',
      TravelPlaceCategory.shopping => 'Mua sắm',
      TravelPlaceCategory.nature => 'Thiên nhiên',
      TravelPlaceCategory.other => 'Khám phá',
    };
  }

  static IconData _iconOf(TravelPlaceCategory category) {
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
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.photo_library_outlined, size: 15, color: Colors.white),
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
          _CategoryBadge._iconOf(category),
          size: 76,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}