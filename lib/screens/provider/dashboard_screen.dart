import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../model/review.dart';
import '../../services/auth.dart';
import '../../services/provider_service.dart';
import '../../services/review_service.dart';
import 'bookings_page.dart';
import 'commission_page.dart';
import 'hotels_page.dart';
import 'overview_page.dart';
import 'payment_settings_page.dart';
import 'reviews_page.dart';
import 'rooms_page.dart';

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

  late final List<Widget> _pages;

  late final Stream<
    QuerySnapshot<Map<String, dynamic>>
  > _bookingStream;

  late final Stream<List<ReviewModel>>
      _reviewStream;

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
    _reviewStream =
        _reviewService.watchProviderReviews();

    _pages = [
      ProviderOverviewPage(
        key: const PageStorageKey(
          'provider-overview',
        ),
        service: _service,
        onOpenHotels: () => _selectPage(1),
        onOpenRooms: () => _selectPage(2),
        onOpenBookings: () => _selectPage(3),
      ),
      ProviderHotelsPage(
        key: const PageStorageKey(
          'provider-hotels',
        ),
        service: _service,
      ),
      ProviderRoomsPage(
        key: const PageStorageKey(
          'provider-rooms',
        ),
        service: _service,
      ),
      ProviderBookingsPage(
        key: const PageStorageKey(
          'provider-bookings',
        ),
        service: _service,
      ),
      ProviderReviewsPage(
        key: const PageStorageKey(
          'provider-reviews',
        ),
        service: _reviewService,
      ),
    ];
  }

  void _selectPage(int index) {
    if (index < 0 || index >= _pages.length) {
      return;
    }

    setState(() => _selectedIndex = index);
  }

  void _openPaymentSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const ProviderPaymentSettingsPage(),
      ),
    );
  }

  void _openCommissions() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const ProviderCommissionPage(),
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
      ),
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
      builder: (sheetContext) {
        return StreamBuilder<
          DocumentSnapshot<Map<String, dynamic>>
        >(
          stream: FirebaseFirestore.instance
              .collection('providers')
              .doc(uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 280,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
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
                    ?.toString() ??
                'Nhà cung cấp';

            return SafeArea(
              child: SingleChildScrollView(
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
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      businessName,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight:
                                FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 18),
                    _ProfileRow(
                      icon: Icons.person_outline,
                      label: 'Người đại diện',
                      value: provider[
                                  'representativeName']
                              ?.toString() ??
                          '',
                    ),
                    _ProfileRow(
                      icon: Icons.phone_outlined,
                      label: 'Số điện thoại',
                      value:
                          provider['phoneNumber']
                                  ?.toString() ??
                              '',
                    ),
                    _ProfileRow(
                      icon:
                          Icons.location_on_outlined,
                      label: 'Địa chỉ',
                      value: provider['address']
                              ?.toString() ??
                          '',
                    ),
                    _ProfileRow(
                      icon: Icons.badge_outlined,
                      label: 'Mã đối tác',
                      value: uid,
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop =
            constraints.maxWidth >= 850;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _titles[_selectedIndex],
            ),
            actions: [
              StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>
              >(
                stream: _bookingStream,
                builder: (context, snapshot) {
                  final count = snapshot.data?.docs
                          .where((document) {
                        final status =
                            document.data()['status'];

                        return status == 'pending' ||
                            status ==
                                'pending_provider' ||
                            status ==
                                'payment_review';
                      }).length ??
                      0;

                  return IconButton(
                    tooltip: '$count đơn cần xử lý',
                    onPressed: () =>
                        _selectPage(3),
                    icon: Badge(
                      isLabelVisible: count > 0,
                      label: Text(
                        count > 9 ? '9+' : '$count',
                      ),
                      child: const Icon(
                        Icons
                            .notifications_none_rounded,
                      ),
                    ),
                  );
                },
              ),
              StreamBuilder<List<ReviewModel>>(
                stream: _reviewStream,
                builder: (context, snapshot) {
                  final unanswered =
                      (snapshot.data ?? [])
                          .where(
                            (review) =>
                                review.isPublished &&
                                !review
                                    .hasProviderReply,
                          )
                          .length;

                  return IconButton(
                    tooltip:
                        '$unanswered đánh giá chưa phản hồi',
                    onPressed: () =>
                        _selectPage(4),
                    icon: Badge(
                      isLabelVisible:
                          unanswered > 0,
                      label: Text(
                        unanswered > 9
                            ? '9+'
                            : '$unanswered',
                      ),
                      child: const Icon(
                        Icons.rate_review_outlined,
                      ),
                    ),
                  );
                },
              ),
              PopupMenuButton<String>(
                tooltip: 'Tài khoản đối tác',
                icon: const CircleAvatar(
                  child: Icon(
                    Icons.storefront_outlined,
                  ),
                ),
                onSelected: (value) {
                  if (value == 'profile') {
                    _showProviderProfile();
                  } else if (value == 'payment') {
                    _openPaymentSettings();
                  } else if (value ==
                      'commission') {
                    _openCommissions();
                  } else if (value == 'reviews') {
                    _selectPage(4);
                  } else if (value == 'logout') {
                    _logout();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'profile',
                    child: ListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      leading: Icon(
                        Icons.storefront_outlined,
                      ),
                      title:
                          Text('Hồ sơ đối tác'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'reviews',
                    child: ListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      leading: Icon(
                        Icons.rate_review_outlined,
                      ),
                      title:
                          Text('Đánh giá phòng'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'payment',
                    child: ListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      leading: Icon(
                        Icons
                            .account_balance_outlined,
                      ),
                      title: Text(
                        'Tài khoản nhận tiền',
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'commission',
                    child: ListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      leading:
                          Icon(Icons.percent_rounded),
                      title: Text(
                        'Hoa hồng ứng dụng',
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      contentPadding:
                          EdgeInsets.zero,
                      leading: Icon(
                        Icons.logout_rounded,
                      ),
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
                  onDestinationSelected:
                      _selectPage,
                  labelType:
                      NavigationRailLabelType.all,
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
                  onDestinationSelected:
                      _selectPage,
                  destinations:
                      const _ProviderNavigation()
                          .barDestinations,
                ),
        );
      },
    );
  }
}

class _ProviderNavigation {
  const _ProviderNavigation();

  List<NavigationRailDestination>
  get railDestinations => const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon:
              Icon(Icons.dashboard_rounded),
          label: Text('Tổng quan'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.apartment_outlined),
          selectedIcon:
              Icon(Icons.apartment_rounded),
          label: Text('Khách sạn'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.bed_outlined),
          selectedIcon: Icon(Icons.bed_rounded),
          label: Text('Phòng'),
        ),
        NavigationRailDestination(
          icon:
              Icon(Icons.receipt_long_outlined),
          selectedIcon:
              Icon(Icons.receipt_long_rounded),
          label: Text('Đơn đặt'),
        ),
        NavigationRailDestination(
          icon:
              Icon(Icons.rate_review_outlined),
          selectedIcon:
              Icon(Icons.rate_review_rounded),
          label: Text('Đánh giá'),
        ),
      ];

  List<NavigationDestination>
  get barDestinations => const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon:
              Icon(Icons.dashboard_rounded),
          label: 'Tổng quan',
        ),
        NavigationDestination(
          icon: Icon(Icons.apartment_outlined),
          selectedIcon:
              Icon(Icons.apartment_rounded),
          label: 'Khách sạn',
        ),
        NavigationDestination(
          icon: Icon(Icons.bed_outlined),
          selectedIcon: Icon(Icons.bed_rounded),
          label: 'Phòng',
        ),
        NavigationDestination(
          icon:
              Icon(Icons.receipt_long_outlined),
          selectedIcon:
              Icon(Icons.receipt_long_rounded),
          label: 'Đơn đặt',
        ),
        NavigationDestination(
          icon:
              Icon(Icons.rate_review_outlined),
          selectedIcon:
              Icon(Icons.rate_review_rounded),
          label: 'Đánh giá',
        ),
      ];
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
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(
        value.trim().isEmpty
            ? 'Chưa cập nhật'
            : value,
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