import 'package:flutter/material.dart';

import '../../model/hotel.dart';
import '../../model/room.dart';
import '../../services/customer_service.dart';
import 'room_details_screen.dart';
import 'widgets/customer_empty_state.dart';
import 'widgets/image_carousel.dart';
import 'widgets/room_card.dart';

class HotelDetailsScreen extends StatefulWidget {
  const HotelDetailsScreen({
    super.key,
    required this.service,
    required this.hotel,
    this.initialCheckIn,
    this.initialCheckOut,
    this.initialGuests = 2,
  });

  final CustomerService service;
  final HotelModel hotel;
  final DateTime? initialCheckIn;
  final DateTime? initialCheckOut;
  final int initialGuests;

  @override
  State<HotelDetailsScreen> createState() =>
      _HotelDetailsScreenState();
}

class _HotelDetailsScreenState
    extends State<HotelDetailsScreen> {
  final _searchController = TextEditingController();

  late int _guests;
  String _search = '';
  bool _onlyAvailable = true;

  @override
  void initState() {
    super.initState();

    _guests = widget.initialGuests > 0
        ? widget.initialGuests
        : 1;
  }

  Future<void> _selectGuests() async {
    var value = _guests;

    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  4,
                  24,
                  24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Số lượng khách',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          onPressed: value > 1
                              ? () => setSheetState(
                                  () => value--,
                                )
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            '$value khách',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium,
                          ),
                        ),
                        IconButton.filled(
                          onPressed: value < 30
                              ? () => setSheetState(
                                  () => value++,
                                )
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(
                          sheetContext,
                          value,
                        ),
                        child: const Text('Áp dụng'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;
    setState(() => _guests = result);
  }

  void _openRoom(RoomModel room) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RoomDetailsScreen(
          service: widget.service,
          hotel: widget.hotel,
          room: room,
          initialCheckIn: widget.initialCheckIn,
          initialCheckOut: widget.initialCheckOut,
          initialGuests: _guests,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hotel = widget.hotel;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết khách sạn'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CustomerImageCarousel(
                images: hotel.images,
                fallbackIcon:
                    Icons.apartment_outlined,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              20,
              18,
              20,
              12,
            ),
            sliver: SliverList.list(
              children: [
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        hotel.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.w900,
                            ),
                      ),
                    ),
                    _RatingBadge(
                      rating: hotel.rating,
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 19,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        hotel.fullAddress.isEmpty
                            ? 'Chưa cập nhật địa chỉ'
                            : hotel.fullAddress,
                      ),
                    ),
                  ],
                ),
                if (hotel.description.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    hotel.description,
                    style: const TextStyle(height: 1.5),
                  ),
                ],
                if (hotel.amenities.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children:
                        hotel.amenities.map((value) {
                          return Chip(
                            avatar: const Icon(
                              Icons
                                  .check_circle_outline,
                              size: 16,
                            ),
                            label: Text(value),
                          );
                        }).toList(),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Chọn phòng',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Mở chi tiết phòng để xem lịch trống, '
                  'combo và giá chính xác.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(
                      () => _search =
                          value.trim().toLowerCase(),
                    );
                  },
                  decoration: InputDecoration(
                    hintText:
                        'Tìm loại phòng hoặc số phòng...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                    ),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();

                              setState(
                                () => _search = '',
                              );
                            },
                            icon: const Icon(
                              Icons.close_rounded,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _FilterTile(
                        icon: Icons.groups_outlined,
                        label: '$_guests khách',
                        onTap: _selectGuests,
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilterChip(
                      label:
                          const Text('Phòng đang mở'),
                      selected: _onlyAvailable,
                      onSelected: (value) {
                        setState(
                          () => _onlyAvailable = value,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          StreamBuilder<List<RoomModel>>(
            stream: widget.service.watchRooms(
              hotelId: hotel.id,
              hotelName: hotel.name,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                      ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: CustomerEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Không thể tải phòng',
                    message:
                        _cleanError(snapshot.error),
                  ),
                );
              }

              final rooms = (snapshot.data ?? [])
                  .where((room) {
                    final source =
                        '${room.roomNumber} ${room.type}'
                            .toLowerCase();

                    final matchesSearch =
                        _search.isEmpty ||
                        source.contains(_search);

                    final matchesGuests =
                        room.maxGuests >= _guests;

                    final matchesStatus =
                        !_onlyAvailable ||
                        room.isAvailable;

                    return matchesSearch &&
                        matchesGuests &&
                        matchesStatus;
                  })
                  .toList();

              if (rooms.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: CustomerEmptyState(
                    icon: Icons.bed_outlined,
                    title: 'Không có phòng phù hợp',
                    message:
                        'Hãy thay đổi số khách hoặc bộ lọc.',
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  32,
                ),
                sliver: SliverList.separated(
                  itemCount: rooms.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final room = rooms[index];

                    return CustomerRoomCard(
                      room: room,
                      guests: _guests,
                      checkIn: widget.initialCheckIn,
                      checkOut: widget.initialCheckOut,
                      onTap: () => _openRoom(room),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          child: Row(
            children: [
              Icon(icon, size: 19),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
              ),
            ],
          ),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.star_rounded,
              color: Colors.orange,
              size: 18,
            ),
            const SizedBox(width: 3),
            Text(
              rating > 0
                  ? rating.toStringAsFixed(1)
                  : 'Mới',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}