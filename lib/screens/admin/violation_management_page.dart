import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../model/violation_record.dart';
import '../../services/violation_service.dart';
import 'violation_details_page.dart';

class ViolationManagementPage extends StatefulWidget {
  const ViolationManagementPage({
    super.key,
    this.service,
  });

  final ViolationService? service;

  @override
  State<ViolationManagementPage> createState() =>
      _ViolationManagementPageState();
}

class _ViolationManagementPageState
    extends State<ViolationManagementPage> {
  final TextEditingController _searchController =
      TextEditingController();

  late final ViolationService _service;

  String _search = '';
  String _status = 'all';
  String? _processingId;

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

  Future<String?> _requestNote({
    required String title,
    required String label,
    required String hint,
    required String submitLabel,
    required IconData submitIcon,
    String initialValue = '',
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DecisionNoteDialog(
        title: title,
        label: label,
        hint: hint,
        submitLabel: submitLabel,
        submitIcon: submitIcon,
        initialValue: initialValue,
      ),
    );
  }

  Future<void> _issue(
    ViolationRecord violation,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.send_outlined),
          title: const Text('Ban hành biên bản?'),
          content: const Text(
            'Biên bản sẽ được gửi cho nhà cung cấp giải trình. '
            'Chưa có khoản phạt nào được áp dụng tại bước này.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Quay lại'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.send_outlined),
              label: const Text('Ban hành'),
            ),
          ],
        );
      },
    );

    if (!mounted || accepted != true) return;

    await _execute(
      violation.id,
      () => _service.issueDraft(violation.id),
      'Đã gửi biên bản cho nhà cung cấp.',
    );
  }

  Future<void> _applyPenalty(
    ViolationRecord violation,
  ) async {
    final note = await _requestNote(
      title: 'Quyết định phạt 5%',
      label: 'Kết luận xác minh',
      hint:
          'Nêu kết quả xác minh, căn cứ và lý do áp dụng khoản phạt...',
      submitLabel: 'Phạt 5%',
      submitIcon: Icons.gavel_outlined,
      initialValue: violation.adminNote,
    );

    if (!mounted || note == null) return;

    await _execute(
      violation.id,
      () => _service.confirmViolation(
        violationId: violation.id,
        adminNote: note,
      ),
      'Đã quyết định phạt 5%. Khoản phạt sẽ được cộng vào hóa đơn hoa hồng.',
    );
  }

  Future<void> _resolveWithoutPenalty(
    ViolationRecord violation,
  ) async {
    final note = await _requestNote(
      title: 'Không áp dụng phạt',
      label: 'Kết luận xác minh',
      hint:
          'Nêu căn cứ chấp nhận giải trình và lý do không áp dụng phạt...',
      submitLabel: 'Không phạt',
      submitIcon: Icons.verified_outlined,
      initialValue: violation.adminNote,
    );

    if (!mounted || note == null) return;

    await _execute(
      violation.id,
      () => _service.resolveWithoutPenalty(
        violationId: violation.id,
        adminNote: note,
      ),
      'Đã kết luận không áp dụng phạt. Biên bản vẫn được lưu.',
    );
  }

  Future<void> _cancelDraft(
    ViolationRecord violation,
  ) async {
    final note = await _requestNote(
      title: 'Hủy bản nháp',
      label: 'Lý do hủy',
      hint: 'Nêu lý do không ban hành bản nháp này...',
      submitLabel: 'Hủy bản nháp',
      submitIcon: Icons.delete_outline,
    );

    if (!mounted || note == null) return;

    await _execute(
      violation.id,
      () => _service.cancelViolation(
        violationId: violation.id,
        reason: note,
      ),
      'Đã hủy bản nháp.',
    );
  }

  Future<void> _execute(
    String violationId,
    Future<void> Function() operation,
    String successMessage,
  ) async {
    if (_processingId != null) return;

    setState(() => _processingId = violationId);

    try {
      await operation();

      if (!mounted) return;
      _message(successMessage);
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _processingId = null);
      }
    }
  }

  Future<void> _openDetails(
    ViolationRecord violation,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ViolationDetailsPage(
          violationId: violation.id,
          service: _service,
        ),
      ),
    );
  }

  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _search = '';
      _status = 'all';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biên bản vi phạm'),
      ),
      body: StreamBuilder<List<ViolationRecord>>(
        stream: _service.watchAllViolations(),
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
              .toList()
            ..sort(_compareViolations);

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
                    title: 'Không có biên bản phù hợp',
                    message:
                        'Hãy thay đổi từ khóa hoặc trạng thái lọc.',
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

                      final processing =
                          _processingId == violation.id;

                      return _ViolationCard(
                        violation: violation,
                        currency: _currency,
                        processing: processing,
                        onView: () {
                          _openDetails(violation);
                        },
                        onIssue: violation.isDraft
                            ? () => _issue(violation)
                            : null,
                        onCancelDraft: violation.isDraft
                            ? () => _cancelDraft(violation)
                            : null,
                        onApplyPenalty:
                            _canDecide(violation)
                                ? () => _applyPenalty(
                                      violation,
                                    )
                                : null,
                        onNoPenalty: _canDecide(violation)
                            ? () => _resolveWithoutPenalty(
                                  violation,
                                )
                            : null,
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    List<ViolationRecord> violations,
    int resultCount,
  ) {
    final colors = Theme.of(context).colorScheme;

    final waiting = violations.where((item) {
      return item.status ==
              ViolationStatus.waitingProvider ||
          item.status ==
              ViolationStatus.investigating ||
          item.status == ViolationStatus.appealed;
    }).length;

    final penalized = violations.where((item) {
      return item.status == ViolationStatus.confirmed ||
          item.status == ViolationStatus.paid;
    }).length;

    final noPenalty = violations.where((item) {
      return item.status == ViolationStatus.noPenalty;
    }).length;

    final totalPenalty = violations
        .where((item) => item.hasPenalty)
        .fold<double>(
          0,
          (total, item) =>
              total + item.penaltyAmount,
        );

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
          LayoutBuilder(
            builder: (context, constraints) {
              final width =
                  (constraints.maxWidth - 10) / 2;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width,
                    child: _SummaryItem(
                      icon:
                          Icons.pending_actions_outlined,
                      label: 'Chờ quyết định',
                      value: '$waiting',
                      color: const Color(0xFFD97706),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _SummaryItem(
                      icon: Icons.gavel_outlined,
                      label: 'Đã phạt',
                      value: '$penalized',
                      color: const Color(0xFFB3261E),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _SummaryItem(
                      icon: Icons.verified_outlined,
                      label: 'Không phạt',
                      value: '$noPenalty',
                      color: const Color(0xFF15803D),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _SummaryItem(
                      icon: Icons.payments_outlined,
                      label: 'Tổng tiền phạt',
                      value: _currency.format(
                        totalPenalty,
                      ),
                      color: colors.primary,
                      smallValue: true,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          SearchBar(
            controller: _searchController,
            hintText:
                'Tìm khách sạn, phòng, khách hàng...',
            leading: const Icon(Icons.search_rounded),
            onChanged: (value) {
              setState(() => _search = value);
            },
            trailing: [
              if (_search.isNotEmpty)
                IconButton(
                  tooltip: 'Xóa tìm kiếm',
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
              labelText: 'Trạng thái biên bản',
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
          Row(
            children: [
              Expanded(
                child: Text(
                  '$resultCount biên bản phù hợp',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_search.isNotEmpty ||
                  _status != 'all')
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(
                    Icons.filter_alt_off_outlined,
                  ),
                  label: const Text('Xóa lọc'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  bool _canDecide(ViolationRecord violation) {
    return (violation.status ==
                ViolationStatus.investigating &&
            violation.hasProviderExplanation) ||
        violation.status == ViolationStatus.appealed;
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
        violation.customerName
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

class _DecisionNoteDialog extends StatefulWidget {
  const _DecisionNoteDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.submitLabel,
    required this.submitIcon,
    required this.initialValue,
  });

  final String title;
  final String label;
  final String hint;
  final String submitLabel;
  final IconData submitIcon;
  final String initialValue;

  @override
  State<_DecisionNoteDialog> createState() =>
      _DecisionNoteDialogState();
}

class _DecisionNoteDialogState
    extends State<_DecisionNoteDialog> {
  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: widget.initialValue,
    );
  }

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
      icon: const Icon(
        Icons.admin_panel_settings_outlined,
      ),
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            minLines: 4,
            maxLines: 8,
            maxLength: 1500,
            textCapitalization:
                TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
              alignLabelWithHint: true,
            ),
            validator: (value) {
              final content =
                  value?.trim() ?? '';

              if (content.length < 5) {
                return 'Nội dung phải có ít nhất 5 ký tự.';
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
          icon: Icon(widget.submitIcon),
          label: Text(widget.submitLabel),
        ),
      ],
    );
  }
}

class _ViolationCard extends StatelessWidget {
  const _ViolationCard({
    required this.violation,
    required this.currency,
    required this.processing,
    required this.onView,
    this.onIssue,
    this.onCancelDraft,
    this.onApplyPenalty,
    this.onNoPenalty,
  });

  final ViolationRecord violation;
  final NumberFormat currency;
  final bool processing;
  final VoidCallback onView;
  final VoidCallback? onIssue;
  final VoidCallback? onCancelDraft;
  final VoidCallback? onApplyPenalty;
  final VoidCallback? onNoPenalty;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor =
        _statusColor(violation.status);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: processing ? null : onView,
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
                    child: const Icon(
                      Icons.gavel_outlined,
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
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusBadge(
                    label: ViolationStatus.label(
                      violation.status,
                    ),
                    color: statusColor,
                  ),
                  _StatusBadge(
                    label: ViolationType.label(
                      violation.violationType,
                    ),
                    color: colors.primary,
                  ),
                ],
              ),
              const Divider(height: 24),
              _InformationRow(
                label: 'Khách hàng',
                value: violation.customerName,
              ),
              _InformationRow(
                label: 'Giá trị đơn',
                value: currency.format(
                  violation.bookingAmount,
                ),
              ),
              _InformationRow(
                label: violation.isNoPenalty
                    ? 'Quyết định'
                    : 'Phụ thu 5%',
                value: violation.isNoPenalty
                    ? 'Không áp dụng phạt'
                    : currency.format(
                        violation.penaltyAmount,
                      ),
                valueColor: violation.isNoPenalty
                    ? const Color(0xFF15803D)
                    : colors.error,
              ),
              if (violation
                  .hasProviderExplanation) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color:
                        colors.surfaceContainerLow,
                    borderRadius:
                        BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.outlineVariant,
                    ),
                  ),
                  child: Text(
                    violation.providerExplanation,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (processing) ...[
                const SizedBox(height: 13),
                const LinearProgressIndicator(),
              ] else if (onIssue != null ||
                  onApplyPenalty != null ||
                  onNoPenalty != null) ...[
                const Divider(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    if (onCancelDraft != null)
                      TextButton.icon(
                        onPressed: onCancelDraft,
                        icon: const Icon(
                          Icons.delete_outline,
                        ),
                        label: const Text(
                          'Hủy bản nháp',
                        ),
                      ),
                    if (onIssue != null)
                      FilledButton.tonalIcon(
                        onPressed: onIssue,
                        icon: const Icon(
                          Icons.send_outlined,
                        ),
                        label:
                            const Text('Ban hành'),
                      ),
                    if (onNoPenalty != null)
                      OutlinedButton.icon(
                        onPressed: onNoPenalty,
                        icon: const Icon(
                          Icons.verified_outlined,
                        ),
                        label:
                            const Text('Không phạt'),
                      ),
                    if (onApplyPenalty != null)
                      FilledButton.icon(
                        onPressed: onApplyPenalty,
                        icon: const Icon(
                          Icons.gavel_outlined,
                        ),
                        label:
                            const Text('Phạt 5%'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.smallValue = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool smallValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 100,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.23),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize:
                        smallValue ? 15 : 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontWeight: FontWeight.w800,
              ),
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
              textAlign: TextAlign.center,
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

int _compareViolations(
  ViolationRecord first,
  ViolationRecord second,
) {
  final priority = _statusPriority(second.status)
      .compareTo(_statusPriority(first.status));

  if (priority != 0) return priority;

  final firstDate = first.updatedAt ??
      first.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  final secondDate = second.updatedAt ??
      second.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);

  return secondDate.compareTo(firstDate);
}

int _statusPriority(String status) {
  return switch (status) {
    ViolationStatus.appealed => 7,
    ViolationStatus.investigating => 6,
    ViolationStatus.waitingProvider => 5,
    ViolationStatus.draft => 4,
    ViolationStatus.confirmed => 3,
    ViolationStatus.noPenalty => 2,
    ViolationStatus.paid => 1,
    _ => 0,
  };
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