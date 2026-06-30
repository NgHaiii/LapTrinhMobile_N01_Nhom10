import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth.dart';
import '../../services/provider_service.dart';
import 'bookings_page.dart';
import 'hotels_page.dart';
import 'overview_page.dart';
import 'rooms_page.dart';

class ProviderDashboard extends StatefulWidget {
  const ProviderDashboard({super.key});

  @override
  State<ProviderDashboard> createState() => _ProviderDashboardState();
}

class _ProviderDashboardState extends State<ProviderDashboard> {
  final ProviderService _service = ProviderService();

  late final List<Widget> _pages;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _bookingStream;

  int _selectedIndex = 0;

  static const _titles = [
    'Tổng quan kinh doanh',
    'Khách sạn của tôi',
    'Quản lý phòng',
    'Đơn đặt phòng',
  ];

  @override
  void initState() {
    super.initState();

    // Chỉ khởi tạo stream và các trang một lần để giữ state ổn định.
    _bookingStream = _service.watchBookings();

    _pages = [
      ProviderOverviewPage(
        key: const PageStorageKey('provider-overview'),
        service: _service,
        onOpenHotels: () => _selectPage(1),
        onOpenRooms: () => _selectPage(2),
        onOpenBookings: () => _selectPage(3),
      ),
      ProviderHotelsPage(
        key: const PageStorageKey('provider-hotels'),
        service: _service,
      ),
      ProviderRoomsPage(
        key: const PageStorageKey('provider-rooms'),
        service: _service,
      ),
      ProviderBookingsPage(
        key: const PageStorageKey('provider-bookings'),
        service: _service,
      ),
    ];
  }

  void _selectPage(int index) {
    if (index < 0 || index >= _pages.length || index == _selectedIndex) {
      return;
    }

    setState(() => _selectedIndex = index);
  }

  Future<void> _logout() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Đăng xuất?'),
          content: const Text('Bạn có chắc chắn muốn kết thúc phiên làm việc?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (accepted == true) {
      await AuthService().signOut();
    }
  }

  void _showProviderProfile() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      _showMessage('Không tìm thấy tài khoản đang đăng nhập.');
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('providers')
              .doc(uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 280,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError) {
              return _ProfileError(message: snapshot.error.toString());
            }

            final provider = snapshot.data?.data();

            if (provider == null) {
              return const _ProfileError(
                message: 'Không tìm thấy hồ sơ nhà cung cấp trong Firestore.',
              );
            }

            final businessName =
                provider['businessName']?.toString() ?? 'Nhà cung cấp';

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          child: Text(
                            _firstCharacter(businessName),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                businessName,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 18,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    provider['status'] == 'active'
                                        ? 'Đối tác đang hoạt động'
                                        : 'Đối tác đã xác minh',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _ProfileRow(
                      icon: Icons.person_outline,
                      label: 'Người đại diện',
                      value: provider['representativeName']?.toString() ?? '',
                    ),
                    _ProfileRow(
                      icon: Icons.phone_outlined,
                      label: 'Số điện thoại',
                      value: provider['phoneNumber']?.toString() ?? '',
                    ),
                    _ProfileRow(
                      icon: Icons.location_on_outlined,
                      label: 'Địa chỉ',
                      value: provider['address']?.toString() ?? '',
                    ),
                    _ProfileRow(
                      icon: Icons.badge_outlined,
                      label: 'Mã đối tác',
                      value: uid,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Đóng'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _firstCharacter(String? text) {
    final value = text?.trim() ?? '';

    if (value.isEmpty) return 'ĐT';

    return value.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 850;

        return Scaffold(
          appBar: AppBar(
            title: Text(_titles[_selectedIndex]),
            actions: [
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _bookingStream,
                builder: (context, snapshot) {
                  final pendingCount =
                      snapshot.data?.docs.where((document) {
                        return document.data()['status'] == 'pending';
                      }).length ??
                      0;

                  return IconButton(
                    tooltip: pendingCount > 0
                        ? '$pendingCount đơn đang chờ xử lý'
                        : 'Không có đơn mới',
                    onPressed: () => _selectPage(3),
                    icon: Badge(
                      isLabelVisible: pendingCount > 0,
                      label: Text(pendingCount > 9 ? '9+' : '$pendingCount'),
                      child: const Icon(Icons.notifications_none_rounded),
                    ),
                  );
                },
              ),
              PopupMenuButton<String>(
                tooltip: 'Tài khoản đối tác',
                icon: const CircleAvatar(
                  child: Icon(Icons.storefront_outlined),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'profile':
                      _showProviderProfile();
                    case 'logout':
                      _logout();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'profile',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.storefront_outlined),
                      title: Text('Hồ sơ đối tác'),
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
          body: Row(
            children: [
              if (desktop) ...[
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectPage,
                  labelType: NavigationRailLabelType.all,
                  groupAlignment: -0.8,
                  leading: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.business_center_rounded,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard_rounded),
                      label: Text('Tổng quan'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.apartment_outlined),
                      selectedIcon: Icon(Icons.apartment_rounded),
                      label: Text('Khách sạn'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.bed_outlined),
                      selectedIcon: Icon(Icons.bed_rounded),
                      label: Text('Phòng'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long_rounded),
                      label: Text('Đơn đặt'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: IndexedStack(index: _selectedIndex, children: _pages),
              ),
            ],
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectPage,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      selectedIcon: Icon(Icons.dashboard_rounded),
                      label: 'Tổng quan',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.apartment_outlined),
                      selectedIcon: Icon(Icons.apartment_rounded),
                      label: 'Khách sạn',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bed_outlined),
                      selectedIcon: Icon(Icons.bed_rounded),
                      label: 'Phòng',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long_rounded),
                      label: 'Đơn đặt',
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(label),
        subtitle: Text(value.trim().isEmpty ? 'Chưa cập nhật' : value),
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 54,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            const Text(
              'Không thể tải hồ sơ đối tác',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
