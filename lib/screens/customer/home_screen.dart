import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth.dart';
import 'provider_application_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final _searchController = TextEditingController();

  String _searchText = '';
  String _selectedCategory = 'Tất cả';
  DateTimeRange? _dateRange;
  int _guests = 2;

  Stream<QuerySnapshot<Map<String, dynamic>>> get _hotelStream {
    return FirebaseFirestore.instance
        .collection('hotels')
        .where('status', isEqualTo: 'approved')
        .snapshots();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();

    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 730)),
      initialDateRange: _dateRange,
      helpText: 'Chọn thời gian lưu trú',
      saveText: 'Xác nhận',
    );

    if (result != null && mounted) {
      setState(() => _dateRange = result);
    }
  }

  Future<void> _selectGuests() async {
    var value = _guests;

    final result = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                          onPressed: value > 1
                              ? () => setModalState(() => value--)
                              : null,
                          icon: const Icon(Icons.remove),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            '$value khách',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton.filled(
                          onPressed: value < 20
                              ? () => setModalState(() => value++)
                              : null,
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, value),
                      child: const Text('Xác nhận'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() => _guests = result);
    }
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
      builder: (context) {
        return AlertDialog(
          title: const Text('Đăng xuất?'),
          content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
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

  void _showMyBookings() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .where('customerId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final bookings = snapshot.data?.docs.toList() ?? [];

                bookings.sort((first, second) {
                  final firstDate = first.data()['createdAt'] as Timestamp?;
                  final secondDate = second.data()['createdAt'] as Timestamp?;

                  return (secondDate?.millisecondsSinceEpoch ?? 0).compareTo(
                    firstDate?.millisecondsSinceEpoch ?? 0,
                  );
                });

                return CustomScrollView(
                  controller: controller,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Đơn đặt phòng của tôi',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                    if (bookings.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(
                          icon: Icons.event_busy_outlined,
                          title: 'Chưa có đơn đặt phòng',
                          message:
                              'Các đơn đặt phòng của bạn sẽ xuất hiện tại đây.',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                        sliver: SliverList.separated(
                          itemCount: bookings.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final document = bookings[index];
                            final booking = document.data();

                            return _BookingCard(
                              booking: booking,
                              onCancel: booking['status'] == 'pending'
                                  ? () async {
                                      await document.reference.update({
                                        'status': 'cancelled',
                                        'updatedAt':
                                            FieldValue.serverTimestamp(),
                                      });
                                    }
                                  : null,
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showHotelDetails(_HotelData hotel) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          minChildSize: 0.6,
          maxChildSize: 0.96,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _NetworkImage(url: hotel.imageUrl),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hotel.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const Icon(Icons.star_rounded, color: Color(0xFFF4A261)),
                    Text(
                      hotel.rating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 19),
                    const SizedBox(width: 5),
                    Expanded(child: Text(hotel.address)),
                  ],
                ),
                if (hotel.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(hotel.description),
                ],
                const SizedBox(height: 24),
                Text(
                  'Phòng đang mở bán',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('rooms')
                      .where('hotelId', isEqualTo: hotel.id)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final rooms =
                        snapshot.data?.docs.where((document) {
                          final data = document.data();
                          return data['isAvailable'] != false &&
                              ((data['maxGuests'] as num?)?.toInt() ?? 2) >=
                                  _guests;
                        }).toList() ??
                        [];

                    if (rooms.isEmpty) {
                      return const _EmptyState(
                        icon: Icons.bed_outlined,
                        title: 'Không có phòng phù hợp',
                        message:
                            'Hãy thay đổi số lượng khách hoặc thử lại sau.',
                      );
                    }

                    return Column(
                      children: rooms.map((document) {
                        return _RoomCard(
                          data: document.data(),
                          onBook: () => _bookRoom(
                            hotel: hotel,
                            roomId: document.id,
                            room: document.data(),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _bookRoom({
    required _HotelData hotel,
    required String roomId,
    required Map<String, dynamic> room,
  }) async {
    if (_dateRange == null) {
      Navigator.pop(context);
      await _selectDate();

      if (_dateRange == null) return;
      _showHotelDetails(hotel);
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final price = (room['price'] as num?)?.toDouble() ?? 0;
    final nights = _dateRange!.duration.inDays;
    final total = price * nights;

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xác nhận đặt phòng'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hotel.name),
              const SizedBox(height: 6),
              Text('Phòng: ${room['roomNumber'] ?? room['type'] ?? ''}'),
              Text('$nights đêm · $_guests khách'),
              const SizedBox(height: 10),
              Text(
                'Tổng tiền: ${_formatMoney(total)}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Đặt phòng'),
            ),
          ],
        );
      },
    );

    if (accepted != true) return;

    try {
      final existingBookings = await FirebaseFirestore.instance
          .collection('bookings')
          .where('roomId', isEqualTo: roomId)
          .get();

      final conflicted = existingBookings.docs.any((document) {
        final data = document.data();
        final status = data['status'];

        if (status == 'cancelled' || status == 'rejected') return false;

        final checkIn = (data['checkIn'] as Timestamp?)?.toDate();
        final checkOut = (data['checkOut'] as Timestamp?)?.toDate();

        if (checkIn == null || checkOut == null) return false;

        return _dateRange!.start.isBefore(checkOut) &&
            _dateRange!.end.isAfter(checkIn);
      });

      if (conflicted) {
        throw StateError('Phòng đã được đặt trong thời gian này.');
      }

      await FirebaseFirestore.instance.collection('bookings').add({
        'customerId': uid,
        'providerId': hotel.providerId,
        'hotelId': hotel.id,
        'hotelName': hotel.name,
        'roomId': roomId,
        'roomNumber': room['roomNumber'] ?? '',
        'roomType': room['type'] ?? '',
        'checkIn': Timestamp.fromDate(_dateRange!.start),
        'checkOut': Timestamp.fromDate(_dateRange!.end),
        'guests': _guests,
        'pricePerNight': price,
        'totalAmount': total,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đặt phòng thành công, đang chờ xác nhận.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    }
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
            onPressed: _showMyBookings,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Tài khoản',
            icon: const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
            onSelected: (value) {
              switch (value) {
                case 'bookings':
                  _showMyBookings();
                case 'provider':
                  _openProviderApplication();
                case 'logout':
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _hotelStream,
        builder: (context, snapshot) {
          final hotels =
              snapshot.data?.docs.map(_HotelData.fromDocument).where((hotel) {
                final search = _searchText.toLowerCase();
                final matchesSearch =
                    hotel.name.toLowerCase().contains(search) ||
                    hotel.address.toLowerCase().contains(search);

                final matchesCategory =
                    _selectedCategory == 'Tất cả' ||
                    hotel.category == _selectedCategory;

                return matchesSearch && matchesCategory;
              }).toList() ??
              [];

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'Bạn muốn đi đâu?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tìm nơi lưu trú phù hợp cho chuyến đi tiếp theo.',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              SearchBar(
                controller: _searchController,
                hintText: 'Tìm thành phố, khách sạn...',
                leading: const Icon(Icons.search_rounded),
                onChanged: (value) {
                  setState(() => _searchText = value.trim());
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
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _QuickFilter(
                      icon: Icons.calendar_today_outlined,
                      title: 'Thời gian',
                      value: _dateRange == null
                          ? 'Chọn ngày'
                          : '${_formatDate(_dateRange!.start)} - '
                                '${_formatDate(_dateRange!.end)}',
                      onTap: _selectDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickFilter(
                      icon: Icons.group_outlined,
                      title: 'Khách',
                      value: '$_guests người',
                      onTap: _selectGuests,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                'Loại hình lưu trú',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children:
                      [
                        'Tất cả',
                        'Khách sạn',
                        'Căn hộ',
                        'Biệt thự',
                        'Homestay',
                      ].map((category) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(category),
                            selected: _selectedCategory == category,
                            onSelected: (_) {
                              setState(() => _selectedCategory = category);
                            },
                          ),
                        );
                      }).toList(),
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Nơi lưu trú nổi bật',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text('${hotels.length} kết quả'),
                ],
              ),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (snapshot.hasError)
                _EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Không thể tải dữ liệu',
                  message: snapshot.error.toString(),
                )
              else if (hotels.isEmpty)
                const _EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Không tìm thấy nơi lưu trú',
                  message: 'Hãy thử thay đổi từ khóa hoặc loại hình.',
                )
              else
                ...hotels.map(
                  (hotel) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _HotelCard(
                      hotel: hotel,
                      onTap: () => _showHotelDetails(hotel),
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              Material(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
                child: ListTile(
                  onTap: _openProviderApplication,
                  contentPadding: const EdgeInsets.all(16),
                  leading: Icon(
                    Icons.storefront_rounded,
                    size: 38,
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

class _HotelData {
  const _HotelData({
    required this.id,
    required this.providerId,
    required this.name,
    required this.address,
    required this.description,
    required this.imageUrl,
    required this.category,
    required this.rating,
    required this.minPrice,
  });

  final String id;
  final String providerId;
  final String name;
  final String address;
  final String description;
  final String imageUrl;
  final String category;
  final double rating;
  final double minPrice;

  factory _HotelData.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    return _HotelData(
      id: document.id,
      providerId: data['providerId'] as String? ?? '',
      name: data['name'] as String? ?? 'Khách sạn',
      address: data['address'] as String? ?? '',
      description: data['description'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      category: data['category'] as String? ?? 'Khách sạn',
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      minPrice: (data['minPrice'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _HotelCard extends StatelessWidget {
  const _HotelCard({required this.hotel, required this.onTap});

  final _HotelData hotel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _NetworkImage(url: hotel.imageUrl),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hotel.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFF4A261),
                        size: 19,
                      ),
                      Text(hotel.rating.toStringAsFixed(1)),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hotel.address,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hotel.minPrice > 0)
                        Text(
                          'Từ ${_formatMoney(hotel.minPrice)}',
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
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.data, required this.onBook});

  final Map<String, dynamic> data;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final price = (data['price'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.bed_rounded, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data['type'] ?? 'Phòng'} - '
                    '${data['roomNumber'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${data['maxGuests'] ?? 2} khách · '
                    '${_formatMoney(price)}/đêm',
                  ),
                ],
              ),
            ),
            FilledButton(onPressed: onBook, child: const Text('Đặt')),
          ],
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, this.onCancel});

  final Map<String, dynamic> booking;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final status = booking['status'] as String? ?? 'pending';
    final statusText = switch (status) {
      'confirmed' => 'Đã xác nhận',
      'completed' => 'Hoàn thành',
      'cancelled' => 'Đã hủy',
      'rejected' => 'Bị từ chối',
      _ => 'Chờ xác nhận',
    };

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        leading: const Icon(Icons.hotel_outlined),
        title: Text(
          booking['hotelName'] as String? ?? 'Khách sạn',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${booking['roomType'] ?? ''} · $statusText\n'
          '${_formatMoney((booking['totalAmount'] as num?)?.toDouble() ?? 0)}',
        ),
        isThreeLine: true,
        trailing: onCancel == null
            ? null
            : IconButton(
                tooltip: 'Hủy đơn',
                onPressed: onCancel,
                icon: const Icon(Icons.cancel_outlined),
              ),
      ),
    );
  }
}

class _QuickFilter extends StatelessWidget {
  const _QuickFilter({
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
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 11)),
                    Text(
                      value,
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

class _NetworkImage extends StatelessWidget {
  const _NetworkImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (url.isEmpty) {
      return ColoredBox(
        color: colors.primaryContainer,
        child: Icon(
          Icons.hotel_rounded,
          size: 56,
          color: colors.onPrimaryContainer,
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        return progress == null
            ? child
            : const Center(child: CircularProgressIndicator());
      },
      errorBuilder: (_, __, ___) {
        return ColoredBox(
          color: colors.primaryContainer,
          child: Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: colors.onPrimaryContainer,
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 52),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}';
}

String _formatMoney(double value) {
  final raw = value.toStringAsFixed(0);

  final formatted = raw.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );

  return '$formatted đ';
}
