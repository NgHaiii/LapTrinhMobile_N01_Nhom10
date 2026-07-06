import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../model/booking.dart';
import '../../model/provider_application.dart';
import '../../model/violation_record.dart';
import '../../services/admin_service.dart';
import '../../services/auth.dart';
import '../../services/review_service.dart';
import '../../services/violation_service.dart';
import 'commission_management_page.dart';
import 'provider_payment_profiles_page.dart';
import 'review_management_page.dart';
import 'violation_management_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() =>
      _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminService _adminService = AdminService();
  final ReviewService _reviewService = ReviewService();
  final ViolationService _violationService =
      ViolationService();

  late final List<Widget> _pages;

  int _index = 0;

  static const List<String> _titles = [
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
      _OverviewPage(
        service: _adminService,
        violationService: _violationService,
        onOpenViolations: _openViolations,
        onOpenCommissions: _openCommissions,
      ),
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
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            const ProviderPaymentProfilesPage(),
      ),
    );
  }

  void _openCommissions() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            const CommissionManagementPage(),
      ),
    );
  }

  void _openViolations() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ViolationManagementPage(
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
            'Bạn có chắc muốn kết thúc phiên quản trị?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Hủy'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _titles[_index],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                tooltip: 'Biên bản vi phạm',
                onPressed: _openViolations,
                icon: const Icon(Icons.gavel_outlined),
              ),
              PopupMenuButton<String>(
                tooltip: 'Công cụ quản trị',
                onSelected: (value) {
                  switch (value) {
                    case 'reviews':
                      _selectPage(4);
                    case 'violations':
                      _openViolations();
                    case 'banks':
                      _openPaymentProfiles();
                    case 'commission':
                      _openCommissions();
                    case 'logout':
                      _logout();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'reviews',
                    child: _PopupMenuItem(
                      icon: Icons.rate_review_outlined,
                      label: 'Quản lý đánh giá',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'violations',
                    child: _PopupMenuItem(
                      icon: Icons.gavel_outlined,
                      label: 'Biên bản vi phạm',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'banks',
                    child: _PopupMenuItem(
                      icon: Icons.account_balance_outlined,
                      label: 'Xác minh ngân hàng',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'commission',
                    child: _PopupMenuItem(
                      icon: Icons.percent_rounded,
                      label: 'Quản lý hoa hồng',
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'logout',
                    child: _PopupMenuItem(
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
      get railDestinations {
    return const [
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
        selectedIcon: Icon(Icons.people_rounded),
        label: Text('Người dùng'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon:
            Icon(Icons.receipt_long_rounded),
        label: Text('Đặt phòng'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.crisis_alert_outlined),
        selectedIcon:
            Icon(Icons.crisis_alert_rounded),
        label: Text('Đánh giá'),
      ),
    ];
  }

  List<NavigationDestination>
      get barDestinations {
    return const [
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
        selectedIcon: Icon(Icons.people_rounded),
        label: 'Người dùng',
      ),
      NavigationDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon:
            Icon(Icons.receipt_long_rounded),
        label: 'Đặt phòng',
      ),
      NavigationDestination(
        icon: Icon(Icons.crisis_alert_outlined),
        selectedIcon:
            Icon(Icons.crisis_alert_rounded),
        label: 'Đánh giá',
      ),
    ];
  }
}

class _OverviewPage extends StatefulWidget {
  const _OverviewPage({
    required this.service,
    required this.violationService,
    required this.onOpenViolations,
    required this.onOpenCommissions,
  });

  final AdminService service;
  final ViolationService violationService;
  final VoidCallback onOpenViolations;
  final VoidCallback onOpenCommissions;

  @override
  State<_OverviewPage> createState() =>
      _OverviewPageState();
}

class _OverviewPageState extends State<_OverviewPage> {
  late Future<AdminStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = widget.service.loadStats();
  }

  Future<void> _refresh() async {
    setState(() {
      _statsFuture = widget.service.loadStats();
    });

    await _statsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminStats>(
      future: _statsFuture,
      builder: (context, statsSnapshot) {
        if (statsSnapshot.connectionState ==
                ConnectionState.waiting &&
            !statsSnapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (statsSnapshot.hasError) {
          return _AdminEmpty(
            icon: Icons.cloud_off_outlined,
            message:
                _cleanError(statsSnapshot.error),
          );
        }

        final stats = statsSnapshot.data!;

        return StreamBuilder<List<ViolationRecord>>(
          stream:
              widget.violationService.watchAllViolations(),
          builder: (context, violationSnapshot) {
            final violations =
                violationSnapshot.data ?? [];

            final waitingDecision =
                violations.where((item) {
              return item.status ==
                      ViolationStatus.investigating ||
                  item.status ==
                      ViolationStatus.appealed;
            }).length;

            final penalized =
                violations.where((item) {
              return item.status ==
                      ViolationStatus.confirmed ||
                  item.status ==
                      ViolationStatus.paid;
            }).length;

            final noPenalty =
                violations.where((item) {
              return item.status ==
                  ViolationStatus.noPenalty;
            }).length;

            final items = <_StatData>[
              _StatData(
                label: 'Người dùng',
                value: stats.users,
                icon: Icons.people_rounded,
                color: const Color(0xFF2563EB),
              ),
              _StatData(
                label: 'Nhà cung cấp',
                value: stats.providers,
                icon: Icons.storefront_rounded,
                color: const Color(0xFF15803D),
              ),
              _StatData(
                label: 'Hồ sơ chờ duyệt',
                value: stats.pendingApplications,
                icon:
                    Icons.pending_actions_rounded,
                color: const Color(0xFFD97706),
              ),
              _StatData(
                label: 'Đơn đặt phòng',
                value: stats.bookings,
                icon:
                    Icons.event_available_rounded,
                color: const Color(0xFF7C3AED),
              ),
              _StatData(
                label: 'Chờ quyết định',
                value: waitingDecision,
                icon:
                    Icons.manage_search_outlined,
                color: const Color(0xFFD35400),
              ),
              _StatData(
                label: 'Biên bản bị phạt',
                value: penalized,
                icon: Icons.gavel_rounded,
                color: const Color(0xFFB3261E),
              ),
              _StatData(
                label: 'Không áp dụng phạt',
                value: noPenalty,
                icon: Icons.verified_rounded,
                color: const Color(0xFF0F766E),
              ),
              _StatData(
                label: 'Ngân hàng chờ duyệt',
                value:
                    stats.pendingPaymentProfiles,
                icon:
                    Icons.account_balance_rounded,
                color: const Color(0xFF0369A1),
              ),
              _StatData(
                label: 'Hoa hồng chưa trả',
                value:
                    stats.unpaidCommissionInvoices,
                icon: Icons.percent_rounded,
                color: const Color(0xFFB3261E),
              ),
            ];

            return RefreshIndicator(
              onRefresh: _refresh,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      constraints.maxWidth >= 1100
                          ? 4
                          : constraints.maxWidth >= 650
                              ? 3
                              : 2;

                  return CustomScrollView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding:
                            const EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          10,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: _OverviewHeader(
                            onOpenViolations:
                                widget
                                    .onOpenViolations,
                            onOpenCommissions:
                                widget
                                    .onOpenCommissions,
                            waitingDecision:
                                waitingDecision,
                          ),
                        ),
                      ),
                      if (violationSnapshot.hasError)
                        SliverPadding(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _InlineWarning(
                              message: _cleanError(
                                violationSnapshot.error,
                              ),
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding:
                            const EdgeInsets.fromLTRB(
                          16,
                          6,
                          16,
                          28,
                        ),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 118,
                          ),
                          delegate:
                              SliverChildBuilderDelegate(
                            (context, index) {
                              return _StatCard(
                                data: items[index],
                              );
                            },
                            childCount: items.length,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({
    required this.onOpenViolations,
    required this.onOpenCommissions,
    required this.waitingDecision,
  });

  final VoidCallback onOpenViolations;
  final VoidCallback onOpenCommissions;
  final int waitingDecision;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Trung tâm điều hành',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        color:
                            colors.onPrimaryContainer,
                        fontWeight:
                            FontWeight.w900,
                      ),
                ),
              ),
              if (waitingDecision > 0)
                Badge(
                  label: Text('$waitingDecision'),
                  backgroundColor: colors.error,
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color:
                        colors.onPrimaryContainer,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            waitingDecision > 0
                ? 'Có $waitingDecision biên bản đang chờ quyết định.'
                : 'Theo dõi hoạt động, cảnh báo và nghĩa vụ tài chính.',
            style: TextStyle(
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: onOpenViolations,
                icon:
                    const Icon(Icons.gavel_outlined),
                label:
                    const Text('Biên bản vi phạm'),
              ),
              FilledButton.tonalIcon(
                onPressed: onOpenCommissions,
                icon:
                    const Icon(Icons.percent_rounded),
                label: const Text('Hoa hồng'),
              ),
            ],
          ),
        ],
      ),
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
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const _RejectApplicationDialog(),
    );

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
    if (!mounted) return;

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
              setState(() {
                _status = value.first;
              });
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<
              QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.service
                .watchApplications(_status),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                      ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child:
                      CircularProgressIndicator(),
                );
              }

              if (snapshot.hasError) {
                return _AdminEmpty(
                  icon: Icons.cloud_off_outlined,
                  message:
                      _cleanError(snapshot.error),
                );
              }

              final documents =
                  snapshot.data?.docs ?? [];

              if (documents.isEmpty) {
                return const _AdminEmpty(
                  icon:
                      Icons.fact_check_outlined,
                  message: 'Không có hồ sơ',
                );
              }

              return ListView.separated(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  0,
                  16,
                  28,
                ),
                itemCount: documents.length,
                separatorBuilder: (_, __) {
                  return const SizedBox(height: 10);
                },
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
                        maxLines: 4,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
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
                                  child:
                                      Text('Phê duyệt'),
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

class _RejectApplicationDialog
    extends StatefulWidget {
  const _RejectApplicationDialog();

  @override
  State<_RejectApplicationDialog> createState() =>
      _RejectApplicationDialogState();
}

class _RejectApplicationDialogState
    extends State<_RejectApplicationDialog> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController _controller =
      TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ??
        false)) {
      return;
    }

    final value = _controller.text.trim();

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Từ chối hồ sơ'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization:
                TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Lý do từ chối',
              alignLabelWithHint: true,
            ),
            validator: (value) {
              if ((value?.trim().length ?? 0) < 5) {
                return 'Lý do phải có ít nhất 5 ký tự.';
              }

              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            FocusScope.of(context).unfocus();
            Navigator.of(context).pop();
          },
          child: const Text('Hủy'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon:
              const Icon(Icons.block_outlined),
          label: const Text('Từ chối'),
        ),
      ],
    );
  }
}

class _UsersPage extends StatelessWidget {
  const _UsersPage({
    required this.service,
  });

  final AdminService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<
        QuerySnapshot<Map<String, dynamic>>>(
      stream: service.watchUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _AdminEmpty(
            icon: Icons.cloud_off_outlined,
            message: _cleanError(snapshot.error),
          );
        }

        final users = snapshot.data?.docs ?? [];

        if (users.isEmpty) {
          return const _AdminEmpty(
            icon: Icons.people_outline,
            message: 'Không có người dùng',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          separatorBuilder: (_, __) {
            return const SizedBox(height: 8);
          },
          itemBuilder: (context, index) {
            final document = users[index];
            final user = document.data();

            final active =
                user['isActive'] != false;
            final role =
                user['role']?.toString() ??
                    'customer';

            return Card(
              child: SwitchListTile(
                value: active,
                onChanged: role == 'admin'
                    ? null
                    : (value) async {
                        try {
                          await service.setUserActive(
                            document.id,
                            value,
                          );
                        } catch (error) {
                          if (!context.mounted) {
                            return;
                          }

                          ScaffoldMessenger.of(
                            context,
                          )
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  _cleanError(
                                    error,
                                  ),
                                ),
                              ),
                            );
                        }
                      },
                secondary: CircleAvatar(
                  child: Icon(
                    role == 'admin'
                        ? Icons
                            .admin_panel_settings_outlined
                        : role == 'provider'
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
                  'Vai trò: $role',
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
        QuerySnapshot<Map<String, dynamic>>>(
      stream: service.watchBookings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _AdminEmpty(
            icon: Icons.cloud_off_outlined,
            message: _cleanError(snapshot.error),
          );
        }

        final bookings =
            snapshot.data?.docs.toList() ?? [];

        bookings.sort((first, second) {
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
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          separatorBuilder: (_, __) {
            return const SizedBox(height: 8);
          },
          itemBuilder: (context, index) {
            final document = bookings[index];

            final booking =
                BookingModel.fromMap(
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
                  '${booking.customerName} • '
                  '${booking.customerPhone}\n'
                  'Phòng ${booking.roomNumber} • '
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

class _PopupMenuItem extends StatelessWidget {
  const _PopupMenuItem({
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

class _StatData {
  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.data,
  });

  final _StatData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: data.color.withValues(
                      alpha: 0.12,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    data.icon,
                    color: data.color,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Text(
                  '${data.value}',
                  style: TextStyle(
                    color: data.color,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              data.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_outlined,
            color: colors.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors.onErrorContainer,
              ),
            ),
          ),
        ],
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
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 52,
              color: colors.primary,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
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