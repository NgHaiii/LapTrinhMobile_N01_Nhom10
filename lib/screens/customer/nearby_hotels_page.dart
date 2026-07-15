import 'package:flutter/material.dart';

import '../../model/hotel.dart';
import '../../model/travel_place.dart';
import '../../services/customer_service.dart';
import 'hotel_details_screen.dart';
import 'widgets/customer_empty_state.dart';
import 'widgets/hotel_card.dart';

class NearbyHotelsPage extends StatefulWidget {
  const NearbyHotelsPage({
    super.key,
    required this.place,
    this.service,
  });

  final TravelPlaceModel place;
  final CustomerService? service;

  @override
  State<NearbyHotelsPage> createState() => _NearbyHotelsPageState();
}

class _NearbyHotelsPageState extends State<NearbyHotelsPage> {
  final _searchController = TextEditingController();

  late final CustomerService _service;

  String _search = '';

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CustomerService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openHotel(HotelModel hotel) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HotelDetailsScreen(
          service: _service,
          hotel: hotel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FBF8),
      appBar: AppBar(
        title: const Text('Khách sạn gần điểm đến'),
        backgroundColor: const Color(0xFFF4FBF8),
      ),
      body: StreamBuilder<List<HotelModel>>(
        stream: _service.watchHotelsByProvince(place.province),
        builder: (context, snapshot) {
          final hotels = _filterHotels(snapshot.data ?? []);

          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DestinationHeader(place: place),
                      const SizedBox(height: 16),
                      SearchBar(
                        controller: _searchController,
                        hintText: 'Tìm khách sạn, địa chỉ, tiện nghi...',
                        leading: const Icon(Icons.search_rounded),
                        onChanged: (value) {
                          setState(() => _search = value);
                        },
                        trailing: [
                          if (_search.trim().isNotEmpty)
                            IconButton(
                              tooltip: 'Xóa',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _search = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Nơi lưu trú phù hợp',
                                  style: TextStyle(
                                    color: Color(0xFF102326),
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Gợi ý khách sạn trong khu vực ${place.province}.',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${hotels.length} nơi',
                            style: TextStyle(
                              color: colors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: CustomerEmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'Không thể tải khách sạn',
                    message: _cleanError(snapshot.error),
                  ),
                )
              else if (hotels.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: CustomerEmptyState(
                    icon: Icons.hotel_outlined,
                    title: 'Chưa có khách sạn phù hợp',
                    message:
                        'Hiện chưa tìm thấy nơi lưu trú tại ${place.province}. Hãy thử tìm địa điểm khác hoặc quay lại sau.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  sliver: SliverList.separated(
                    itemCount: hotels.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final hotel = hotels[index];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (index == 0) const _BestMatchBadge(),
                          if (index == 0) const SizedBox(height: 8),
                          CustomerHotelCard(
                            hotel: hotel,
                            onTap: () => _openHotel(hotel),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).bottom + 8,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<HotelModel> _filterHotels(List<HotelModel> hotels) {
    final keyword = _normalize(_search);

    final filtered = hotels.where((hotel) {
      if (keyword.isEmpty) return true;

      final source = _normalize(
        '${hotel.name} ${hotel.category} ${hotel.fullAddress} '
        '${hotel.description} ${hotel.amenities.join(' ')}',
      );

      return source.contains(keyword);
    }).toList();

    filtered.sort((first, second) {
      final firstScore = _hotelScore(first);
      final secondScore = _hotelScore(second);

      final scoreCompare = secondScore.compareTo(firstScore);
      if (scoreCompare != 0) return scoreCompare;

      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    });

    return filtered;
  }

  double _hotelScore(HotelModel hotel) {
    var score = 0.0;

    score += hotel.rating * 20;
    score += hotel.reviewCount.clamp(0, 500) * 0.05;

    if (hotel.images.isNotEmpty || hotel.imageUrl.trim().isNotEmpty) {
      score += 8;
    }

    if (hotel.effectiveMinFirstHourPrice > 0) {
      score += 8;
    }

    if (hotel.hasContactInformation) {
      score += 4;
    }

    return score;
  }
}

class _DestinationHeader extends StatelessWidget {
  const _DestinationHeader({
    required this.place,
  });

  final TravelPlaceModel place;

  @override
  Widget build(BuildContext context) {
    final image = place.primaryImage.trim();

    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF087F8C).withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (image.isEmpty)
              const ColoredBox(color: Color(0xFF087F8C))
            else
              Image.asset(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return const ColoredBox(color: Color(0xFF087F8C));
                },
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.68),
                    const Color(0xFF087F8C).withValues(alpha: 0.44),
                    Colors.black.withValues(alpha: 0.25),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderBadge(
                    icon: Icons.place_rounded,
                    label: '${place.district}, ${place.province}',
                  ),
                  const Spacer(),
                  Text(
                    'Lưu trú gần ${place.name}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chọn nơi nghỉ phù hợp để chuyến đi trọn vẹn hơn.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
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

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BestMatchBadge extends StatelessWidget {
  const _BestMatchBadge();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
              'Phù hợp nhất với điểm đến',
              style: TextStyle(
                color: colors.onPrimaryContainer,
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

String _normalize(String value) {
  return value.trim().toLowerCase();
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');
}