import 'package:flutter/material.dart';

import '../../../model/room.dart';
import 'image_carousel.dart';

class CustomerRoomCard extends StatelessWidget {
  const CustomerRoomCard({
    super.key,
    required this.room,
    required this.guests,
    required this.booking,
    this.onBook,
  });

  final RoomModel room;
  final int guests;
  final bool booking;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final enoughCapacity = room.maxGuests >= guests;
    final validPrice = room.price > 0;

    final canBook =
        room.isAvailable &&
        enoughCapacity &&
        validPrice &&
        onBook != null &&
        !booking;

    final reason = _disabledReason(room: room, guests: guests);

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: CustomerImageCarousel(
              images: room.images,
              fallbackIcon: Icons.bed_outlined,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${room.type} · Phòng ${room.roomNumber}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _AvailabilityBadge(available: room.isAvailable),
                  ],
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _RoomInfo(
                      icon: Icons.group_outlined,
                      label: 'Tối đa ${room.maxGuests} khách',
                    ),
                    _RoomInfo(
                      icon: Icons.photo_library_outlined,
                      label: '${room.images.length} ảnh',
                    ),
                  ],
                ),
                if (room.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 11),
                  Text(
                    room.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 13),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 360;

                    final priceSection = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          validPrice ? _formatMoney(room.price) : 'Chưa có giá',
                          style: TextStyle(
                            color: validPrice ? colors.primary : colors.error,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (validPrice)
                          Text(
                            'mỗi đêm',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        if (reason != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            reason,
                            style: TextStyle(
                              color: colors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    );

                    final bookButton = FilledButton.icon(
                      onPressed: canBook ? onBook : null,
                      style: FilledButton.styleFrom(
                        minimumSize: Size(compact ? double.infinity : 0, 42),
                        fixedSize: null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: booking
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.event_available_outlined, size: 18),
                      label: Text(booking ? 'Đang đặt...' : 'Đặt phòng'),
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          priceSection,
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: bookButton,
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(child: priceSection),
                        const SizedBox(width: 10),
                        bookButton,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.available});

  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = available ? Colors.green.shade700 : Colors.orange.shade800;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Text(
          available ? 'Đang mở' : 'Tạm đóng',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _RoomInfo extends StatelessWidget {
  const _RoomInfo({required this.icon, required this.label});

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

String? _disabledReason({required RoomModel room, required int guests}) {
  if (!room.isAvailable) {
    return 'Phòng hiện đang tạm đóng';
  }

  if (room.maxGuests < guests) {
    return 'Chỉ phù hợp tối đa ${room.maxGuests} khách';
  }

  if (room.price <= 0) {
    return 'Phòng chưa cập nhật giá';
  }

  return null;
}

String _formatMoney(double value) {
  final raw = value.toStringAsFixed(0);

  final formatted = raw.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );

  return '$formatted đ';
}