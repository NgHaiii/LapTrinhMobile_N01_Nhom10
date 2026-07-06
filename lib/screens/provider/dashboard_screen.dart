import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../model/violation_record.dart';
import '../../services/auth.dart';
import '../../services/provider_service.dart';
import '../../services/review_service.dart';
import '../../services/violation_service.dart';
import 'bookings_page.dart';
import 'commission_page.dart';
import 'hotels_page.dart';
import 'overview_page.dart';
import 'payment_settings_page.dart';
import 'reviews_page.dart';
import 'rooms_page.dart';
import 'violations_page.dart';

class ProviderDashboard extends StatefulWidget {
  const ProviderDashboard({super.key});

  @override
  State<ProviderDashboard> createState() =>
      _ProviderDashboardState();
}

class _ProviderDashboardState
    extends State<ProviderDashboard> {
  final ProviderService _service = ProviderService();
  final ReviewService _reviewService = ReviewService();
  final ViolationService _violationService =
      ViolationService();

  late final List<Widget> _pages;

  late final Stream<
      QuerySnapshot<Map<String, dynamic>>> _bookingStream;

  late final Stream<List<ViolationRecord>>
      _violationStream;

  int _selectedIndex = 0;

  static const _titles = [
    'Tổng quan kinh doanh',
    'Khách sạn của tôi',
    'Quản lý phòng',
    'Đơn đặt phòng',
    'Đánh giá khách hàng',
  ];

  @override
  void initState() {
    super.initState();

    _bookingStream = _service.watchBookings();

    final providerId =
        FirebaseAuth.instance.currentUser?.uid;

    _violationStream = providerId == null
        ? Stream.value(const <ViolationRecord>[])
        : _violationService.watchProviderViolations(
            providerId,
          );

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
      ProviderReviewsPage(
        key: const PageStorageKey('provider-reviews'),
        service: _reviewService,
      ),
    ];
  }

  void _selectPage(int index) {
    if (index < 0 || index >= _pages.length) return;

    setState(() => _selectedIndex = index);
  }

  void _openPaymentSettings() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            const ProviderPaymentSettingsPage(),
      ),
    );
  }

  void _openCommissions() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const ProviderCommissionPage(),
      ),
    );
  }

  void _openViolations() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProviderViolationsPage(
          service: _violationService,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.logout_rounded),
          title: const Text('Đăng xuất?'),
          content: const Text(
            'Bạn có chắc muốn kết thúc phiên làm việc?',
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
        );
      },
    );

    if (accepted == true) {
      await AuthService().signOut();
    }
  }

  void _showProviderProfile() {
    final uid =
        FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ProviderProfileSheet(uid: uid),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 850;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _titles[_selectedIndex],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              _BookingNotificationButton(
                stream: _bookingStream,
                onPressed: () => _selectPage(3),
              ),
              _ViolationNotificationButton(
                stream: _violationStream,
                onPressed: _openViolations,
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
                    case 'reviews':
                      _selectPage(4);
                    case 'violations':
                      _openViolations();
                    case 'payment':
                      _openPaymentSettings();
                    case 'commission':
                      _openCommissions();
                    case 'logout':
                      _logout();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'profile',
                    child: _PopupItem(
                      icon: Icons.storefront_outlined,
                      label: 'Hồ sơ đối tác',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'reviews',
                    child: _PopupItem(
                      icon: Icons.rate_review_outlined,
                      label: 'Đánh giá phòng',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'violations',
                    child: _PopupItem(
                      icon: Icons.gavel_outlined,
                      label: 'Biên bản vi phạm',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'payment',
                    child: _PopupItem(
                      icon: Icons.account_balance_outlined,
                      label: 'Tài khoản nhận tiền',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'commission',
                    child: _PopupItem(
                      icon: Icons.percent_rounded,
                      label: 'Hoa hồng ứng dụng',
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'logout',
                    child: _PopupItem(
                      icon: Icons.logout_rounded,
                      label: 'Đăng xuất',
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: Row(
            children: [
              if (desktop) ...[
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _selectPage,
                  labelType: NavigationRailLabelType.all,
                  destinations:
                      const _ProviderNavigation()
                          .railDestinations,
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _pages,
                ),
              ),
            ],
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: _selectedIndex,
                  labelBehavior:
                      NavigationDestinationLabelBehavior
                          .onlyShowSelected,
                  onDestinationSelected: _selectPage,
                  destinations:
                      const _ProviderNavigation()
                          .barDestinations,
                ),
        );
      },
    );
  }
}

class _BookingNotificationButton extends StatelessWidget {
  const _BookingNotificationButton({
    required this.stream,
    required this.onPressed,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.where((document) {
              final status =
                  document.data()['status']?.toString();

              return status == 'pending' ||
                  status == 'pending_provider' ||
                  status == 'payment_review';
            }).length ??
            0;

        return IconButton(
          tooltip: '$count đơn cần xử lý',
          onPressed: onPressed,
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 9 ? '9+' : '$count'),
            child: const Icon(
              Icons.notifications_none_rounded,
            ),
          ),
        );
      },
    );
  }
}

class _ViolationNotificationButton
    extends StatelessWidget {
  const _ViolationNotificationButton({
    required this.stream,
    required this.onPressed,
  });

  final Stream<List<ViolationRecord>> stream;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ViolationRecord>>(
      stream: stream,
      builder: (context, snapshot) {
        final count = (snapshot.data ?? []).where((item) {
          return item.status ==
                  ViolationStatus.waitingProvider ||
              item.status == ViolationStatus.appealed;
        }).length;

        return IconButton(
          tooltip: '$count biên bản cần xử lý',
          onPressed: onPressed,
          icon: Badge(
            isLabelVisible: count > 0,
            backgroundColor:
                Theme.of(context).colorScheme.error,
            label: Text(count > 9 ? '9+' : '$count'),
            child: const Icon(Icons.gavel_outlined),
          ),
        );
      },
    );
  }
}

class _ProviderProfileSheet extends StatelessWidget {
  const _ProviderProfileSheet({
    required this.uid,
  });

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('providers')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const SizedBox(
            height: 280,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return _ProfileError(
            message: snapshot.error.toString(),
          );
        }

        final provider = snapshot.data?.data();

        if (provider == null) {
          return const _ProfileError(
            message:
                'Không tìm thấy hồ sơ nhà cung cấp.',
          );
        }

        final businessName =
            provider['businessName']
                    ?.toString()
                    .trim() ??
                'Nhà cung cấp';

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            24,
            4,
            24,
            28,
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 32,
                child: Text(
                  businessName.isEmpty
                      ? 'ĐT'
                      : businessName
                          .substring(0, 1)
                          .toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                businessName,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 18),
              _ProfileRow(
                icon: Icons.person_outline,
                label: 'Người đại diện',
                value: provider['representativeName']
                        ?.toString() ??
                    '',
              ),
              _ProfileRow(
                icon: Icons.phone_outlined,
                label: 'Số điện thoại',
                value:
                    provider['phoneNumber']?.toString() ??
                        '',
              ),
              _ProfileRow(
                icon: Icons.location_on_outlined,
                label: 'Địa chỉ',
                value:
                    provider['address']?.toString() ?? '',
              ),
              _ProfileRow(
                icon: Icons.badge_outlined,
                label: 'Mã đối tác',
                value: uid,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProviderNavigation {
  const _ProviderNavigation();

  List<NavigationRailDestination>
      get railDestinations {
    return const [
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
      NavigationRailDestination(
        icon: Icon(Icons.rate_review_outlined),
        selectedIcon: Icon(Icons.rate_review_rounded),
        label: Text('Đánh giá'),
      ),
    ];
  }

  List<NavigationDestination> get barDestinations {
    return const [
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
      NavigationDestination(
        icon: Icon(Icons.rate_review_outlined),
        selectedIcon: Icon(Icons.rate_review_rounded),
        label: 'Đánh giá',
      ),
    ];
  }
}

class _PopupItem extends StatelessWidget {
  const _PopupItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(
        value.trim().isEmpty ? 'Chưa cập nhật' : value,
      ),
    );
  }
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}