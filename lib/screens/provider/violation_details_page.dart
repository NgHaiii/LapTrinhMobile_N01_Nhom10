import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../model/violation_record.dart';
import '../../services/violation_service.dart';

class ProviderViolationDetailsPage
    extends StatefulWidget {
  const ProviderViolationDetailsPage({
    super.key,
    required this.violationId,
    this.service,
  });

  final String violationId;
  final ViolationService? service;

  @override
  State<ProviderViolationDetailsPage> createState() =>
      _ProviderViolationDetailsPageState();
}

class _ProviderViolationDetailsPageState
    extends State<ProviderViolationDetailsPage> {
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

  Future<String?> _requestContent({
    required String title,
    required String label,
    required String hint,
    String initialValue = '',
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProviderResponseDialog(
        title: title,
        label: label,
        hint: hint,
        initialValue: initialValue,
      ),
    );
  }

  Future<void> _submitExplanation(
    ViolationRecord violation,
  ) async {
    final content = await _requestContent(
      title: violation.hasProviderExplanation
          ? 'Cập nhật giải trình'
          : 'Gửi giải trình',
      label: 'Nội dung giải trình',
      hint:
          'Trình bày sự việc, nguyên nhân và hướng khắc phục...',
      initialValue:
          violation.providerExplanation,
    );

    if (!mounted || content == null) return;

    await _execute(
      () => _service.submitProviderExplanation(
        violationId: violation.id,
        explanation: content,
      ),
      'Đã gửi giải trình đến quản trị viên.',
    );
  }

  Future<void> _submitAppeal(
    ViolationRecord violation,
  ) async {
    final content = await _requestContent(
      title: 'Khiếu nại quyết định phạt',
      label: 'Nội dung khiếu nại',
      hint:
          'Nêu lý do không đồng ý với quyết định phạt...',
      initialValue: violation.appealNote,
    );

    if (!mounted || content == null) return;

    await _execute(
      () => _service.submitAppeal(
        violationId: violation.id,
        appealNote: content,
      ),
      'Đã gửi khiếu nại đến quản trị viên.',
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
        _message('Không thể mở liên kết.');
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
              : _buildActions(violation),
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
        message: 'Không tìm thấy biên bản.',
      );
    }

    final colors = Theme.of(context).colorScheme;
    final statusColor =
        _statusColor(violation.status);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        120,
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
        const SizedBox(height: 12),
        _ProviderDecisionNotice(
          violation: violation,
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'Thông tin biên bản',
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
              label: 'Loại vi phạm',
              value: ViolationType.label(
                violation.violationType,
              ),
            ),
            _InfoRow(
              label: 'Mã đặt phòng',
              value: _shortId(
                violation.bookingId,
              ),
            ),
            _InfoRow(
              label: 'Ngày ban hành',
              value: _formatDate(
                violation.issuedAt,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'Thông tin khoản phạt',
          icon: Icons.payments_outlined,
          children: [
            _InfoRow(
              label: 'Giá trị đơn',
              value: _currency.format(
                violation.bookingAmount,
              ),
            ),
            _InfoRow(
              label: 'Mức phạt đề xuất',
              value: _currency.format(
                violation.penaltyAmount,
              ),
            ),
            _InfoRow(
              label: 'Quyết định',
              value: _decisionText(violation),
              valueColor: violation.isNoPenalty
                  ? const Color(0xFF15803D)
                  : violation.hasPenalty
                      ? colors.error
                      : null,
            ),
            _InfoRow(
              label: 'Số tiền phải trả',
              value: _currency.format(
                violation.effectivePenaltyAmount,
              ),
              valueColor: violation.isNoPenalty
                  ? const Color(0xFF15803D)
                  : violation.hasPenalty
                      ? colors.error
                      : null,
            ),
            _InfoRow(
              label: 'Đã vào hóa đơn',
              value: violation.commissionApplied
                  ? 'Có'
                  : 'Chưa',
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
            title: 'Giải trình của bạn',
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
      ],
    );
  }

  Widget? _buildActions(
    ViolationRecord violation,
  ) {
    final canExplain =
        violation.canProviderExplain;

    final canAppeal =
        violation.canProviderAppeal;

    if (!canExplain && !canAppeal) return null;

    return SafeArea(
      top: false,
      child: Material(
        elevation: 10,
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: canExplain
                ? FilledButton.icon(
                    onPressed: _processing
                        ? null
                        : () => _submitExplanation(
                              violation,
                            ),
                    icon: _processing
                        ? const SizedBox.square(
                            dimension: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.chat_outlined,
                          ),
                    label: Text(
                      violation.hasProviderExplanation
                          ? 'Cập nhật giải trình'
                          : 'Gửi giải trình',
                    ),
                  )
                : OutlinedButton.icon(
                    onPressed: _processing
                        ? null
                        : () => _submitAppeal(
                              violation,
                            ),
                    icon: const Icon(
                      Icons.report_problem_outlined,
                    ),
                    label:
                        const Text('Khiếu nại'),
                  ),
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

class _ProviderResponseDialog
    extends StatefulWidget {
  const _ProviderResponseDialog({
    required this.title,
    required this.label,
    required this.hint,
    required this.initialValue,
  });

  final String title;
  final String label;
  final String hint;
  final String initialValue;

  @override
  State<_ProviderResponseDialog> createState() =>
      _ProviderResponseDialogState();
}

class _ProviderResponseDialogState
    extends State<_ProviderResponseDialog> {
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
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _controller,
            autofocus: true,
            minLines: 5,
            maxLines: 10,
            maxLength: 2000,
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

              if (content.length < 10) {
                return 'Nội dung phải có ít nhất 10 ký tự.';
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
          icon: const Icon(Icons.send_outlined),
          label: const Text('Gửi'),
        ),
      ],
    );
  }
}

class _ProviderDecisionNotice
    extends StatelessWidget {
  const _ProviderDecisionNotice({
    required this.violation,
  });

  final ViolationRecord violation;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final IconData icon;
    late final String title;
    late final String message;

    if (violation.isNoPenalty) {
      color = const Color(0xFF15803D);
      icon = Icons.verified_outlined;
      title = 'Không áp dụng phạt';
      message =
          'Quản trị viên đã chấp nhận giải trình. Bạn không phải thanh toán khoản phạt này.';
    } else if (violation.hasPenalty) {
      color = Theme.of(context).colorScheme.error;
      icon = Icons.gavel_outlined;
      title = 'Đã quyết định phạt 5%';
      message =
          'Khoản phạt sẽ được cộng vào hóa đơn hoa hồng.';
    } else if (violation.status ==
        ViolationStatus.investigating) {
      color = const Color(0xFF2563EB);
      icon = Icons.manage_search_outlined;
      title = 'Đang chờ quyết định';
      message =
          'Quản trị viên đang xem xét nội dung giải trình.';
    } else {
      color = const Color(0xFFD97706);
      icon = Icons.pending_actions_outlined;
      title = 'Cần gửi giải trình';
      message =
          'Vui lòng gửi nội dung giải trình để quản trị viên xem xét.';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.24),
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
                Text(message),
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
                Icon(icon),
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
            width: 125,
            child: Text(label),
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
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

String _decisionText(
  ViolationRecord violation,
) {
  if (violation.isNoPenalty) {
    return 'Không áp dụng phạt';
  }

  if (violation.hasPenalty) {
    return 'Phạt 5%';
  }

  return 'Chưa quyết định';
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

String _shortId(String value) {
  if (value.length <= 8) return value.toUpperCase();
  return value.substring(0, 8).toUpperCase();
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}