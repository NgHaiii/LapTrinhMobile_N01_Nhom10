import 'package:flutter/material.dart';

import '../../../model/hotel.dart';
import 'image_carousel.dart';

class CustomerHotelCard extends StatelessWidget {
  const CustomerHotelCard({
    super.key,
    required this.hotel,
    required this.onTap,
  });

  final HotelModel hotel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasPrice =
        hotel.effectiveMinFirstHourPrice > 0;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomerImageCarousel(
                    images: hotel.images,
                    fallbackIcon:
                        Icons.apartment_outlined,
                  ),

                  // Chỉ giữ loại hình lưu trú trên ảnh.
                  Positioned(
                    left: 12,
                    top: 12,
                    child: _ImageBadge(
                      icon: Icons.hotel_outlined,
                      label: hotel.category,
                    ),
                  ),

                  if (hotel.images.length > 1)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: _ImageBadge(
                        icon:
                            Icons.photo_library_outlined,
                        label:
                            '${hotel.images.length} ảnh',
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // Ngôi sao chuyển xuống cạnh tên.
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          hotel.name,
                          maxLines: 2,
                          overflow:
                              TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight.w900,
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _RatingBadge(
                        rating: hotel.rating,
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          hotel.fullAddress.isEmpty
                              ? 'Chưa cập nhật địa chỉ'
                              : hotel.fullAddress,
                          maxLines: 2,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (hotel.amenities.isNotEmpty) ...[
                    const SizedBox(height: 11),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        ...hotel.amenities
                            .take(3)
                            .map(
                              (amenity) =>
                                  _AmenityChip(
                                    label: amenity,
                                  ),
                            ),
                        if (hotel.amenities.length > 3)
                          _AmenityChip(
                            label:
                                '+${hotel.amenities.length - 3}',
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: hasPrice
                            ? Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    'Giá giờ đầu từ',
                                    style: TextStyle(
                                      color: colors
                                          .onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _money(
                                      hotel
                                          .effectiveMinFirstHourPrice,
                                    ),
                                    style: TextStyle(
                                      color:
                                          colors.primary,
                                      fontSize: 19,
                                      fontWeight:
                                          FontWeight.w900,
                                    ),
                                  ),
                                  if (hotel
                                          .effectiveMinAdditionalHourPrice >
                                      0)
                                    Text(
                                      'Giờ tiếp theo từ '
                                      '${_money(hotel.effectiveMinAdditionalHourPrice)}/giờ',
                                      style: TextStyle(
                                        color: colors
                                            .onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              )
                            : Text(
                                'Chưa cập nhật giá',
                                style: TextStyle(
                                  color: colors.error,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Xem khách sạn',
                        onPressed: onTap,
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
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
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({
    required this.rating,
  });

  final double rating;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              size: 17,
              color: colors.onTertiaryContainer,
            ),
            const SizedBox(width: 3),
            Text(
              rating > 0
                  ? rating.toStringAsFixed(1)
                  : 'Mới',
              style: TextStyle(
                color: colors.onTertiaryContainer,
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
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 15,
            ),
            const SizedBox(width: 5),
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

class _AmenityChip extends StatelessWidget {
  const _AmenityChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 14,
              color: colors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _money(double value) {
  final raw = value.round().toString();

  return '${raw.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  )}đ';
}