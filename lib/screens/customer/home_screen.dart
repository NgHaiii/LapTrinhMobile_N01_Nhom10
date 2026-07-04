import 'package:flutter/material.dart';

import '../../model/hotel.dart';
import '../../services/auth.dart';
import '../../services/customer_service.dart';
import '../../services/recommendation_service.dart';
import 'hotel_details_screen.dart';
import 'my_bookings_screen.dart';
import 'provider_application_screen.dart';
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
  State<CustomerHomeScreen> createState() =>
      _CustomerHomeScreenState();
}

class _CustomerHomeScreenState
    extends State<CustomerHomeScreen> {
  final _searchController = TextEditingController();

  late final CustomerService _service;
  late final RecommendationService
      _recommendationService;
  late final Stream<List<HotelModel>> _hotelsStream;

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
    return _search.trim().isEmpty &&
        _category == 'Tất cả';
  }

  @override
  void initState() {
    super.initState();

    _service = widget.service ?? CustomerService();
    _recommendationService =
        RecommendationService();
    _hotelsStream = _service.watchHotels();
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
        builder: (_) => MyBookingsScreen(
          service: _service,
        ),
      ),
    );
  }

  void _openProviderApplication() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const ProviderApplicationScreen(),
      ),
    );
  }

  Future<void> _logout() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: const Text('Đăng xuất?'),
        content: const Text(
          'Bạn có chắc muốn đăng xuất khỏi ứng dụng?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton.icon(
            onPressed: () =>
                Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (!mounted || accepted != true) return;
    await AuthService().signOut();
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
                    Text(
                      'Số lượng khách',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w900,
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
                              fontWeight:
                                  FontWeight.w800,
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

  Future<void> _selectLocation(
    List<HotelModel> hotels,
  ) async {
    final locations = <String, Set<String>>{};

    for (final hotel in hotels) {
      final province = hotel.province.trim();
      final district = hotel.district.trim();

      if (province.isEmpty) continue;

      locations.putIfAbsent(
        province,
        () => <String>{},
      );

      if (district.isNotEmpty) {
        locations[province]!.add(district);
      }
    }

    final provinces = locations.keys.toList()
      ..sort();

    if (provinces.isEmpty) {
      _message(
        'Các khách sạn chưa cập nhật tỉnh/thành phố.',
      );
      return;
    }

    var province = _province;
    var district = _district;

    final result =
        await showModalBottomSheet<_LocationResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final districts = province == null
                ? <String>[]
                : (locations[province]?.toList() ??
                    [])
              ..sort();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  24 +
                      MediaQuery.viewInsetsOf(
                        sheetContext,
                      ).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tìm theo khu vực',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                      initialValue:
                          provinces.contains(province)
                          ? province
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tỉnh/Thành phố',
                        prefixIcon: Icon(
                          Icons.location_city_outlined,
                        ),
                      ),
                      items: provinces
                          .map(
                            (value) =>
                                DropdownMenuItem(
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
                      initialValue:
                          districts.contains(district)
                          ? district
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Quận/Huyện',
                        prefixIcon:
                            Icon(Icons.map_outlined),
                      ),
                      items: districts
                          .map(
                            (value) =>
                                DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: province == null
                          ? null
                          : (value) {
                              setSheetState(
                                () => district = value,
                              );
                            },
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.pop(
                              sheetContext,
                              const _LocationResult(),
                            ),
                            child:
                                const Text('Xóa khu vực'),
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
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TravelHub'),
        actions: [
          IconButton(
            tooltip: 'Đơn đặt phòng',
            onPressed: _openBookings,
            icon: const Icon(
              Icons.event_note_outlined,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Tài khoản',
            icon: CircleAvatar(
              backgroundColor:
                  colors.primaryContainer,
              foregroundColor:
                  colors.onPrimaryContainer,
              child: const Icon(
                Icons.person_outline_rounded,
              ),
            ),
            onSelected: (value) {
              if (value == 'bookings') {
                _openBookings();
              } else if (value == 'provider') {
                _openProviderApplication();
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'bookings',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.event_note_outlined,
                  ),
                  title: Text('Đơn đặt phòng'),
                ),
              ),
              PopupMenuItem(
                value: 'provider',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.storefront_outlined,
                  ),
                  title: Text(
                    'Trở thành nhà cung cấp',
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      Icon(Icons.logout_rounded),
                  title: Text('Đăng xuất'),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<HotelModel>>(
        stream: _hotelsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
                  ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
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

          final filteredHotels =
              allHotels.where((hotel) {
            final source = _normalize(
              '${hotel.name} '
              '${hotel.fullAddress} '
              '${hotel.category}',
            );

            final matchesSearch =
                keyword.isEmpty ||
                source.contains(keyword);

            final matchesCategory =
                _category == 'Tất cả' ||
                _normalize(hotel.category) ==
                    _normalize(_category);

            final matchesProvince =
                _province == null ||
                _normalize(hotel.province) ==
                    _normalize(_province!);

            final matchesDistrict =
                _district == null ||
                _normalize(hotel.district) ==
                    _normalize(_district!);

            return matchesSearch &&
                matchesCategory &&
                matchesProvince &&
                matchesDistrict;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              32,
            ),
            children: [
              Text(
                'Tìm nơi lưu trú',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 5),
              Text(
                'Đặt phòng linh hoạt theo từng giờ.',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SearchBar(
                controller: _searchController,
                hintText:
                    'Tên khách sạn hoặc địa điểm...',
                leading:
                    const Icon(Icons.search_rounded),
                onChanged: (value) {
                  setState(() => _search = value);
                },
                trailing: [
                  if (_search.isNotEmpty)
                    IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: () {
                        _searchController.clear();

                        setState(() => _search = '');
                      },
                      icon: const Icon(
                        Icons.close_rounded,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _FilterTile(
                icon: Icons.location_on_outlined,
                title: 'Khu vực',
                value: _province == null
                    ? 'Tất cả tỉnh/thành phố'
                    : _district == null
                        ? _province!
                        : '$_district, $_province',
                onTap: () =>
                    _selectLocation(allHotels),
              ),
              const SizedBox(height: 10),
              _FilterTile(
                icon: Icons.groups_outlined,
                title: 'Số khách',
                value: '$_guests khách',
                onTap: _selectGuests,
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      _categories.map((category) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        right: 8,
                      ),
                      child: ChoiceChip(
                        label: Text(category),
                        selected:
                            _category == category,
                        onSelected: (_) {
                          setState(
                            () => _category = category,
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              /*
               * Chế độ mặc định:
               * Chỉ hiển thị danh sách đề xuất đã sắp xếp.
               * Không lặp lại danh sách tất cả khách sạn.
               */
              if (_showRecommendations) ...[
                const SizedBox(height: 26),
                RecommendedHotelsSection(
                  service: _recommendationService,
                  province: _province ?? '',
                  district: _district ?? '',
                  limit: 20,
                  onHotelTap: _openHotel,
                ),
              ] else ...[
                /*
                 * Chỉ hiện danh sách thông thường khi
                 * khách tìm kiếm hoặc chọn loại hình.
                 */
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _search.trim().isNotEmpty
                            ? 'Kết quả tìm kiếm'
                            : 'Nơi lưu trú phù hợp',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.w900,
                            ),
                      ),
                    ),
                    Text(
                      '${filteredHotels.length} kết quả',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (filteredHotels.isEmpty)
                  CustomerEmptyState(
                    icon: Icons.search_off_rounded,
                    title:
                        'Không tìm thấy nơi lưu trú',
                    message:
                        'Hãy thay đổi từ khóa hoặc bộ lọc.',
                    actionLabel: 'Xóa bộ lọc',
                    onAction: _clearFilters,
                  )
                else
                  ...filteredHotels.map(
                    (hotel) => Padding(
                      padding:
                          const EdgeInsets.only(
                        bottom: 14,
                      ),
                      child: CustomerHotelCard(
                        hotel: hotel,
                        onTap: () =>
                            _openHotel(hotel),
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
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
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Icon(icon, color: colors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      value,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
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