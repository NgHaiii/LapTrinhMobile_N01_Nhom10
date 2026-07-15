import 'package:flutter/material.dart';

import '../../../../model/travel_place.dart';

class TravelPlaceCard extends StatelessWidget {
  const TravelPlaceCard({
    super.key,
    required this.place,
    required this.onTap,
    this.onSaveTap,
    this.onBookTap,
    this.saved = false,
  });

  final TravelPlaceModel place;
  final VoidCallback onTap;
  final VoidCallback? onSaveTap;
  final VoidCallback? onBookTap;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final image = place.primaryImage.trim();

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF087F8C).withValues(alpha: 0.08),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image.isEmpty)
                      const _ImagePlaceholder()
                    else
                      Image.asset(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) {
                          return const _ImagePlaceholder();
                        },
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.12),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.64),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _ImageBadge(
                        icon: _categoryIcon(place.category),
                        label: place.category.label,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: IconButton.filledTonal(
                        tooltip: saved ? 'Bỏ lưu' : 'Lưu địa điểm',
                        onPressed: onSaveTap,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.92),
                          foregroundColor: saved
                              ? const Color(0xFFE76F51)
                              : const Color(0xFF087F8C),
                        ),
                        icon: Icon(
                          saved
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right: 14,
                      bottom: 13,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                color: Colors.white,
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${place.district}, ${place.province}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.38,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _InfoPill(
                          icon: Icons.star_rounded,
                          label: place.rating <= 0
                              ? 'Chưa đánh giá'
                              : '${place.rating.toStringAsFixed(1)} (${place.reviewCount})',
                          color: const Color(0xFFE76F51),
                        ),
                        _InfoPill(
                          icon: Icons.confirmation_number_outlined,
                          label: place.isFree
                              ? 'Miễn phí'
                              : '${place.ticketPrice.round()}đ',
                          color: const Color(0xFF087F8C),
                        ),
                        _InfoPill(
                          icon: Icons.photo_library_outlined,
                          label: '${place.images.length} ảnh',
                          color: const Color(0xFF3A86FF),
                        ),
                      ],
                    ),
                    const SizedBox(height: 13),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: onTap,
                            icon: const Icon(Icons.explore_outlined),
                            label: const Text('Xem chi tiết'),
                          ),
                        ),
                        if (onBookTap != null) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: onBookTap,
                              icon: const Icon(Icons.hotel_rounded),
                              label: const Text('Đặt phòng'),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                            tooltip: 'Xem địa điểm',
                            onPressed: onTap,
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFDDF8F5),
      child: Center(
        child: Icon(
          Icons.landscape_rounded,
          color: Color(0xFF087F8C),
          size: 58,
        ),
      ),
    );
  }
}

class _ImageBadge extends StatelessWidget {
  const _ImageBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _categoryIcon(TravelPlaceCategory category) {
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