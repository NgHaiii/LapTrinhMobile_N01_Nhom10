import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../model/provider_application.dart';
import '../../services/admin_service.dart';
import '../../services/auth.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _service = AdminService();
  int _currentIndex = 0;

  static const _titles = [
    'Tổng quan',
    'Duyệt nhà cung cấp',
    'Người dùng',
    'Đơn đặt phòng',
  ];

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
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: AuthService().signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
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
          crossAxisCount: MediaQuery.sizeOf(context).width >= 700 ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
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
              label: 'Chờ xét duyệt',
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending', label: Text('Chờ duyệt')),
              ButtonSegment(value: 'approved', label: Text('Đã duyệt')),
              ButtonSegment(value: 'rejected', label: Text('Từ chối')),
              ButtonSegment(value: 'all', label: Text('Tất cả')),
            ],
            selected: {_status},
            onSelectionChanged: (values) {
              setState(() => _status = values.first);
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.service.watchApplications(_status),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final applications =
                  snapshot.data?.docs.map((document) {
                    return ProviderApplication.fromMap(document.data());
                  }).toList() ??
                  [];

              if (applications.isEmpty) {
                return const _EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Không có hồ sơ',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: applications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final application = applications[index];

                  return Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(14),
                      leading: const CircleAvatar(
                        child: Icon(Icons.storefront_outlined),
                      ),
                      title: Text(
                        application.businessName,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${application.representativeName}\n'
                        '${application.phoneNumber}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showApplication(application),
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

  void _showApplication(ProviderApplication application) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          maxChildSize: 0.97,
          builder: (context, controller) {
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              children: [
                Text(
                  application.businessName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                _InfoTile(
                  icon: Icons.person_outline,
                  label: 'Người đại diện',
                  value: application.representativeName,
                ),
                _InfoTile(
                  icon: Icons.phone_outlined,
                  label: 'Số điện thoại',
                  value: application.phoneNumber,
                ),
                _InfoTile(
                  icon: Icons.location_on_outlined,
                  label: 'Địa chỉ',
                  value: application.address,
                ),
                _InfoTile(
                  icon: Icons.badge_outlined,
                  label: 'CCCD/CMND',
                  value: application.identityNumber,
                ),
                const SizedBox(height: 18),
                _DocumentImage(
                  title: 'Mặt trước CCCD/CMND',
                  url: application.identityFrontUrl,
                ),
                _DocumentImage(
                  title: 'Mặt sau CCCD/CMND',
                  url: application.identityBackUrl,
                ),
                _DocumentImage(
                  title: 'Giấy phép kinh doanh',
                  url: application.businessLicenseUrl,
                ),
                if (application.status == ApplicationStatus.pending) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _reject(sheetContext, application),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Từ chối'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _approve(sheetContext, application),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Phê duyệt'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _approve(
    BuildContext sheetContext,
    ProviderApplication application,
  ) async {
    try {
      await widget.service.approveApplication(application);

      if (!mounted) return;
      Navigator.pop(sheetContext);
      _message('Đã phê duyệt nhà cung cấp.');
    } catch (error) {
      _message(error.toString());
    }
  }

  Future<void> _reject(
    BuildContext sheetContext,
    ProviderApplication application,
  ) async {
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Lý do từ chối'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Nhập nội dung cần bổ sung...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (reason == null) return;

    try {
      await widget.service.rejectApplication(application, reason);

      if (!mounted) return;
      Navigator.pop(sheetContext);
      _message('Đã từ chối hồ sơ.');
    } catch (error) {
      _message(error.toString());
    }
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
        final users = snapshot.data?.docs ?? [];

        if (users.isEmpty) {
          return const _EmptyState(
            icon: Icons.people_outline,
            title: 'Chưa có người dùng',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final document = users[index];
            final user = document.data();
            final active = user['isActive'] != false;

            return Card(
              child: SwitchListTile(
                value: active,
                onChanged: user['role'] == 'admin'
                    ? null
                    : (value) async {
                        try {
                          await service.setUserActive(document.id, value);
                        } catch (error) {
                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      },
                secondary: CircleAvatar(
                  child: Text(
                    (user['fullName'] as String? ?? '?').characters.first
                        .toUpperCase(),
                  ),
                ),
                title: Text(
                  user['fullName'] as String? ?? 'Người dùng',
                  style: const TextStyle(fontWeight: FontWeight.w900),
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
        final bookings = snapshot.data?.docs ?? [];

        if (bookings.isEmpty) {
          return const _EmptyState(
            icon: Icons.event_busy_outlined,
            title: 'Chưa có đơn đặt phòng',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: bookings.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final document = bookings[index];
            final booking = document.data();

            return Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: const Icon(Icons.hotel_outlined),
                title: Text(
                  booking['hotelName'] as String? ?? 'Khách sạn',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  'Phòng: ${booking['roomNumber'] ?? ''}\n'
                  'Trạng thái: ${booking['status'] ?? 'pending'}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (status) {
                    service.updateBookingStatus(document.id, status);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'confirmed', child: Text('Xác nhận')),
                    PopupMenuItem(
                      value: 'completed',
                      child: Text('Hoàn thành'),
                    ),
                    PopupMenuItem(value: 'cancelled', child: Text('Hủy đơn')),
                  ],
                ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const Spacer(),
            Text(
              '$value',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(label, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
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
      subtitle: Text(value),
    );
  }
}

class _DocumentImage extends StatelessWidget {
  const _DocumentImage({required this.title, required this.url});

  final String title;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return const Center(
                    child: Icon(Icons.broken_image_outlined, size: 42),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
