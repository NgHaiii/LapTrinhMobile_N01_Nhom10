import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../model/booking.dart';
import '../../model/provider_application.dart';
import '../../services/admin_service.dart';
import '../../services/auth.dart';
import '../../services/review_service.dart';
import 'commission_management_page.dart';
import 'provider_payment_profiles_page.dart';
import 'review_management_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() =>
      _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _adminService = AdminService();
  final _reviewService = ReviewService();

  late final List<Widget> _pages;

  int _index = 0;

  static const _titles = [
    'Tổng quan hệ thống',
    'Duyệt nhà cung cấp',
    'Quản lý người dùng',
    'Đơn đặt phòng',
    'Cảnh báo đánh giá',
  ];

  @override
  void initState() {
    super.initState();

    _pages = [
      _OverviewPage(service: _adminService),
      _ApplicationsPage(service: _adminService),
      _UsersPage(service: _adminService),
      _BookingsPage(service: _adminService),
      AdminReviewManagementPage(
        service: _reviewService,
      ),
    ];
  }

  void _selectPage(int value) {
    if (value < 0 || value >= _pages.length) return;
    setState(() => _index = value);
  }

  void _openPaymentProfiles() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const ProviderPaymentProfilesPage(),
      ),
    );
  }

  void _openCommissions() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const CommissionManagementPage(),
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
          'Bạn có chắc muốn kết thúc phiên quản trị?',
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;

        return Scaffold(
          appBar: AppBar(
            title: Text(_titles[_index]),
            actions: [
              IconButton(
                tooltip: 'Cảnh báo đánh giá',
                onPressed: () => _selectPage(4),
                icon: const Icon(
                  Icons.crisis_alert_outlined,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Công cụ quản trị',
                onSelected: (value) {
                  if (value == 'banks') {
                    _openPaymentProfiles();
                  } else if (value == 'commission') {
                    _openCommissions();
                  } else if (value == 'reviews') {
                    _selectPage(4);
                  } else if (value == 'logout') {
                    _logout();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'reviews',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.rate_review_outlined,
                      ),
                      title: Text('Quản lý đánh giá'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'banks',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.account_balance_outlined,
                      ),
                      title: Text('Xác minh ngân hàng'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'commission',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          Icon(Icons.percent_rounded),
                      title: Text('Quản lý hoa hồng'),
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
          body: Row(
            children: [
              if (desktop) ...[
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _selectPage,
                  labelType:
                      NavigationRailLabelType.all,
                  destinations:
                      const _AdminNavigation()
                          .railDestinations,
                ),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: IndexedStack(
                  index: _index,
                  children: _pages,
                ),
              ),
            ],
          ),
          bottomNavigationBar: desktop
    ? null
    : NavigationBar(
        selectedIndex: _index,
        labelBehavior:
            NavigationDestinationLabelBehavior
                .onlyShowSelected,
        onDestinationSelected: _selectPage,
        destinations:
            const _AdminNavigation()
                .barDestinations,
      ),
        );
      },
    );
  }
}

class _AdminNavigation {
  const _AdminNavigation();

  List<NavigationRailDestination>
  get railDestinations => const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon:
              Icon(Icons.dashboard_rounded),
          label: Text('Tổng quan'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon:
              Icon(Icons.fact_check_rounded),
          label: Text('Xét duyệt'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon:
              Icon(Icons.people_rounded),
          label: Text('Người dùng'),
        ),
        NavigationRailDestination(
          icon:
              Icon(Icons.receipt_long_outlined),
          selectedIcon:
              Icon(Icons.receipt_long_rounded),
          label: Text('Đặt phòng'),
        ),
        NavigationRailDestination(
          icon:
              Icon(Icons.crisis_alert_outlined),
          selectedIcon:
              Icon(Icons.crisis_alert_rounded),
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
          icon: Icon(Icons.fact_check_outlined),
          selectedIcon:
              Icon(Icons.fact_check_rounded),
          label: 'Xét duyệt',
        ),
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon:
              Icon(Icons.people_rounded),
          label: 'Người dùng',
        ),
        NavigationDestination(
          icon:
              Icon(Icons.receipt_long_outlined),
          selectedIcon:
              Icon(Icons.receipt_long_rounded),
          label: 'Đặt phòng',
        ),
        NavigationDestination(
          icon:
              Icon(Icons.crisis_alert_outlined),
          selectedIcon:
              Icon(Icons.crisis_alert_rounded),
          label: 'Đánh giá',
        ),
      ];
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({required this.service});

  final AdminService service;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminStats>(
      future: service.loadStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final stats = snapshot.data!;

        return LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
    ? 3
    : 2;

            return GridView.count(
              padding: const EdgeInsets.all(20),
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio:
    constraints.maxWidth < 500 ? 1.35 : 1.7,
              children: [
                _StatCard(
                  label: 'Người dùng',
                  value: stats.users,
                  icon: Icons.people_rounded,
                  color: Colors.blue,
                ),
                _StatCard(
                  label: 'Nhà cung cấp',
                  value: stats.providers,
                  icon: Icons.storefront_rounded,
                  color: Colors.green,
                ),
                _StatCard(
                  label: 'Hồ sơ chờ duyệt',
                  value: stats.pendingApplications,
                  icon: Icons.pending_actions_rounded,
                  color: Colors.orange,
                ),
                _StatCard(
                  label: 'Đơn đặt phòng',
                  value: stats.bookings,
                  icon:
                      Icons.event_available_rounded,
                  color: Colors.pink,
                ),
                _StatCard(
                  label: 'Ngân hàng chờ duyệt',
                  value:
                      stats.pendingPaymentProfiles,
                  icon:
                      Icons.account_balance_rounded,
                  color: Colors.indigo,
                ),
                _StatCard(
                  label: 'Hoa hồng chưa trả',
                  value:
                      stats.unpaidCommissionInvoices,
                  icon: Icons.percent_rounded,
                  color: Colors.red,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ApplicationsPage extends StatefulWidget {
  const _ApplicationsPage({
    required this.service,
  });

  final AdminService service;

  @override
  State<_ApplicationsPage> createState() =>
      _ApplicationsPageState();
}

class _ApplicationsPageState
    extends State<_ApplicationsPage> {
  String _status = 'pending';

  Future<void> _approve(
    ProviderApplication application,
  ) async {
    try {
      await widget.service
          .approveApplication(application);

      if (!mounted) return;
      _message('Đã duyệt nhà cung cấp.');
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    }
  }

  Future<void> _reject(
    ProviderApplication application,
  ) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Từ chối hồ sơ'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Lý do từ chối',
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (!mounted ||
        reason == null ||
        reason.isEmpty) {
      return;
    }

    try {
      await widget.service.rejectApplication(
        application,
        reason,
      );

      if (!mounted) return;
      _message('Đã từ chối hồ sơ.');
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'pending',
                label: Text('Chờ duyệt'),
              ),
              ButtonSegment(
                value: 'approved',
                label: Text('Đã duyệt'),
              ),
              ButtonSegment(
                value: 'rejected',
                label: Text('Từ chối'),
              ),
            ],
            selected: {_status},
            onSelectionChanged: (value) {
              setState(() => _status = value.first);
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>
          >(
            stream:
                widget.service.watchApplications(
              _status,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final documents =
                  snapshot.data!.docs;

              if (documents.isEmpty) {
                return const _AdminEmpty(
                  icon:
                      Icons.fact_check_outlined,
                  message: 'Không có hồ sơ',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  0,
                  20,
                  28,
                ),
                itemCount: documents.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final application =
                      ProviderApplication.fromMap(
                    documents[index].data(),
                  );

                  return Card(
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.all(14),
                      leading: const CircleAvatar(
                        child: Icon(
                          Icons.storefront_outlined,
                        ),
                      ),
                      title: Text(
                        application.businessName,
                        style: const TextStyle(
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(
                        '${application.representativeName}\n'
                        '${application.phoneNumber}\n'
                        '${application.address}',
                      ),
                      isThreeLine: true,
                      trailing: _status == 'pending'
                          ? PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value ==
                                    'approve') {
                                  _approve(
                                    application,
                                  );
                                } else {
                                  _reject(
                                    application,
                                  );
                                }
                              },
                              itemBuilder: (_) =>
                                  const [
                                PopupMenuItem(
                                  value: 'approve',
                                  child: Text(
                                    'Phê duyệt',
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'reject',
                                  child:
                                      Text('Từ chối'),
                                ),
                              ],
                            )
                          : null,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UsersPage extends StatelessWidget {
  const _UsersPage({required this.service});

  final AdminService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
      QuerySnapshot<Map<String, dynamic>>
    >(
      stream: service.watchUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final users = snapshot.data!.docs;

        if (users.isEmpty) {
          return const _AdminEmpty(
            icon: Icons.people_outline,
            message: 'Không có người dùng',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: users.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final document = users[index];
            final user = document.data();
            final active = user['isActive'] != false;

            return Card(
              child: SwitchListTile(
                value: active,
                onChanged: (value) async {
                  try {
                    await service.setUserActive(
                      document.id,
                      value,
                    );
                  } catch (error) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      SnackBar(
                        content: Text(
                          _cleanError(error),
                        ),
                      ),
                    );
                  }
                },
                secondary: CircleAvatar(
                  child: Icon(
                    user['role'] == 'admin'
                        ? Icons
                            .admin_panel_settings_outlined
                        : user['role'] == 'provider'
                            ? Icons
                                .storefront_outlined
                            : Icons.person_outline,
                  ),
                ),
                title: Text(
                  user['fullName']?.toString() ??
                      'Người dùng',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                subtitle: Text(
                  '${user['email'] ?? ''}\n'
                  'Vai trò: ${user['role'] ?? 'customer'}',
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

class _BookingsPage extends StatelessWidget {
  const _BookingsPage({
    required this.service,
  });

  final AdminService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
      QuerySnapshot<Map<String, dynamic>>
    >(
      stream: service.watchBookings(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final bookings = snapshot.data!.docs.toList()
          ..sort((first, second) {
            final firstTime =
                first.data()['createdAt']
                    as Timestamp?;

            final secondTime =
                second.data()['createdAt']
                    as Timestamp?;

            return (secondTime
                        ?.millisecondsSinceEpoch ??
                    0)
                .compareTo(
              firstTime?.millisecondsSinceEpoch ??
                  0,
            );
          });

        if (bookings.isEmpty) {
          return const _AdminEmpty(
            icon: Icons.receipt_long_outlined,
            message: 'Không có đơn đặt phòng',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: bookings.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final document = bookings[index];

            final booking = BookingModel.fromMap(
              document.data(),
              document.id,
            );

            return Card(
              child: ListTile(
                contentPadding:
                    const EdgeInsets.all(14),
                leading: const CircleAvatar(
                  child: Icon(
                    Icons.receipt_long_outlined,
                  ),
                ),
                title: Text(
                  booking.hotelName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: Text(
                  '${booking.customerName} · '
                  '${booking.customerPhone}\n'
                  'Phòng ${booking.roomNumber} · '
                  '${booking.statusLabel}\n'
                  '${_money(booking.totalAmount)}',
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor:
                  color.withValues(alpha: 0.12),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                          color: color,
                          fontWeight:
                              FontWeight.w900,
                        ),
                  ),
                  Text(label),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminEmpty extends StatelessWidget {
  const _AdminEmpty({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 54, color: colors.primary),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _money(double value) {
  final raw = value.round().toString();

  return '${raw.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  )}đ';
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}