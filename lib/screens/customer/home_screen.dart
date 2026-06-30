import 'package:flutter/material.dart';

import '../../model/hotel.dart';
import '../../services/auth.dart';
import '../../services/customer_service.dart';
import 'hotel_details_screen.dart';
import 'my_bookings_screen.dart';
import 'provider_application_screen.dart';
import 'widgets/customer_empty_state.dart';
import 'widgets/hotel_card.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key, this.service});

  final CustomerService? service;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final _searchController = TextEditingController();

  late final CustomerService _service;
  late final Stream<List<HotelModel>> _hotelsStream;

  String _searchText = '';
  String _category = 'Tất cả';
  String? _province;
  String? _district;

  DateTimeRange? _dateRange;
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

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CustomerService();
    _hotelsStream = _service.watchHotels();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);

    final result = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 730)),
      initialDateRange: _dateRange,
      helpText: 'Chọn thời gian lưu trú',
      cancelText: 'Hủy',
      saveText: 'Xác nhận',
    );

    if (!mounted || result == null) return;

    setState(() => _dateRange = result);
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
                    const SizedBox(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filledTonal(
                          onPressed: guests > 1
                              ? () {
                                  setSheetState(() {
                                    guests--;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            '$guests khách',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton.filled(
                          onPressed: guests < 30
                              ? () {
                                  setSheetState(() {
                                    guests++;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(sheetContext, guests);
                        },
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
    final locationMap = <String, Set<String>>{};

    for (final hotel in hotels) {
      final province = hotel.province.trim();
      final district = hotel.district.trim();

      if (province.isEmpty) continue;

      locationMap.putIfAbsent(province, () => <String>{});

      if (district.isNotEmpty) {
        locationMap[province]!.add(district);
      }
    }

    final provinces = locationMap.keys.toList()..sort();

    if (provinces.isEmpty) {
      _showMessage('Các khách sạn chưa cập nhật tỉnh/thành phố.');
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
            final districts =
                province == null ? <String>[] : (locationMap[province]?.toList() ?? [])
                  ..sort();

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Tìm theo khu vực',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: provinces.contains(province) ? province : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tỉnh/Thành phố',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      items: provinces.map((value) {
                        return DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setSheetState(() {
                          province = value;
                          district = null;
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: ValueKey(province),
                      initialValue: districts.contains(district) ? district : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Quận/Huyện',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                      items: districts.map((value) {
                        return DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: province == null
                          ? null
                          : (value) {
                              setSheetState(() {
                                district = value;
                              });
                            },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(sheetContext, const _LocationResult());
                            },
                            child: const Text('Xóa bộ lọc'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: province == null
                                ? null
                                : () {
                                    Navigator.pop(
                                      sheetContext,
                                      _LocationResult(
                                        province: province,
                                        district: district,
                                      ),
                                    );
                                  },
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
      _searchText = '';
      _category = 'Tất cả';
      _province = null;
      _district = null;
    });
  }

  void _openHotel(HotelModel hotel) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HotelDetailsScreen(
          service: _service,
          hotel: hotel,
          initialDateRange: _dateRange,
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

  void _openProviderApplication() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ProviderApplicationScreen(),
      ),
    );
  }

  Future<void> _logout() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Đăng xuất?'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (accepted == true) {
      await AuthService().signOut();
    }
  }

  void _showMessage(String message) {
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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.travel_explore_rounded,
                color: colors.onPrimary,
              ),
            ),
            const SizedBox(width: 10),
            const Text('TravelHub'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Đơn đặt phòng',
            onPressed: _openBookings,
            icon: const Icon(Icons.event_note_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Tài khoản',
            icon: const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
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
                  leading: Icon(Icons.event_note_outlined),
                  title: Text('Đơn đặt phòng'),
                ),
              ),
              PopupMenuItem(
                value: 'provider',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.storefront_outlined),
                  title: Text('Trở thành nhà cung cấp'),
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout_rounded),
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
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 14),
                  Text('Đang tải danh sách nơi lưu trú...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                CustomerEmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Không thể tải khách sạn',
                  message: _cleanError(snapshot.error),
                  actionLabel: 'Thử lại',
                  onAction: () => setState(() {}),
                ),
              ],
            );
          }

          final allHotels = snapshot.data ?? [];
          final keyword = _normalize(_searchText);

          final hotels = allHotels.where((hotel) {
            final searchableText = _normalize(
              '${hotel.name} '
              '${hotel.address} '
              '${hotel.district} '
              '${hotel.province} '
              '${hotel.category}',
            );

            final matchesSearch = keyword.isEmpty || searchableText.contains(keyword);

            final matchesCategory =
                _category == 'Tất cả' || _normalize(hotel.category) == _normalize(_category);

            final matchesProvince =
                _province == null || _normalize(hotel.province) == _normalize(_province!);

            final matchesDistrict =
                _district == null || _normalize(hotel.district) == _normalize(_district!);

            return matchesSearch && matchesCategory && matchesProvince && matchesDistrict;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
            children: [
              Text(
                'Bạn muốn đi đâu?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tìm nơi lưu trú phù hợp cho chuyến đi.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              SearchBar(
                controller: _searchController,
                hintText: 'Tìm khách sạn hoặc địa điểm...',
                leading: const Icon(Icons.search_rounded),
                onChanged: (value) {
                  setState(() => _searchText = value);
                },
                trailing: [
                  if (_searchText.isNotEmpty)
                    IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchText = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _FilterTile(
                icon: Icons.location_on_outlined,
                title: 'Khu vực',
                value: _province == null
                    ? 'Chọn tỉnh/thành phố'
                    : _district == null
                        ? _province!
                        : '$_district, $_province',
                onTap: () {
                  _selectLocation(allHotels);
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _FilterTile(
                      icon: Icons.calendar_today_outlined,
                      title: 'Thời gian',
                      value: _dateRange == null
                          ? 'Chọn ngày'
                          : '${_formatShortDate(_dateRange!.start)} - '
                              '${_formatShortDate(_dateRange!.end)}',
                      onTap: _selectDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FilterTile(
                      icon: Icons.group_outlined,
                      title: 'Khách',
                      value: '$_guests người',
                      onTap: _selectGuests,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categories.map((category) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(category),
                        selected: _category == category,
                        onSelected: (_) {
                          setState(() {
                            _category = category;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Nơi lưu trú',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  Text('${hotels.length} kết quả'),
                ],
              ),
              const SizedBox(height: 12),
              if (hotels.isEmpty)
                CustomerEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Không tìm thấy nơi lưu trú',
                  message: allHotels.isEmpty
                      ? 'Chưa có khách sạn được hiển thị.'
                      : 'Hãy thay đổi hoặc xóa bộ lọc.',
                  actionLabel: allHotels.isEmpty ? null : 'Xóa bộ lọc',
                  onAction: allHotels.isEmpty ? null : _clearFilters,
                )
              else
                ...hotels.map(
                  (hotel) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: CustomerHotelCard(
                      hotel: hotel,
                      onTap: () => _openHotel(hotel),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Material(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
                child: ListTile(
                  onTap: _openProviderApplication,
                  contentPadding: const EdgeInsets.all(16),
                  leading: Icon(
                    Icons.storefront_rounded,
                    size: 36,
                    color: colors.onSecondaryContainer,
                  ),
                  title: const Text(
                    'Bạn đang kinh doanh lưu trú?',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: const Text('Đăng ký trở thành nhà cung cấp.'),
                  trailing: const Icon(Icons.arrow_forward_rounded),
                ),
              ),
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
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 11)),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
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

class _LocationResult {
  const _LocationResult({this.province, this.district});

  final String? province;
  final String? district;
}

String _formatShortDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}';
}

String _normalize(String value) {
  const source =
      'àáạảãâầấậẩẫăằắặẳẵ'
      'èéẹẻẽêềếệểễ'
      'ìíịỉĩ'
      'òóọỏõôồốộổỗơờớợởỡ'
      'ùúụủũưừứựửữ'
      'ỳýỵỷỹđ';

  const target =
      'aaaaaaaaaaaaaaaaa'
      'eeeeeeeeeee'
      'iiiii'
      'ooooooooooooooooo'
      'uuuuuuuuuuu'
      'yyyyyd';

  var result = value.trim().toLowerCase();

  for (var index = 0; index < source.length; index++) {
    result = result.replaceAll(source[index], target[index]);
  }

  return result;
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}