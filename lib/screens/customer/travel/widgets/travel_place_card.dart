import 'package:flutter/material.dart';

import '../../../../model/travel_place.dart';

class TravelPlaceCard extends StatelessWidget {
  const TravelPlaceCard({
    super.key,
    required this.place,
    required this.onTap,
    this.onSaveTap,
    this.saved = false,
  });

  final TravelPlaceModel place;
  final VoidCallback onTap;
  final VoidCallback? onSaveTap;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final image = place.primaryImage.trim();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD7E5E7)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.045),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (image.isEmpty)
                        const ColoredBox(
                          color: Color(0xFFF0F7F6),
                          child: Icon(
                            Icons.terrain_rounded,
                            color: Color(0xFF087F8C),
                            size: 44,
                          ),
                        )
                      else
                        Image.network(
                          image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) {
                            return const ColoredBox(
                              color: Color(0xFFF0F7F6),
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: Color(0xFF087F8C),
                              ),
                            );
                          },
                        ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: _ImageBadge(
                          icon: Icons.category_outlined,
                          label: place.category.label,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton.filledTonal(
                          tooltip: saved ? 'Bỏ lưu' : 'Lưu địa điểm',
                          onPressed: onSaveTap,
                          icon: Icon(
                            saved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF102326),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 17,
                          color: Color(0xFF087F8C),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            place.fullAddress.isEmpty
                                ? place.province
                                : place.fullAddress,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF647A7D),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _InfoPill(
                          icon: Icons.star_rounded,
                          label: place.rating <= 0
                              ? 'Chưa đánh giá'
                              : '${place.rating.toStringAsFixed(1)} (${place.reviewCount})',
                          color: const Color(0xFFE76F51),
                        ),
                        const SizedBox(width: 8),
                        if (place.ticketPrice > 0)
                          _InfoPill(
                            icon: Icons.confirmation_number_outlined,
                            label: '${place.ticketPrice.round()}đ',
                            color: const Color(0xFF087F8C),
                          )
                        else
                          const _InfoPill(
                            icon: Icons.confirmation_number_outlined,
                            label: 'Miễn phí',
                            color: Color(0xFF087F8C),
                          ),
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
        color: Colors.black.withOpacity(0.42),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
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
    return Flexible(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withOpacity(0.11),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
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