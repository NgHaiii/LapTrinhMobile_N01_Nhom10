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

    final images = <String>[...hotel.images];

    if (images.isEmpty && hotel.imageUrl.trim().isNotEmpty) {
      images.add(hotel.imageUrl.trim());
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: CustomerImageCarousel(
              images: images,
              fallbackIcon: Icons.apartment_outlined,
            ),
          ),
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          hotel.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      if (hotel.rating > 0) ...[
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.star_rounded,
                          size: 19,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          hotel.rating.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HotelInfo(
                        icon: Icons.category_outlined,
                        label: hotel.category,
                      ),
                      _HotelInfo(
                        icon: Icons.photo_library_outlined,
                        label: '${images.length} ảnh',
                      ),
                      if (hotel.district.isNotEmpty)
                        _HotelInfo(
                          icon: Icons.map_outlined,
                          label: hotel.district,
                        ),
                    ],
                  ),
                  if (hotel.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 11),
                    Text(
                      hotel.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hotel.minPrice > 0
                              ? 'Từ ${_formatMoney(hotel.minPrice)}/đêm'
                              : 'Xem giá phòng',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.tonalIcon(
                        onPressed: onTap,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 42),
                          fixedSize: null,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.bed_outlined, size: 18),
                        label: const Text('Xem phòng'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HotelInfo extends StatelessWidget {
  const _HotelInfo({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: colors.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatMoney(double value) {
  final raw = value.toStringAsFixed(0);

  final formatted = raw.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );

  return '$formatted đ';
}