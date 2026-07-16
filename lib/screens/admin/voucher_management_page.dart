import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'voucher_form_page.dart';

class VoucherManagementPage extends StatefulWidget {
  const VoucherManagementPage({super.key});

  @override
  State<VoucherManagementPage> createState() => _VoucherManagementPageState();
}

class _VoucherManagementPageState extends State<VoucherManagementPage> {
  final _searchController = TextEditingController();
  String _statusFilter = 'all';
  String _targetFilter = 'all';

  CollectionReference<Map<String, dynamic>> get _vouchersRef {
    return FirebaseFirestore.instance.collection('vouchers');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _watchVouchers() {
    return _vouchersRef.orderBy('createdAt', descending: true).snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final keyword = _searchController.text.trim().toLowerCase();

    return docs.where((doc) {
      final data = doc.data();
      final title = (data['title'] as String? ?? '').toLowerCase();
      final code = (data['code'] as String? ?? '').toLowerCase();
      final target = data['target'] as String? ?? 'all';
      final isActive = data['isActive'] as bool? ?? true;
      final endAt = _toDate(data['endAt']);
      final isExpired = endAt != null && endAt.isBefore(DateTime.now());

      final matchKeyword =
          keyword.isEmpty || title.contains(keyword) || code.contains(keyword);

      final matchTarget = _targetFilter == 'all' || target == _targetFilter;

      final matchStatus = switch (_statusFilter) {
        'active' => isActive && !isExpired,
        'inactive' => !isActive,
        'expired' => isExpired,
        _ => true,
      };

      return matchKeyword && matchTarget && matchStatus;
    }).toList();
  }

  Future<void> _toggleActive(String id, bool currentValue) async {
    await _vouchersRef.doc(id).update({
      'isActive': !currentValue,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteVoucher(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa voucher?'),
          content: const Text(
            'Voucher sau khi xóa sẽ không thể sử dụng hoặc hiển thị cho khách hàng.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await _vouchersRef.doc(id).delete();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã xóa voucher.')),
    );
  }

  void _openForm({
    String? voucherId,
    Map<String, dynamic>? initialData,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoucherFormPage(
          voucherId: voucherId,
          initialData: initialData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Quản lý voucher'),
        actions: [
          IconButton(
            tooltip: 'Thêm voucher',
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.local_activity_outlined),
        label: const Text('Tạo voucher'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _watchVouchers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Không thể tải voucher',
              message: snapshot.error.toString(),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data!.docs;
          final docs = _filterDocs(allDocs);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              _HeaderCard(total: allDocs.length),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Tìm theo mã hoặc tên voucher...',
                ),
              ),
              const SizedBox(height: 12),
              _FilterBar(
                status: _statusFilter,
                target: _targetFilter,
                onStatusChanged: (value) {
                  setState(() => _statusFilter = value);
                },
                onTargetChanged: (value) {
                  setState(() => _targetFilter = value);
                },
              ),
              const SizedBox(height: 16),
              if (docs.isEmpty)
                const _EmptyState(
                  icon: Icons.confirmation_number_outlined,
                  title: 'Chưa có voucher phù hợp',
                  message: 'Tạo voucher mới để khách hàng đổi điểm hoặc nhận ưu đãi.',
                )
              else
                ...docs.map((doc) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _VoucherAdminCard(
                      id: doc.id,
                      data: doc.data(),
                      onEdit: () => _openForm(
                        voucherId: doc.id,
                        initialData: doc.data(),
                      ),
                      onToggleActive: () {
                        _toggleActive(
                          doc.id,
                          doc.data()['isActive'] as bool? ?? true,
                        );
                      },
                      onDelete: () => _deleteVoucher(doc.id),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF008C95),
            Color(0xFF18B7B5),
            Color(0xFFF4C95D),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            foregroundColor: Colors.white,
            child: const Icon(Icons.local_activity_outlined),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kho ưu đãi TravelHub',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total voucher đang được quản lý',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.card_giftcard_outlined,
            color: colors.onPrimary,
            size: 34,
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.status,
    required this.target,
    required this.onStatusChanged,
    required this.onTargetChanged,
  });

  final String status;
  final String target;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onTargetChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Choice(
          label: 'Tất cả',
          selected: status == 'all',
          onTap: () => onStatusChanged('all'),
        ),
        _Choice(
          label: 'Đang chạy',
          selected: status == 'active',
          onTap: () => onStatusChanged('active'),
        ),
        _Choice(
          label: 'Tạm tắt',
          selected: status == 'inactive',
          onTap: () => onStatusChanged('inactive'),
        ),
        _Choice(
          label: 'Hết hạn',
          selected: status == 'expired',
          onTap: () => onStatusChanged('expired'),
        ),
        _Choice(
          label: 'Đặt phòng',
          selected: target == 'booking',
          onTap: () => onTargetChanged(target == 'booking' ? 'all' : 'booking'),
        ),
        _Choice(
          label: 'Du lịch',
          selected: target == 'travelActivity',
          onTap: () => onTargetChanged(
            target == 'travelActivity' ? 'all' : 'travelActivity',
          ),
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onTap(),
      selectedColor: colors.primaryContainer,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w800,
        color: selected ? colors.onPrimaryContainer : colors.onSurface,
      ),
    );
  }
}

class _VoucherAdminCard extends StatelessWidget {
  const _VoucherAdminCard({
    required this.id,
    required this.data,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final String id;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final code = data['code'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final isActive = data['isActive'] as bool? ?? true;
    final endAt = _toDate(data['endAt']);
    final isExpired = endAt != null && endAt.isBefore(DateTime.now());

    final statusText = !isActive
        ? 'Tạm tắt'
        : isExpired
            ? 'Hết hạn'
            : 'Đang chạy';

    final statusColor = !isActive
        ? colors.outline
        : isExpired
            ? colors.error
            : const Color(0xFF008C72);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: statusColor.withValues(alpha: 0.12),
              foregroundColor: statusColor,
              child: const Icon(Icons.confirmation_number_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? 'Voucher chưa đặt tên' : title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    code,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoPill(
                        icon: Icons.flag_outlined,
                        label: _targetLabel(data['target'] as String?),
                      ),
                      _InfoPill(
                        icon: Icons.payments_outlined,
                        label: _discountText(data),
                      ),
                      _InfoPill(
                        icon: Icons.star_outline,
                        label: '${(data['pointsRequired'] as num?)?.toInt() ?? 0} điểm',
                      ),
                      _InfoPill(
                        icon: Icons.event_outlined,
                        label: endAt == null
                            ? 'Không hạn'
                            : 'Đến ${DateFormat('dd/MM/yyyy').format(endAt)}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                      case 'toggle':
                        onToggleActive();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Chỉnh sửa'),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(isActive ? 'Tạm tắt' : 'Bật lại'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Xóa'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 24),
      child: Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.primary,
            child: Icon(icon, size: 34),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

String _discountText(Map<String, dynamic> data) {
  final type = data['discountType'] as String? ?? 'percent';
  final value = (data['discountValue'] as num?)?.toDouble() ?? 0;

  if (type == 'fixedAmount') {
    return '${NumberFormat.decimalPattern('vi_VN').format(value.round())}đ';
  }

  return '${value.round()}%';
}

String _targetLabel(String? value) {
  return switch (value) {
    'booking' => 'Đặt phòng',
    'travelActivity' => 'Du lịch',
    _ => 'Tất cả',
  };
}

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}