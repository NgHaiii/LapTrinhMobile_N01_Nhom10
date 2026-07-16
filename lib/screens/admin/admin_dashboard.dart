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
import 'voucher_management_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AdminService _adminService = AdminService();
  final ReviewService _reviewService = ReviewService();
  final ViolationService _violationService = ViolationService();

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
        onOpenApplications: () => _selectPage(1),
        onOpenUsers: () => _selectPage(2),
        onOpenBookings: () => _selectPage(3),
        onOpenReviews: () => _selectPage(4),
        onOpenViolations: _openViolations,
        onOpenCommissions: _openCommissions,
        onOpenPaymentProfiles: _openPaymentProfiles,
        onOpenVouchers: _openVouchers,
      ),
      _ApplicationsPage(service: _adminService),
      _UsersPage(service: _adminService),
      _BookingsPage(service: _adminService),
      AdminReviewManagementPage(service: _reviewService),
    ];
  }

  void _selectPage(int value) {
    if (value < 0 || value >= _pages.length) return;
    setState(() => _index = value);
  }

  void _openPaymentProfiles() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const ProviderPaymentProfilesPage(),
      ),
    );
  }

  void _openCommissions() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const CommissionManagementPage(),
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

  void _openVouchers() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const VoucherManagementPage(),
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: colors.surface,
          appBar: AppBar(
            title: Text(
              _titles[_index],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                tooltip: 'Quản lý voucher',
                onPressed: _openVouchers,
                icon: const Icon(Icons.local_activity_outlined),
              ),
              IconButton(
                tooltip: 'Biên bản vi phạm',
                onPressed: _openViolations,
                icon: const Icon(Icons.gavel_outlined),
              ),
              PopupMenuButton<String>(
                tooltip: 'Công cụ quản trị',
                onSelected: (value) {
                  switch (value) {
                    case 'applications':
                      _selectPage(1);
                    case 'users':
                      _selectPage(2);
                    case 'bookings':
                      _selectPage(3);
                    case 'reviews':
                      _selectPage(4);
                    case 'violations':
                      _openViolations();
                    case 'banks':
                      _openPaymentProfiles();
                    case 'commission':
                      _openCommissions();
                    case 'vouchers':
                      _openVouchers();
                    case 'logout':
                      _logout();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'applications',
                    child: _PopupMenuItem(
                      icon: Icons.fact_check_outlined,
                      label: 'Duyệt nhà cung cấp',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'users',
                    child: _PopupMenuItem(
                      icon: Icons.people_outline,
                      label: 'Quản lý người dùng',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'bookings',
                    child: _PopupMenuItem(
                      icon: Icons.receipt_long_outlined,
                      label: 'Đơn đặt phòng',
                    ),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'vouchers',
                    child: _PopupMenuItem(
                      icon: Icons.local_activity_outlined,
                      label: 'Quản lý voucher',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'commission',
                    child: _PopupMenuItem(
                      icon: Icons.percent_rounded,
                      label: 'Quản lý hoa hồng',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'banks',
                    child: _PopupMenuItem(
                      icon: Icons.account_balance_outlined,
                      label: 'Xác minh ngân hàng',
                    ),
                  ),
                  PopupMenuDivider(),
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
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: colors.surface,
                  destinations: const _AdminNavigation().railDestinations,
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
                      NavigationDestinationLabelBehavior.onlyShowSelected,
                  onDestinationSelected: _selectPage,
                  destinations: const _AdminNavigation().barDestinations,
                ),
        );
      },
    );
  }
}

class _AdminNavigation {
  const _AdminNavigation();

  List<NavigationRailDestination> get railDestinations {
    return const [
      NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard_rounded),
        label: Text('Tổng quan'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.fact_check_outlined),
        selectedIcon: Icon(Icons.fact_check_rounded),
        label: Text('Xét duyệt'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people_rounded),
        label: Text('Người dùng'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.receipt_long_outlined),
        selectedIcon: Icon(Icons.receipt_long_rounded),
        label: Text('Đặt phòng'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.crisis_alert_outlined),
        selectedIcon: Icon(Icons.crisis_alert_rounded),
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
        label: 'Đơn đặt',
      ),
      NavigationDestination(
        icon: Icon(Icons.crisis_alert_outlined),
        selectedIcon: Icon(Icons.crisis_alert_rounded),
        label: 'Đánh giá',
      ),
    ];
  }
}

class _OverviewPage extends StatefulWidget {
  const _OverviewPage({
    required this.service,
    required this.violationService,
    required this.onOpenApplications,
    required this.onOpenUsers,
    required this.onOpenBookings,
    required this.onOpenReviews,
    required this.onOpenViolations,
    required this.onOpenCommissions,
    required this.onOpenPaymentProfiles,
    required this.onOpenVouchers,
  });

  final AdminService service;
  final ViolationService violationService;
  final VoidCallback onOpenApplications;
  final VoidCallback onOpenUsers;
  final VoidCallback onOpenBookings;
  final VoidCallback onOpenReviews;
  final VoidCallback onOpenViolations;
  final VoidCallback onOpenCommissions;
  final VoidCallback onOpenPaymentProfiles;
  final VoidCallback onOpenVouchers;

  @override
  State<_OverviewPage> createState() => _OverviewPageState();
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
        if (statsSnapshot.connectionState == ConnectionState.waiting &&
            !statsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (statsSnapshot.hasError) {
          return _AdminEmpty(
            icon: Icons.cloud_off_outlined,
            message: _cleanError(statsSnapshot.error),
          );
        }

        final stats = statsSnapshot.data!;

        return StreamBuilder<List<ViolationRecord>>(
          stream: widget.violationService.watchAllViolations(),
          builder: (context, violationSnapshot) {
            final violations = violationSnapshot.data ?? [];

            final waitingDecision = violations.where((item) {
              return item.status == ViolationStatus.investigating ||
                  item.status == ViolationStatus.appealed;
            }).length;

            final penalized = violations.where((item) {
              return item.status == ViolationStatus.confirmed ||
                  item.status == ViolationStatus.paid;
            }).length;

            final noPenalty = violations.where((item) {
              return item.status == ViolationStatus.noPenalty;
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
                color: const Color(0xFF0F766E),
              ),
              _StatData(
                label: 'Hồ sơ chờ duyệt',
                value: stats.pendingApplications,
                icon: Icons.pending_actions_rounded,
                color: const Color(0xFFF59E0B),
              ),
              _StatData(
                label: 'Đơn đặt phòng',
                value: stats.bookings,
                icon: Icons.event_available_rounded,
                color: const Color(0xFF7C3AED),
              ),
              _StatData(
                label: 'Chờ quyết định',
                value: waitingDecision,
                icon: Icons.manage_search_outlined,
                color: const Color(0xFFE76F51),
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
                color: const Color(0xFF16A34A),
              ),
              _StatData(
                label: 'Ngân hàng chờ duyệt',
                value: stats.pendingPaymentProfiles,
                icon: Icons.account_balance_rounded,
                color: const Color(0xFF0284C7),
              ),
              _StatData(
                label: 'Hoa hồng chưa trả',
                value: stats.unpaidCommissionInvoices,
                icon: Icons.percent_rounded,
                color: const Color(0xFFDC2626),
              ),
            ];

            return RefreshIndicator(
              onRefresh: _refresh,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1100
                      ? 4
                      : constraints.maxWidth >= 650
                          ? 3
                          : 2;

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                        sliver: SliverToBoxAdapter(
                          child: _OverviewHero(
                            waitingDecision: waitingDecision,
                            onOpenReviews: widget.onOpenReviews,
                            onOpenViolations: widget.onOpenViolations,
                          ),
                        ),
                      ),
                      if (violationSnapshot.hasError)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverToBoxAdapter(
                            child: _InlineWarning(
                              message: _cleanError(violationSnapshot.error),
                            ),
                          ),
                        ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        sliver: SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 116,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _StatCard(data: items[index]),
                            childCount: items.length,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            children: [
                              _AdminActionGroup(
                                title: 'Vận hành hệ thống',
                                subtitle:
                                    'Theo dõi người dùng, nhà cung cấp và đơn đặt phòng.',
                                icon: Icons.dashboard_customize_outlined,
                                color: const Color(0xFF008C95),
                                actions: [
                                  _AdminAction(
                                    icon: Icons.fact_check_outlined,
                                    title: 'Duyệt nhà cung cấp',
                                    subtitle: 'Xem hồ sơ đăng ký kinh doanh',
                                    onTap: widget.onOpenApplications,
                                  ),
                                  _AdminAction(
                                    icon: Icons.people_outline,
                                    title: 'Người dùng',
                                    subtitle: 'Khóa, mở khóa tài khoản',
                                    onTap: widget.onOpenUsers,
                                  ),
                                  _AdminAction(
                                    icon: Icons.receipt_long_outlined,
                                    title: 'Đơn đặt phòng',
                                    subtitle: 'Theo dõi lịch sử đặt phòng',
                                    onTap: widget.onOpenBookings,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _AdminActionGroup(
                                title: 'Tài chính & khuyến mại',
                                subtitle:
                                    'Quản lý tiền hoa hồng, ngân hàng và ưu đãi.',
                                icon: Icons.payments_outlined,
                                color: const Color(0xFFE76F51),
                                actions: [
                                  _AdminAction(
                                    icon: Icons.percent_rounded,
                                    title: 'Hoa hồng',
                                    subtitle: 'Lập và xác nhận hóa đơn',
                                    onTap: widget.onOpenCommissions,
                                  ),
                                  _AdminAction(
                                    icon: Icons.account_balance_outlined,
                                    title: 'Ngân hàng',
                                    subtitle: 'Xác minh tài khoản nhận tiền',
                                    onTap: widget.onOpenPaymentProfiles,
                                  ),
                                  _AdminAction(
                                    icon: Icons.local_activity_outlined,
                                    title: 'Voucher',
                                    subtitle: 'Tạo mã giảm giá, đổi điểm',
                                    onTap: widget.onOpenVouchers,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _AdminActionGroup(
                                title: 'Chất lượng dịch vụ',
                                subtitle:
                                    'Kiểm soát đánh giá xấu và xử lý biên bản.',
                                icon: Icons.health_and_safety_outlined,
                                color: const Color(0xFF7C3AED),
                                actions: [
                                  _AdminAction(
                                    icon: Icons.rate_review_outlined,
                                    title: 'Đánh giá',
                                    subtitle: 'Cảnh báo đánh giá tiêu cực',
                                    onTap: widget.onOpenReviews,
                                  ),
                                  _AdminAction(
                                    icon: Icons.gavel_outlined,
                                    title: 'Biên bản vi phạm',
                                    subtitle: 'Phạt hoặc không phạt NCC',
                                    onTap: widget.onOpenViolations,
                                  ),
                                ],
                              ),
                            ],
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

class _OverviewHero extends StatelessWidget {
  const _OverviewHero({
    required this.waitingDecision,
    required this.onOpenReviews,
    required this.onOpenViolations,
  });

  final int waitingDecision;
  final VoidCallback onOpenReviews;
  final VoidCallback onOpenViolations;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 172),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF006D77),
            Color(0xFF00A6A6),
            Color(0xFFF4A261),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF006D77).withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -28,
            child: Icon(
              Icons.travel_explore_rounded,
              size: 130,
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'TravelHub Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                waitingDecision > 0
                    ? 'Có $waitingDecision biên bản cần quyết định'
                    : 'Trung tâm điều hành TravelHub',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                waitingDecision > 0
                    ? 'Theo dõi đánh giá xấu, giải trình và quyết định phạt minh bạch.'
                    : 'Quản lý vận hành, doanh thu, ưu đãi và chất lượng dịch vụ trong một nơi.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onOpenReviews,
                    icon: const Icon(Icons.rate_review_outlined),
                    label: const Text('Xem đánh giá'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenViolations,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    icon: const Icon(Icons.gavel_outlined),
                    label: const Text('Biên bản'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AdminActionGroup extends StatelessWidget {
  const _AdminActionGroup({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.actions,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<_AdminAction> actions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.13),
                  foregroundColor: color,
                  child: Icon(icon),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final width = wide
                    ? (constraints.maxWidth - 16) / 3
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: actions.map((action) {
                    return SizedBox(
                      width: width,
                      child: _AdminActionTile(action: action),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminAction {
  const _AdminAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _AdminActionTile extends StatelessWidget {
  const _AdminActionTile({
    required this.action,
  });

  final _AdminAction action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerHighest.withOpacity(0.42),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.primary,
                child: Icon(action.icon, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
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
  State<_ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends State<_ApplicationsPage> {
  String _status = 'pending';

  Future<void> _approve(
    ProviderApplication application,
  ) async {
    try {
      await widget.service.approveApplication(application);

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
      builder: (_) => const _RejectApplicationDialog(),
    );

    if (!mounted || reason == null || reason.isEmpty) {
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
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.service.watchApplications(_status),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return _AdminEmpty(
                  icon: Icons.cloud_off_outlined,
                  message: _cleanError(snapshot.error),
                );
              }

              final documents = snapshot.data?.docs ?? [];

              if (documents.isEmpty) {
                return const _AdminEmpty(
                  icon: Icons.fact_check_outlined,
                  message: 'Không có hồ sơ',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                itemCount: documents.length,
                separatorBuilder: (_, __) {
                  return const SizedBox(height: 10);
                },
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
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      subtitle: Text(
                        '${application.representativeName}\n'
                        '${application.phoneNumber}\n'
                        '${application.address}',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: _status == 'pending'
                          ? PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'approve') {
                                  _approve(application);
                                } else {
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

class _RejectApplicationDialog extends StatefulWidget {
  const _RejectApplicationDialog();

  @override
  State<_RejectApplicationDialog> createState() =>
      _RejectApplicationDialogState();
}

class _RejectApplicationDialogState extends State<_RejectApplicationDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
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
            textCapitalization: TextCapitalization.sentences,
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
          icon: const Icon(Icons.block_outlined),
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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.watchUsers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
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

            final active = user['isActive'] != false;
            final role = user['role']?.toString() ?? 'customer';

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
                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(_cleanError(error)),
                              ),
                            );
                        }
                      },
                secondary: CircleAvatar(
                  child: Icon(
                    role == 'admin'
                        ? Icons.admin_panel_settings_outlined
                        : role == 'provider'
                            ? Icons.storefront_outlined
                            : Icons.person_outline,
                  ),
                ),
                title: Text(
                  user['fullName']?.toString() ?? 'Người dùng',
                  style: const TextStyle(fontWeight: FontWeight.w800),
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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.watchBookings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _AdminEmpty(
            icon: Icons.cloud_off_outlined,
            message: _cleanError(snapshot.error),
          );
        }

        final bookings = snapshot.data?.docs.toList() ?? [];

        bookings.sort((first, second) {
          final firstTime = first.data()['createdAt'] as Timestamp?;

          final secondTime = second.data()['createdAt'] as Timestamp?;

          return (secondTime?.millisecondsSinceEpoch ?? 0).compareTo(
            firstTime?.millisecondsSinceEpoch ?? 0,
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
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: data.color.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: data.color.withOpacity(0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  data.icon,
                  color: data.color,
                  size: 21,
                ),
              ),
              const Spacer(),
              Text(
                '${data.value}',
                style: TextStyle(
                  color: data.color,
                  fontSize: 24,
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
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ],
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
        borderRadius: BorderRadius.circular(12),
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
            CircleAvatar(
              radius: 34,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.primary,
              child: Icon(icon, size: 34),
            ),
            const SizedBox(height: 12),
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