import 'package:flutter/material.dart';

import '../../../model/room.dart';
import 'image_carousel.dart';

class CustomerRoomCard extends StatelessWidget {
  const CustomerRoomCard({
    super.key,
    required this.room,
    required this.guests,
    required this.onTap,
    this.checkIn,
    this.checkOut,
  });

  final RoomModel room;
  final int guests;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reason = _disabledReason(room, guests);

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
                    images: room.images,
                    fallbackIcon: Icons.bed_outlined,
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _AvailabilityBadge(
                      available: room.isAvailable,
                    ),
                  ),
                  if (room.images.length > 1)
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: _PhotoBadge(
                        count: room.images.length,
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
                  Text(
                    '${room.type} · '
                    'Phòng ${room.roomNumber}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _RoomInfo(
                        icon: Icons.groups_outlined,
                        label:
                            'Tối đa ${room.maxGuests} khách',
                      ),
                      if (room.area > 0)
                        _RoomInfo(
                          icon:
                              Icons.square_foot_outlined,
                          label:
                              '${room.area.toStringAsFixed(0)} m²',
                        ),
                      if (room.bedCount > 0)
                        _RoomInfo(
                          icon: Icons.bed_outlined,
                          label: '${room.bedCount} '
                              '${room.bedType.isEmpty ? 'giường' : room.bedType}',
                        ),
                      if (room.enabledRatePlans.isNotEmpty)
                        _RoomInfo(
                          icon:
                              Icons.local_offer_outlined,
                          label:
                              '${room.enabledRatePlans.length} combo',
                          highlighted: true,
                        ),
                    ],
                  ),
                  if (room.description.isNotEmpty) ...[
                    const SizedBox(height: 11),
                    Text(
                      room.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          colors.surfaceContainerLow,
                      borderRadius:
                          BorderRadius.circular(8),
                      border: Border.all(
                        color: colors.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                'Giờ đầu tiên',
                                style: TextStyle(
                                  color: colors
                                      .onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                room.effectiveFirstHourPrice >
                                        0
                                    ? _money(
                                        room
                                            .effectiveFirstHourPrice,
                                      )
                                    : 'Chưa có giá',
                                style: TextStyle(
                                  color: room
                                              .effectiveFirstHourPrice >
                                          0
                                      ? colors.primary
                                      : colors.error,
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 38,
                          color: colors.outlineVariant,
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                'Từ giờ thứ hai',
                                style: TextStyle(
                                  color: colors
                                      .onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                room.effectiveAdditionalHourPrice >
                                        0
                                    ? '${_money(room.effectiveAdditionalHourPrice)}/giờ'
                                    : 'Chưa có giá',
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight:
                                      FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (room.enabledRatePlans.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(
                      'Có combo từ '
                      '${_money(_minimumComboPrice(room))}',
                      style: TextStyle(
                        color: colors.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                  if (reason != null) ...[
                    const SizedBox(height: 9),
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 17,
                          color: colors.error,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            reason,
                            style: TextStyle(
                              color: colors.error,
                              fontSize: 12,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 13),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onTap,
                      icon: const Icon(
                        Icons.visibility_outlined,
                      ),
                      label: Text(
                        reason == null
                            ? 'Xem lịch trống và đặt phòng'
                            : 'Xem chi tiết phòng',
                      ),
                    ),
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

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({
    required this.available,
  });

  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = available
        ? Colors.green.shade700
        : Colors.orange.shade800;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              available
                  ? Icons.check_circle_outline
                  : Icons.pause_circle_outline,
              color: color,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              available ? 'Đang mở' : 'Tạm đóng',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoBadge extends StatelessWidget {
  const _PhotoBadge({
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.70),
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
            const Icon(
              Icons.photo_library_outlined,
              color: Colors.white,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              '$count ảnh',
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

class _RoomInfo extends StatelessWidget {
  const _RoomInfo({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final background = highlighted
        ? colors.secondaryContainer
        : colors.surfaceContainerHighest;

    final foreground = highlighted
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
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
              size: 15,
              color: foreground,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: foreground,
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

String? _disabledReason(
  RoomModel room,
  int guests,
) {
  if (!room.isAvailable) {
    return 'Phòng hiện đang tạm đóng.';
  }

  if (room.maxGuests < guests) {
    return 'Phòng chỉ phù hợp tối đa '
        '${room.maxGuests} khách.';
  }

  if (room.effectiveFirstHourPrice <= 0 ||
      room.effectiveAdditionalHourPrice <= 0) {
    return 'Phòng chưa cập nhật đầy đủ giá thuê.';
  }

  return null;
}

double _minimumComboPrice(RoomModel room) {
  final plans = room.enabledRatePlans;

  if (plans.isEmpty) return 0;

  return plans
      .map((plan) => plan.price)
      .reduce((first, second) {
        return first < second ? first : second;
      });
}

String _money(double value) {
  final raw = value.round().toString();

  return '${raw.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  )}đ';
}