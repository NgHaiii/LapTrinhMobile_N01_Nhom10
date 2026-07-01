import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../model/booking.dart';
import '../../model/provider_application.dart';
import '../../services/admin_service.dart';
import '../../services/auth.dart';
import 'commission_management_page.dart';
import 'provider_payment_profiles_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminService _service = AdminService();
  int _index = 0;

  static const _titles = [
    'Tổng quan hệ thống',
    'Duyệt nhà cung cấp',
    'Quản lý người dùng',
    'Đơn đặt phòng',
  ];

  void _openPaymentProfiles() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ProviderPaymentProfilesPage(),
      ),
    );
  }

  void _openCommissions() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CommissionManagementPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _OverviewPage(service: _service),
      _ApplicationsPage(service: _service),
      _UsersPage(service: _service),
      _BookingsPage(service: _service),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'banks') _openPaymentProfiles();
              if (value == 'commission') _openCommissions();
              if (value == 'logout') AuthService().signOut();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'banks',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.account_balance_outlined),
                  title: Text('Xác minh ngân hàng'),
                ),
              ),
              PopupMenuItem(
                value: 'commission',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.percent_rounded),
                  title: Text('Quản lý hoa hồng'),
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
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          setState(() => _index = value);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check_rounded),
            label: 'Xét duyệt',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Người dùng',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Đặt phòng',
          ),
        ],
      ),
    );
  }
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
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data!;

        return GridView.count(
          padding: const EdgeInsets.all(20),
          crossAxisCount: MediaQuery.sizeOf(context).width >= 800 ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.3,
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
              icon: Icons.event_available_rounded,
              color: Colors.pink,
            ),
            _StatCard(
              label: 'Ngân hàng chờ duyệt',
              value: stats.pendingPaymentProfiles,
              icon: Icons.account_balance_rounded,
              color: Colors.indigo,
            ),
            _StatCard(
              label: 'Hoa hồng chưa trả',
              value: stats.unpaidCommissionInvoices,
              icon: Icons.percent_rounded,
              color: Colors.red,
            ),
          ],
        );
      },
    );
  }
}

class _ApplicationsPage extends StatefulWidget {
  const _ApplicationsPage({required this.service});

  final AdminService service;

  @override
  State<_ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<_ApplicationsPage> {
  String _status = 'pending';

  Future<void> _approve(ProviderApplication application) async {
    try {
      await widget.service.approveApplication(application);

      if (!mounted) return;
      _message('Đã duyệt nhà cung cấp.');
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    }
  }

  Future<void> _reject(ProviderApplication application) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Từ chối hồ sơ'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Lý do từ chối',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, controller.text);
              },
              child: const Text('Từ chối'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || reason == null) return;

    try {
      await widget.service.rejectApplication(application, reason);

      if (!mounted) return;
      _message('Đã từ chối hồ sơ.');
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
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
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.service.watchApplications(_status),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final documents = snapshot.data!.docs;

              if (documents.isEmpty) {
                return const Center(child: Text('Không có hồ sơ'));
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                itemCount: documents.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final application = ProviderApplication.fromMap(
                    documents[index].data(),
                  );

                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: const CircleAvatar(
                        child: Icon(Icons.storefront_outlined),
                      ),
                      title: Text(
                        application.businessName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
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
                                if (value == 'approve') {
                                  _approve(application);
                                }

                                if (value == 'reject') {
                                  _reject(application);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'approve',
                                  child: Text('Phê duyệt'),
                                ),
                                PopupMenuItem(
                                  value: 'reject',
                                  child: Text('Từ chối'),
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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.watchUsers(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final document = users[index];
            final user = document.data();
            final active = user['isActive'] != false;

            return Card(
              child: SwitchListTile(
                value: active,
                onChanged: (value) async {
                  try {
                    await service.setUserActive(document.id, value);
                  } catch (error) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_cleanError(error))),
                    );
                  }
                },
                secondary: CircleAvatar(
                  child: Icon(
                    user['role'] == 'admin'
                        ? Icons.admin_panel_settings_outlined
                        : user['role'] == 'provider'
                        ? Icons.storefront_outlined
                        : Icons.person_outline,
                  ),
                ),
                title: Text(
                  user['fullName']?.toString() ?? 'Người dùng',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${user['email'] ?? ''}\nVai trò: ${user['role'] ?? 'customer'}',
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
  const _BookingsPage({required this.service});

  final AdminService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.watchBookings(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings = snapshot.data!.docs.toList()
          ..sort((first, second) {
            final firstTime =
                first.data()['createdAt'] as Timestamp?;
            final secondTime =
                second.data()['createdAt'] as Timestamp?;

            return (secondTime?.millisecondsSinceEpoch ?? 0).compareTo(
              firstTime?.millisecondsSinceEpoch ?? 0,
            );
          });

        if (bookings.isEmpty) {
          return const Center(child: Text('Không có đơn đặt phòng'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: bookings.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final document = bookings[index];
            final booking = BookingModel.fromMap(
              document.data(),
              document.id,
            );

            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: const CircleAvatar(
                  child: Icon(Icons.receipt_long_outlined),
                ),
                title: Text(
                  booking.hotelName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${booking.customerName} · ${booking.customerPhone}\n'
                  'Phòng ${booking.roomNumber} · ${booking.statusLabel}\n'
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 30),
            const Spacer(),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(label),
          ],
        ),
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