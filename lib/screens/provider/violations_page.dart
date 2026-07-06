import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../model/violation_record.dart';
import '../../services/violation_service.dart';
import 'violation_details_page.dart';

class ProviderViolationsPage extends StatefulWidget {
  const ProviderViolationsPage({
    super.key,
    this.service,
  });

  final ViolationService? service;

  @override
  State<ProviderViolationsPage> createState() =>
      _ProviderViolationsPageState();
}

class _ProviderViolationsPageState
    extends State<ProviderViolationsPage> {
  final TextEditingController _searchController =
      TextEditingController();

  late final ViolationService _service;

  String _search = '';
  String _status = 'all';

  final NumberFormat _currency = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ViolationService();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providerId =
        FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biên bản vi phạm'),
      ),
      body: providerId == null
          ? const _EmptyState(
              icon: Icons.lock_outline,
              title: 'Bạn chưa đăng nhập',
              message:
                  'Vui lòng đăng nhập để xem biên bản.',
            )
          : _buildContent(providerId),
    );
  }

  Widget _buildContent(String providerId) {
    return StreamBuilder<List<ViolationRecord>>(
      stream:
          _service.watchProviderViolations(providerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
                ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return _EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Không thể tải biên bản',
            message: _cleanError(snapshot.error),
          );
        }

        final allViolations = snapshot.data ?? [];

        final violations = allViolations
            .where(_matchesFilter)
            .toList();

        return CustomScrollView(
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: _buildHeader(
                allViolations,
                violations.length,
              ),
            ),
            if (violations.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  icon: Icons.fact_check_outlined,
                  title: 'Không có biên bản',
                  message:
                      'Các biên bản của cơ sở sẽ xuất hiện tại đây.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  14,
                  16,
                  32,
                ),
                sliver: SliverList.separated(
                  itemCount: violations.length,
                  separatorBuilder: (_, __) {
                    return const SizedBox(height: 12);
                  },
                  itemBuilder: (context, index) {
                    final violation =
                        violations[index];

                    return _ProviderViolationCard(
                      violation: violation,
                      currency: _currency,
                      onTap: () {
                        Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ProviderViolationDetailsPage(
                              violationId:
                                  violation.id,
                              service: _service,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(
    List<ViolationRecord> violations,
    int resultCount,
  ) {
    final colors = Theme.of(context).colorScheme;

    final needsResponse = violations.where((item) {
      return item.status ==
          ViolationStatus.waitingProvider;
    }).length;

    final penalized = violations.where((item) {
      return item.status ==
              ViolationStatus.confirmed ||
          item.status == ViolationStatus.paid;
    }).length;

    final noPenalty = violations.where((item) {
      return item.status ==
          ViolationStatus.noPenalty;
    }).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        16,
        14,
        16,
        16,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  label: 'Cần giải trình',
                  value: '$needsResponse',
                  color: const Color(0xFFD97706),
                  icon:
                      Icons.pending_actions_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryItem(
                  label: 'Đã phạt',
                  value: '$penalized',
                  color: const Color(0xFFB3261E),
                  icon: Icons.gavel_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryItem(
                  label: 'Không phạt',
                  value: '$noPenalty',
                  color: const Color(0xFF15803D),
                  icon: Icons.verified_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SearchBar(
            controller: _searchController,
            hintText:
                'Tìm khách sạn, phòng, biên bản...',
            leading: const Icon(Icons.search_rounded),
            onChanged: (value) {
              setState(() => _search = value);
            },
            trailing: [
              if (_search.isNotEmpty)
                IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _search = '');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey(_status),
            initialValue: _status,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Trạng thái',
              prefixIcon:
                  Icon(Icons.filter_list_outlined),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: 'all',
                child: Text('Tất cả trạng thái'),
              ),
              ...ViolationStatus.values.map((status) {
                return DropdownMenuItem<String>(
                  value: status,
                  child: Text(
                    ViolationStatus.label(status),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _status = value);
            },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$resultCount biên bản phù hợp',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesFilter(
    ViolationRecord violation,
  ) {
    final keyword = _search.trim().toLowerCase();

    final matchesSearch = keyword.isEmpty ||
        violation.hotelName
            .toLowerCase()
            .contains(keyword) ||
        violation.roomNumber
            .toLowerCase()
            .contains(keyword) ||
        violation.title
            .toLowerCase()
            .contains(keyword);

    final matchesStatus = _status == 'all' ||
        violation.status == _status;

    return matchesSearch && matchesStatus;
  }
}

class _ProviderViolationCard
    extends StatelessWidget {
  const _ProviderViolationCard({
    required this.violation,
    required this.currency,
    required this.onTap,
  });

  final ViolationRecord violation;
  final NumberFormat currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor =
        _statusColor(violation.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor:
                        statusColor.withValues(
                      alpha: 0.12,
                    ),
                    foregroundColor: statusColor,
                    child: Icon(
                      violation.isNoPenalty
                          ? Icons.verified_outlined
                          : Icons.gavel_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          violation.title,
                          maxLines: 2,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${violation.hotelName} • '
                          'Phòng ${violation.roomNumber}',
                          style: TextStyle(
                            color:
                                colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              _StatusBadge(
                label: ViolationStatus.label(
                  violation.status,
                ),
                color: statusColor,
              ),
              const Divider(height: 24),
              if (violation.isNoPenalty)
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Khoản phải thanh toán',
                      ),
                    ),
                    Text(
                      'Không áp dụng',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        violation.hasPenalty
                            ? 'Khoản phạt 5%'
                            : 'Phụ thu dự kiến',
                      ),
                    ),
                    Text(
                      currency.format(
                        violation.penaltyAmount,
                      ),
                      style: TextStyle(
                        color: violation.hasPenalty
                            ? colors.error
                            : colors.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              if (violation.status ==
                  ViolationStatus.waitingProvider) ...[
                const SizedBox(height: 12),
                _Notice(
                  color: const Color(0xFFD97706),
                  text:
                      'Biên bản đang chờ bạn gửi giải trình.',
                ),
              ],
              if (violation.isNoPenalty) ...[
                const SizedBox(height: 12),
                const _Notice(
                  color: Color(0xFF15803D),
                  text:
                      'Giải trình đã được chấp nhận. Bạn không phải thanh toán khoản phạt.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.color,
    required this.text,
  });

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

Color _statusColor(String status) {
  return switch (status) {
    ViolationStatus.draft =>
      const Color(0xFF607D8B),
    ViolationStatus.waitingProvider =>
      const Color(0xFFD97706),
    ViolationStatus.investigating =>
      const Color(0xFF2563EB),
    ViolationStatus.confirmed =>
      const Color(0xFFB3261E),
    ViolationStatus.noPenalty =>
      const Color(0xFF15803D),
    ViolationStatus.appealed =>
      const Color(0xFF7C3AED),
    ViolationStatus.cancelled =>
      const Color(0xFF64748B),
    ViolationStatus.paid =>
      const Color(0xFF15803D),
    _ => const Color(0xFF607D8B),
  };
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}