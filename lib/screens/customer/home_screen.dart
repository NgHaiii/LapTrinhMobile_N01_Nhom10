import 'package:flutter/material.dart';

import '../../model/hotel.dart';
import '../../services/customer_service.dart';
import '../../services/recommendation_service.dart';
import '../../services/voucher_service.dart';
import 'account/account_page.dart';
import 'hotels/hotel_details_screen.dart';
import 'bookings/my_bookings_screen.dart';
import 'promotions/promotions_page.dart';
import 'travel/travel_activities_page.dart';
import 'widgets/customer_empty_state.dart';
import 'widgets/hotel_card.dart';
import 'widgets/recommended_hotels_section.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({
    super.key,
    this.service,
  });

  final CustomerService? service;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final _searchController = TextEditingController();
  final _hotelSearchKey = GlobalKey();

  late final CustomerService _service;
  late final RecommendationService _recommendationService;
  late final Stream<List<HotelModel>> _hotelsStream;
  late final VoucherService _voucherService;
  late Stream<int> _newVoucherCountStream;

  String _search = '';
  String _category = 'Tất cả';
  String? _province;
  String? _district;
  int _guests = 2;

  static const _categories = [
    'Tất cả',
    'Khách sạn',
    'Căn hộ',
    'Biệt thự',
    'Homestay',
    'Resort',
    'Nhà nghỉ',
  ];

  bool get _showRecommendations {
    return _search.trim().isEmpty && _category == 'Tất cả';
  }

  Stream<int> _createNewVoucherCountStream() {
    return _voucherService.watchNewVoucherCount();
  }

  @override
  void initState() {
    super.initState();

    _service = widget.service ?? CustomerService();
    _recommendationService = RecommendationService();
    _voucherService = VoucherService();

    _hotelsStream = _service.watchHotels();
    _newVoucherCountStream =
        _createNewVoucherCountStream();
  }

  void _openHotel(HotelModel hotel) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HotelDetailsScreen(
          service: _service,
          hotel: hotel,
          initialGuests: _guests,
        ),
      ),
    );
  }

  void _openBookings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MyBookingsScreen(service: _service),
      ),
    );
  }

  void _openAccountPage() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerAccountPage(service: _service),
      ),
    );
  }

  void _openTravelActivities() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const TravelActivitiesPage(),
      ),
    );
  }

  Future<void> _openPromotions() async {
    try {
      await _voucherService.markVouchersAsSeen();

      if (mounted) {
        setState(() {
          _newVoucherCountStream =
              _createNewVoucherCountStream();
        });
      }
    } catch (_) {
      // Lỗi đánh dấu đã xem không được phép chặn trang Ưu đãi.
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PromotionsPage(),
      ),
    );
  }

  void _scrollToHotelSearch() {
    final targetContext = _hotelSearchKey.currentContext;
    if (targetContext == null) return;

    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
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
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Số lượng khách',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          onPressed: guests > 1
                              ? () => setSheetState(() => guests--)
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
                              ? () => setSheetState(() => guests++)
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, guests),
                        child: const Text('Xác nhận'),
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

  Future<void> _selectLocation(List<HotelModel> hotels) async {
    final locations = <String, Set<String>>{};

    for (final hotel in hotels) {
      final province = hotel.province.trim();
      final district = hotel.district.trim();

      if (province.isEmpty) continue;
      locations.putIfAbsent(province, () => <String>{});

      if (district.isNotEmpty) {
        locations[province]!.add(district);
      }
    }

    final provinces = locations.keys.toList()..sort();

    if (provinces.isEmpty) {
      _message('Các khách sạn chưa cập nhật tỉnh/thành phố.');
      return;
    }

    var province = _province;
    var district = _district;

    final result = await showModalBottomSheet<_LocationResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final districts = province == null
                ? <String>[]
                : (locations[province]?.toList() ?? [])..sort();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  24 + MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tìm theo khu vực',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue: provinces.contains(province)
                          ? province
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tỉnh/Thành phố',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      items: provinces
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        setSheetState(() {
                          province = value;
                          district = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey(province),
                      initialValue: districts.contains(district)
                          ? district
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Quận/Huyện',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                      items: districts
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: province == null
                          ? null
                          : (value) {
                              setSheetState(() => district = value);
                            },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(
                              sheetContext,
                              const _LocationResult(),
                            ),
                            child: const Text('Xóa khu vực'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: province == null
                                ? null
                                : () => Navigator.pop(
                                      sheetContext,
                                      _LocationResult(
                                        province: province,
                                        district: district,
                                      ),
                                    ),
                            child: const Text('Áp dụng'),
                          ),
                        ),
                      ],
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
      _province = result.province;
      _district = result.district;
    });
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _search = '';
      _category = 'Tất cả';
      _province = null;
      _district = null;
    });
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FAF8),
      body: StreamBuilder<List<HotelModel>>(
        stream: _hotelsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return CustomerEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Không thể tải khách sạn',
              message: _cleanError(snapshot.error),
            );
          }

          final allHotels = snapshot.data ?? [];
          final keyword = _normalize(_search);

          final filteredHotels = allHotels.where((hotel) {
            final source = _normalize(
              '${hotel.name} ${hotel.fullAddress} ${hotel.category}',
            );

            final matchesSearch = keyword.isEmpty || source.contains(keyword);

            final matchesCategory = _category == 'Tất cả' ||
                _normalize(hotel.category) == _normalize(_category);

            final matchesProvince = _province == null ||
                _normalize(hotel.province) == _normalize(_province!);

            final matchesDistrict = _district == null ||
                _normalize(hotel.district) == _normalize(_district!);

            return matchesSearch &&
                matchesCategory &&
                matchesProvince &&
                matchesDistrict;
          }).toList();

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                _HomeHeader(onAccountTap: _openAccountPage),
                const SizedBox(height: 18),
                _TravelHeroCard(
                  onHotelTap: _scrollToHotelSearch,
                  onActivityTap: _openTravelActivities,
                  onPromotionTap: _openPromotions,
                ),
                const SizedBox(height: 18),
                StreamBuilder<int>(
                  stream: _newVoucherCountStream,
                  initialData: 0,
                  builder: (context, voucherSnapshot) {
                    final newVoucherCount = voucherSnapshot.hasError
                        ? 0
                        : voucherSnapshot.data ?? 0;

                    return _FeatureGrid(
                      onHotelTap: _scrollToHotelSearch,
                      onActivityTap: _openTravelActivities,
                      onPromotionTap: _openPromotions,
                      onBookingsTap: _openBookings,
                      newVoucherCount: newVoucherCount,
                    );
                  },
                ),
                const SizedBox(height: 22),
                _TravelPlacePreviewSection(
                  onOpenTravel: _openTravelActivities,
                ),
                const SizedBox(height: 24),
                _HotelSearchPanel(
                  key: _hotelSearchKey,
                  searchController: _searchController,
                  search: _search,
                  guests: _guests,
                  province: _province,
                  district: _district,
                  category: _category,
                  categories: _categories,
                  onSearchChanged: (value) {
                    setState(() => _search = value);
                  },
                  onClearSearch: () {
                    _searchController.clear();
                    setState(() => _search = '');
                  },
                  onSelectLocation: () => _selectLocation(allHotels),
                  onSelectGuests: _selectGuests,
                  onSelectCategory: (value) {
                    setState(() => _category = value);
                  },
                ),
                if (_showRecommendations) ...[
                  const SizedBox(height: 24),
                  RecommendedHotelsSection(
                    service: _recommendationService,
                    province: _province ?? '',
                    district: _district ?? '',
                    limit: 20,
                    onHotelTap: _openHotel,
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _search.trim().isNotEmpty
                              ? 'Kết quả tìm kiếm'
                              : 'Nơi lưu trú phù hợp',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ),
                      Text('${filteredHotels.length} kết quả'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (filteredHotels.isEmpty)
                    CustomerEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Không tìm thấy nơi lưu trú',
                      message: 'Hãy thay đổi từ khóa hoặc bộ lọc.',
                      actionLabel: 'Xóa bộ lọc',
                      onAction: _clearFilters,
                    )
                  else
                    ...filteredHotels.map(
                      (hotel) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: CustomerHotelCard(
                          hotel: hotel,
                          onTap: () => _openHotel(hotel),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.onAccountTap,
  });

  final VoidCallback onAccountTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF087F8C),
                Color(0xFF18B6C8),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF087F8C).withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: const SizedBox(
            width: 54,
            height: 54,
            child: Icon(
              Icons.travel_explore_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TravelHub',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF102326),
                  fontSize: 23,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Khám phá, đặt phòng, tận hưởng',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF647A7D),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: 'Quản lý tài khoản',
          onPressed: onAccountTap,
          icon: const Icon(Icons.person_outline_rounded),
        ),
      ],
    );
  }
}

class _TravelHeroCard extends StatelessWidget {
  const _TravelHeroCard({
    required this.onHotelTap,
    required this.onActivityTap,
    required this.onPromotionTap,
  });

  final VoidCallback onHotelTap;
  final VoidCallback onActivityTap;
  final VoidCallback onPromotionTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 380;

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF073B42),
            Color(0xFF087F8C),
            Color(0xFF42D8C8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF087F8C).withValues(alpha: 0.26),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -34,
            top: -26,
            child: Icon(
              Icons.explore_rounded,
              size: 150,
              color: Colors.white.withValues(alpha: 0.11),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFE76F51),
                        size: 17,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Tổng quan du lịch',
                        style: TextStyle(
                          color: Color(0xFF102326),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Bạn muốn khám phá điều gì hôm nay?',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 23 : 27,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tìm khách sạn, địa điểm du lịch, ưu đãi và gợi ý hành trình trong một nơi.',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.84),
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _HeroActionButton(
                      icon: Icons.hotel_rounded,
                      label: 'Tìm khách sạn',
                      filled: true,
                      onTap: onHotelTap,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeroActionButton(
                      icon: Icons.terrain_rounded,
                      label: 'Hoạt động',
                      filled: false,
                      onTap: onActivityTap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _HeroActionButton(
                icon: Icons.confirmation_number_rounded,
                label: 'Ưu đãi và voucher',
                filled: false,
                wide: true,
                onTap: onPromotionTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroActionButton extends StatelessWidget {
  const _HeroActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
    this.wide = false,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final bool wide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );

    return SizedBox(
      height: 50,
      width: wide ? double.infinity : null,
      child: filled
          ? FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF087F8C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: onTap,
              child: child,
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: onTap,
              child: child,
            ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({
    required this.onHotelTap,
    required this.onActivityTap,
    required this.onPromotionTap,
    required this.onBookingsTap,
    required this.newVoucherCount,
  });

  final VoidCallback onHotelTap;
  final VoidCallback onActivityTap;
  final VoidCallback onPromotionTap;
  final VoidCallback onBookingsTap;
  final int newVoucherCount;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < 380;

    final items = [
      _FeatureItem(
        icon: Icons.hotel_rounded,
        title: 'Tìm khách sạn',
        subtitle: 'Đặt phòng',
        color: const Color(0xFF087F8C),
        onTap: onHotelTap,
      ),
      _FeatureItem(
        icon: Icons.terrain_rounded,
        title: 'Hoạt động',
        subtitle: 'Địa điểm',
        color: const Color(0xFFE76F51),
        onTap: onActivityTap,
      ),
      _FeatureItem(
        icon: Icons.confirmation_number_rounded,
        title: 'Ưu đãi',
        subtitle: newVoucherCount > 0
            ? '$newVoucherCount voucher mới'
            : 'Voucher',
        color: const Color(0xFF7A5AF8),
        onTap: onPromotionTap,
        badgeCount: newVoucherCount,
      ),
      _FeatureItem(
        icon: Icons.event_note_rounded,
        title: 'Đơn đặt phòng',
        subtitle: 'Theo dõi',
        color: const Color(0xFF1B7F5A),
        onTap: onBookingsTap,
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics:
          const NeverScrollableScrollPhysics(),
      gridDelegate:
          SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: compact ? 1.12 : 1.2,
      ),
      itemBuilder: (context, index) {
        final item = items[index];

        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: EdgeInsets.all(
                compact ? 12 : 14,
              ),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFD7E5E7),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.045,
                    ),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      CircleAvatar(
                        radius: compact ? 20 : 22,
                        backgroundColor:
                            item.color.withValues(
                          alpha: 0.12,
                        ),
                        foregroundColor: item.color,
                        child: Icon(
                          item.icon,
                          size: compact ? 20 : 22,
                        ),
                      ),

                      if (item.badgeCount > 0)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD92D20),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          const Color(0xFF102326),
                      fontWeight: FontWeight.w900,
                      fontSize: compact ? 13 : 14,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      color: item.badgeCount > 0
                          ? const Color(0xFFD92D20)
                          : const Color(0xFF647A7D),
                      fontSize: compact ? 11 : 12,
                      fontWeight:
                          item.badgeCount > 0
                              ? FontWeight.w800
                              : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FeatureItem {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;
}

class _TravelPlacePreviewSection extends StatelessWidget {
  const _TravelPlacePreviewSection({
    required this.onOpenTravel,
  });

  final VoidCallback onOpenTravel;

  @override
  Widget build(BuildContext context) {
    const places = [
      _PreviewPlace(
        icon: Icons.beach_access_rounded,
        title: 'Biển đảo',
        subtitle: 'Nghỉ dưỡng',
        color: Color(0xFF087F8C),
      ),
      _PreviewPlace(
        icon: Icons.landscape_rounded,
        title: 'Núi rừng',
        subtitle: 'Khám phá',
        color: Color(0xFF1B7F5A),
      ),
      _PreviewPlace(
        icon: Icons.museum_rounded,
        title: 'Văn hóa',
        subtitle: 'Di tích',
        color: Color(0xFFE76F51),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Hoạt động du lịch',
          subtitle: 'Khám phá điểm đến, lịch trình và gợi ý AI.',
          trailing: TextButton(
            onPressed: onOpenTravel,
            child: const Text('Xem thêm'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 136,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: places.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final place = places[index];

              return InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: onOpenTravel,
                child: Container(
                  width: 178,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFD7E5E7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: place.color.withValues(alpha: 0.12),
                        foregroundColor: place.color,
                        child: Icon(place.icon),
                      ),
                      const Spacer(),
                      Text(
                        place.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF102326),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        place.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF647A7D),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PreviewPlace {
  const _PreviewPlace({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
}

class _HotelSearchPanel extends StatelessWidget {
  const _HotelSearchPanel({
    super.key,
    required this.searchController,
    required this.search,
    required this.guests,
    required this.province,
    required this.district,
    required this.category,
    required this.categories,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onSelectLocation,
    required this.onSelectGuests,
    required this.onSelectCategory,
  });

  final TextEditingController searchController;
  final String search;
  final int guests;
  final String? province;
  final String? district;
  final String category;
  final List<String> categories;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onSelectLocation;
  final VoidCallback onSelectGuests;
  final ValueChanged<String> onSelectCategory;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFD7E5E7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              title: 'Tìm nơi lưu trú',
              subtitle: 'Đặt phòng linh hoạt theo từng giờ.',
            ),
            const SizedBox(height: 14),
            SearchBar(
              controller: searchController,
              hintText: 'Tên khách sạn hoặc địa điểm...',
              leading: const Icon(Icons.search_rounded),
              onChanged: onSearchChanged,
              trailing: [
                if (search.isNotEmpty)
                  IconButton(
                    tooltip: 'Xóa tìm kiếm',
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _FilterTile(
              icon: Icons.location_on_outlined,
              title: 'Khu vực',
              value: province == null
                  ? 'Tất cả tỉnh/thành phố'
                  : district == null
                      ? province!
                      : '$district, $province',
              onTap: onSelectLocation,
            ),
            const SizedBox(height: 10),
            _FilterTile(
              icon: Icons.groups_outlined,
              title: 'Số khách',
              value: '$guests khách',
              onTap: onSelectGuests,
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(item),
                      selected: category == item,
                      onSelected: (_) => onSelectCategory(item),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF102326),
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF647A7D),
                  fontWeight: FontWeight.w600,
                  height: 1.28,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _FilterTile extends StatelessWidget {
  const _FilterTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF0F7F6),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF087F8C)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF647A7D),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF102326),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationResult {
  const _LocationResult({
    this.province,
    this.district,
  });

  final String? province;
  final String? district;
}

String _normalize(String value) {
  return value.trim().toLowerCase();
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}
