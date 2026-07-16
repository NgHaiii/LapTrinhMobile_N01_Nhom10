import 'package:flutter/material.dart';

import '../../../model/hotel.dart';
import '../../../model/hotel_rating.dart';
import '../../../model/review.dart';
import '../../../model/room.dart';
import '../../../services/customer_service.dart';
import '../../../services/recommendation_service.dart';
import '../../../services/review_service.dart';
import '../reviews/hotel_reviews_screen.dart';
import '../rooms/room_details_screen.dart';
import '../widgets/customer_empty_state.dart';
import '../widgets/image_carousel.dart';
import '../widgets/rating_summary.dart';
import '../widgets/room_card.dart';

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

  late final RecommendationService
      _recommendationService;
  late final ReviewService _reviewService;

  late Stream<List<RoomRecommendation>>
      _recommendedRoomsStream;

  late Stream<List<ReviewModel>> _reviewsStream;

  late int _guests;
  String _search = '';

  @override
  void initState() {
    super.initState();

    _guests = widget.initialGuests > 0
        ? widget.initialGuests
        : 1;

    _recommendationService =
        RecommendationService();

    _reviewService = ReviewService();

    _reviewsStream =
        _reviewService.watchHotelRoomReviews(
      widget.hotel.id,
    );

    _refreshRecommendedRooms();
  }

  void _refreshRecommendedRooms() {
    _recommendedRoomsStream =
        _recommendationService.watchRecommendedRooms(
      hotelId: widget.hotel.id,
      guests: _guests,
      limit: 100,
    );
  }

  Future<void> _selectGuests() async {
    var guests = _guests;

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
                    const Text(
                      'Số lượng khách',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          onPressed: guests > 1
                              ? () => setSheetState(
                                  () => guests--,
                                )
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(
                          width: 120,
                          child: Text(
                            '$guests khách',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton.filled(
                          onPressed: guests < 30
                              ? () => setSheetState(
                                  () => guests++,
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
                        onPressed: () =>
                            Navigator.pop(
                          sheetContext,
                          guests,
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

    setState(() {
      _guests = result;
      _refreshRecommendedRooms();
    });
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

  void _openReviews() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HotelReviewsScreen(
          service: _reviewService,
          hotelId: widget.hotel.id,
          hotelName: widget.hotel.name,
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
                Text(
                  hotel.name,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 9),
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: colors.primary,
                      size: 19,
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
                    children: hotel.amenities.map((value) {
                      return Chip(
                        avatar: const Icon(
                          Icons.check_circle_outline,
                          size: 16,
                        ),
                        label: Text(value),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 20),
                StreamBuilder<List<ReviewModel>>(
                  stream: _reviewsStream,
                  builder: (context, snapshot) {
                    final reviews = snapshot.data ?? [];

                    final rating =
                        HotelRating.calculate(
                      hotelId: hotel.id,
                      reviews: reviews,
                    );

                    return Column(
                      children: [
                        CustomerRatingSummary.hotel(
                          rating: rating,
                        ),
                        if (rating.reviewCount > 0) ...[
                          const SizedBox(height: 9),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _openReviews,
                              icon: const Icon(
                                Icons.rate_review_outlined,
                              ),
                              label: Text(
                                'Xem ${rating.reviewCount} '
                                'đánh giá phòng',
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  'Phòng đề xuất',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Phòng phù hợp được xếp theo điểm '
                  'đánh giá và số lượt đánh giá.',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
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
                  onChanged: (value) {
                    setState(() {
                      _search =
                          value.trim().toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 10),
                _GuestFilter(
                  guests: _guests,
                  onTap: _selectGuests,
                ),
              ],
            ),
          ),
          StreamBuilder<List<RoomRecommendation>>(
            stream: _recommendedRoomsStream,
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
                  .where((recommendation) {
                final room = recommendation.room;

                final source =
                    '${room.roomNumber} ${room.type}'
                        .toLowerCase();

                return _search.isEmpty ||
                    source.contains(_search);
              }).toList();

              if (rooms.isEmpty) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: CustomerEmptyState(
                    icon: Icons.bed_outlined,
                    title: 'Không có phòng phù hợp',
                    message:
                        'Hãy thay đổi số khách hoặc từ khóa.',
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
                    final recommendation =
                        rooms[index];

                    final room =
                        recommendation.room.copyWith(
                      rating:
                          recommendation.rating.averageRating,
                      reviewCount:
                          recommendation.rating.reviewCount,
                      recommendationScore:
                          recommendation.rating
                              .recommendationScore,
                    );

                    return Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        if (index == 0 &&
                            recommendation
                                .rating.hasReviews)
                          Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: 7,
                            ),
                            child: _TopRoomBadge(
                              rating:
                                  recommendation.rating,
                            ),
                          ),
                        CustomerRoomCard(
                          room: room,
                          guests: _guests,
                          checkIn: widget.initialCheckIn,
                          checkOut:
                              widget.initialCheckOut,
                          onTap: () => _openRoom(room),
                        ),
                      ],
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

class _GuestFilter extends StatelessWidget {
  const _GuestFilter({
    required this.guests,
    required this.onTap,
  });

  final int guests;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 11,
          ),
          child: Row(
            children: [
              Icon(
                Icons.groups_outlined,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$guests khách',
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

class _TopRoomBadge extends StatelessWidget {
  const _TopRoomBadge({required this.rating});

  final RoomRating rating;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
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
              Icons.workspace_premium_outlined,
              size: 17,
              color: colors.onPrimaryContainer,
            ),
            const SizedBox(width: 5),
            Text(
              'Được đề xuất · '
              '${rating.averageRating.toStringAsFixed(1)} sao · '
              '${rating.reviewCount} đánh giá',
              style: TextStyle(
                color: colors.onPrimaryContainer,
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

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}