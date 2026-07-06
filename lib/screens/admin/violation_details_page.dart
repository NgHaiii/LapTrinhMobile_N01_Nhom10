import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../model/violation_record.dart';
import '../../services/violation_service.dart';

class ViolationDetailsPage extends StatefulWidget {
  const ViolationDetailsPage({
    super.key,
    required this.violationId,
    this.service,
  });

  final String violationId;
  final ViolationService? service;

  @override
  State<ViolationDetailsPage> createState() =>
      _ViolationDetailsPageState();
}

class _ViolationDetailsPageState
    extends State<ViolationDetailsPage> {
  late final ViolationService _service;

  bool _processing = false;

  final NumberFormat _currency = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: 'đ',
    decimalDigits: 0,
  );

  final DateFormat _dateFormat = DateFormat(
    'HH:mm - dd/MM/yyyy',
    'vi_VN',
  );

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ViolationService();
  }

  Future<String?> _requestNote({
    required String title,
    required String label,
    required String hint,
    String initialValue = '',
    required String submitLabel,
    required IconData submitIcon,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdminNoteDialog(
        title: title,
        label: label,
        hint: hint,
        initialValue: initialValue,
        submitLabel: submitLabel,
        submitIcon: submitIcon,
      ),
    );
  }

  Future<void> _issue(
    ViolationRecord violation,
  ) async {
    await _execute(
      () => _service.issueDraft(violation.id),
      'Đã ban hành biên bản.',
    );
  }

  Future<void> _confirm(
    ViolationRecord violation,
  ) async {
    final note = await _requestNote(
      title: 'Quyết định phạt 5%',
      label: 'Kết luận của quản trị viên',
      hint:
          'Nêu kết quả xác minh, căn cứ xử lý và lý do áp dụng phạt...',
      initialValue: violation.adminNote,
      submitLabel: 'Phạt 5%',
      submitIcon: Icons.gavel_outlined,
    );

    if (!mounted || note == null) return;

    await _execute(
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
      label: 'Kết luận của quản trị viên',
      hint:
          'Nêu căn cứ chấp nhận giải trình và lý do không áp dụng phạt...',
      initialValue: violation.adminNote,
      submitLabel: 'Không phạt',
      submitIcon: Icons.verified_outlined,
    );

    if (!mounted || note == null) return;

    await _execute(
      () => _service.resolveWithoutPenalty(
        violationId: violation.id,
        adminNote: note,
      ),
      'Đã kết luận không áp dụng phạt. Biên bản vẫn được lưu.',
    );
  }

  Future<void> _cancel(
    ViolationRecord violation,
  ) async {
    final reason = await _requestNote(
      title: 'Hủy bản nháp',
      label: 'Lý do hủy',
      hint: 'Nêu rõ lý do hủy bản nháp...',
      submitLabel: 'Hủy bản nháp',
      submitIcon: Icons.delete_outline,
    );

    if (!mounted || reason == null) return;

    await _execute(
      () => _service.cancelViolation(
        violationId: violation.id,
        reason: reason,
      ),
      'Đã hủy bản nháp. Dữ liệu biên bản vẫn được lưu.',
    );
  }

  Future<void> _execute(
    Future<void> Function() operation,
    String successMessage,
  ) async {
    if (_processing) return;

    setState(() => _processing = true);

    try {
      await operation();

      if (!mounted) return;
      _message(successMessage);
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) {
        setState(() => _processing = false);
      }
    }
  }

  Future<void> _openEvidence(String value) async {
    final uri = Uri.tryParse(value.trim());

    if (uri == null ||
        !(uri.scheme == 'https' ||
            uri.scheme == 'http')) {
      _message('Liên kết bằng chứng không hợp lệ.');
      return;
    }

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!mounted) return;

      if (!opened) {
        _message('Không thể mở liên kết bằng chứng.');
      }
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
    return StreamBuilder<ViolationRecord?>(
      stream: _service.watchViolation(
        widget.violationId,
      ),
      builder: (context, snapshot) {
        final violation = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Chi tiết biên bản'),
          ),
          body: _buildBody(snapshot),
          bottomNavigationBar: violation == null
              ? null
              : _buildActionBar(violation),
        );
      },
    );
  }

  Widget _buildBody(
    AsyncSnapshot<ViolationRecord?> snapshot,
  ) {
    if (snapshot.connectionState ==
            ConnectionState.waiting &&
        !snapshot.hasData) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (snapshot.hasError) {
      return _ErrorState(
        message: _cleanError(snapshot.error),
      );
    }

    final violation = snapshot.data;

    if (violation == null) {
      return const _ErrorState(
        message:
            'Biên bản không tồn tại hoặc đã bị xóa.',
      );
    }

    final colors = Theme.of(context).colorScheme;
    final statusColor = _statusColor(violation.status);

    final baseCommission =
        violation.bookingAmount *
            violation.baseCommissionRate;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        130,
      ),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                      child: Text(
                        violation.title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.w900,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _StatusBadge(
                  label: ViolationStatus.label(
                    violation.status,
                  ),
                  color: statusColor,
                ),
                const SizedBox(height: 14),
                Text(
                  violation.description,
                  style: const TextStyle(height: 1.45),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _DecisionNotice(violation: violation),
        const SizedBox(height: 14),
        _Section(
          title: 'Thông tin liên quan',
          icon: Icons.receipt_long_outlined,
          children: [
            _InfoRow(
              label: 'Khách sạn',
              value: violation.hotelName,
            ),
            _InfoRow(
              label: 'Phòng',
              value: violation.roomNumber,
            ),
            _InfoRow(
              label: 'Khách hàng',
              value: violation.customerName,
            ),
            _InfoRow(
              label: 'Loại vi phạm',
              value: ViolationType.label(
                violation.violationType,
              ),
            ),
            _InfoRow(
              label: 'Mức độ',
              value: _severityLabel(
                violation.severity,
              ),
            ),
            _InfoRow(
              label: 'Mã đặt phòng',
              value: _shortId(
                violation.bookingId,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'Hoa hồng và khoản phạt',
          icon:
              Icons.account_balance_wallet_outlined,
          children: [
            _InfoRow(
              label: 'Giá trị đơn',
              value: _currency.format(
                violation.bookingAmount,
              ),
            ),
            _InfoRow(
              label:
                  'Hoa hồng cơ bản ${(violation.baseCommissionRate * 100).round()}%',
              value: _currency.format(baseCommission),
            ),
            _InfoRow(
              label: 'Mức phạt đề xuất 5%',
              value: _currency.format(
                violation.penaltyAmount,
              ),
              valueColor: colors.error,
            ),
            _InfoRow(
              label: 'Quyết định áp dụng',
              value: _penaltyDecision(violation),
              valueColor: violation.hasPenalty
                  ? colors.error
                  : violation.isNoPenalty
                      ? const Color(0xFF15803D)
                      : null,
            ),
            _InfoRow(
              label: 'Khoản phạt thực tế',
              value: _currency.format(
                violation.effectivePenaltyAmount,
              ),
              valueColor: violation.hasPenalty
                  ? colors.error
                  : const Color(0xFF15803D),
            ),
            _InfoRow(
              label: 'Đã tính vào hóa đơn',
              value: violation.commissionApplied
                  ? 'Có'
                  : 'Chưa',
            ),
            if (violation.commissionInvoiceId != null)
              _InfoRow(
                label: 'Mã hóa đơn',
                value: _shortId(
                  violation.commissionInvoiceId!,
                ),
              ),
          ],
        ),
        if (violation.evidenceUrls.isNotEmpty) ...[
          const SizedBox(height: 14),
          _Section(
            title: 'Bằng chứng',
            icon: Icons.attach_file_outlined,
            children: [
              for (
                var index = 0;
                index <
                    violation.evidenceUrls.length;
                index++
              )
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.link_outlined),
                  title:
                      Text('Bằng chứng ${index + 1}'),
                  subtitle: Text(
                    violation.evidenceUrls[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing:
                      const Icon(Icons.open_in_new),
                  onTap: () => _openEvidence(
                    violation.evidenceUrls[index],
                  ),
                ),
            ],
          ),
        ],
        if (violation
            .providerExplanation.isNotEmpty) ...[
          const SizedBox(height: 14),
          _TextSection(
            title: 'Giải trình của nhà cung cấp',
            icon: Icons.storefront_outlined,
            content:
                violation.providerExplanation,
          ),
        ],
        if (violation.appealNote.isNotEmpty) ...[
          const SizedBox(height: 14),
          _TextSection(
            title: 'Nội dung khiếu nại',
            icon: Icons.report_problem_outlined,
            content: violation.appealNote,
          ),
        ],
        if (violation.adminNote.isNotEmpty) ...[
          const SizedBox(height: 14),
          _TextSection(
            title: 'Kết luận của quản trị viên',
            icon:
                Icons.admin_panel_settings_outlined,
            content: violation.adminNote,
          ),
        ],
        const SizedBox(height: 14),
        _Section(
          title: 'Lịch sử thời gian',
          icon: Icons.history_outlined,
          children: [
            _InfoRow(
              label: 'Ngày tạo',
              value: _formatDate(
                violation.createdAt,
              ),
            ),
            if (violation.issuedAt != null)
              _InfoRow(
                label: 'Ngày ban hành',
                value: _formatDate(
                  violation.issuedAt,
                ),
              ),
            if (violation.confirmedAt != null)
              _InfoRow(
                label: 'Ngày quyết định phạt',
                value: _formatDate(
                  violation.confirmedAt,
                ),
              ),
            if (violation.resolvedAt != null)
              _InfoRow(
                label: 'Ngày hoàn tất',
                value: _formatDate(
                  violation.resolvedAt,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget? _buildActionBar(
    ViolationRecord violation,
  ) {
    final canIssue =
        violation.status == ViolationStatus.draft;

    final canDecide =
        (violation.status ==
                    ViolationStatus.investigating &&
                violation.hasProviderExplanation) ||
            violation.status ==
                ViolationStatus.appealed;

    final canCancel =
        violation.status == ViolationStatus.draft &&
            !violation.commissionApplied;

    if (!canIssue && !canDecide && !canCancel) {
      return null;
    }

    return SafeArea(
      top: false,
      child: Material(
        elevation: 10,
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (canCancel)
                OutlinedButton.icon(
                  onPressed: _processing
                      ? null
                      : () => _cancel(violation),
                  icon:
                      const Icon(Icons.close_outlined),
                  label:
                      const Text('Hủy bản nháp'),
                ),
              if (canIssue)
                FilledButton.tonalIcon(
                  onPressed: _processing
                      ? null
                      : () => _issue(violation),
                  icon:
                      const Icon(Icons.send_outlined),
                  label: const Text('Ban hành'),
                ),
              if (canDecide)
                OutlinedButton.icon(
                  onPressed: _processing
                      ? null
                      : () => _resolveWithoutPenalty(
                            violation,
                          ),
                  icon: const Icon(
                    Icons.verified_outlined,
                  ),
                  label: const Text('Không phạt'),
                ),
              if (canDecide)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .error,
                    foregroundColor: Theme.of(context)
                        .colorScheme
                        .onError,
                  ),
                  onPressed: _processing
                      ? null
                      : () => _confirm(violation),
                  icon: _processing
                      ? const SizedBox.square(
                          dimension: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.gavel_outlined,
                        ),
                  label: const Text('Phạt 5%'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Chưa có';
    return _dateFormat.format(value);
  }
}

class _AdminNoteDialog extends StatefulWidget {
  const _AdminNoteDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.submitLabel,
    required this.submitIcon,
  });

  final String title;
  final String label;
  final String hint;
  final String initialValue;
  final String submitLabel;
  final IconData submitIcon;

  @override
  State<_AdminNoteDialog> createState() =>
      _AdminNoteDialogState();
}

class _AdminNoteDialogState
    extends State<_AdminNoteDialog> {
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

  void _close() {
    FocusScope.of(context).unfocus();
    Navigator.of(context).pop();
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
      icon: const Icon(
        Icons.admin_panel_settings_outlined,
      ),
      title: Text(widget.title),
      scrollable: true,
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
            keyboardType: TextInputType.multiline,
            textInputAction:
                TextInputAction.newline,
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

              if (content.isEmpty) {
                return 'Vui lòng nhập nội dung kết luận.';
              }

              if (content.length < 5) {
                return 'Nội dung phải có ít nhất 5 ký tự.';
              }

              if (content.length > 1500) {
                return 'Nội dung không được vượt quá 1.500 ký tự.';
              }

              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _close,
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

class _DecisionNotice extends StatelessWidget {
  const _DecisionNotice({
    required this.violation,
  });

  final ViolationRecord violation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    late final Color color;
    late final IconData icon;
    late final String title;
    late final String message;

    if (violation.hasPenalty) {
      color = colors.error;
      icon = Icons.gavel_outlined;
      title = 'Đã quyết định phạt 5%';
      message =
          'Khoản phạt sẽ được cộng vào hóa đơn hoa hồng của nhà cung cấp.';
    } else if (violation.isNoPenalty) {
      color = const Color(0xFF15803D);
      icon = Icons.verified_outlined;
      title = 'Không áp dụng phạt';
      message =
          'Giải trình đã được chấp nhận. Biên bản vẫn được lưu để theo dõi.';
    } else if (violation.hasProviderExplanation) {
      color = const Color(0xFFD97706);
      icon = Icons.pending_actions_outlined;
      title = 'Đang chờ quyết định';
      message =
          'Nhà cung cấp đã giải trình. Quản trị viên cần chọn phạt hoặc không phạt.';
    } else {
      color = colors.primary;
      icon = Icons.hourglass_top_outlined;
      title = 'Chờ nhà cung cấp giải trình';
      message =
          'Chưa thể đưa ra quyết định trước khi có nội dung giải trình.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _TextSection extends StatelessWidget {
  const _TextSection({
    required this.title,
    required this.icon,
    required this.content,
  });

  final String title;
  final IconData icon;
  final String content;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: title,
      icon: icon,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            content,
            style: const TextStyle(height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
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
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
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
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 52,
            ),
            const SizedBox(height: 12),
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

String _penaltyDecision(
  ViolationRecord violation,
) {
  if (violation.hasPenalty) {
    return 'Áp dụng phạt 5%';
  }

  if (violation.isNoPenalty) {
    return 'Không áp dụng phạt';
  }

  return 'Chưa quyết định';
}

String _severityLabel(String severity) {
  return switch (severity) {
    'critical' => 'Nghiêm trọng',
    'high' => 'Mức cao',
    'warning' => 'Cần lưu ý',
    _ => 'Bình thường',
  };
}

String _shortId(String value) {
  final normalized = value.trim();

  if (normalized.isEmpty) return 'Không có';

  if (normalized.length <= 8) {
    return normalized.toUpperCase();
  }

  return normalized
      .substring(0, 8)
      .toUpperCase();
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}