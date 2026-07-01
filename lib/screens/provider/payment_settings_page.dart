import 'package:flutter/material.dart';

import '../../model/provider_payment_profile.dart';
import '../../model/vietqr_bank.dart';
import '../../services/provider_payment_service.dart';

class ProviderPaymentSettingsPage extends StatefulWidget {
  const ProviderPaymentSettingsPage({super.key});

  @override
  State<ProviderPaymentSettingsPage> createState() =>
      _ProviderPaymentSettingsPageState();
}

class _ProviderPaymentSettingsPageState
    extends State<ProviderPaymentSettingsPage> {
  final ProviderPaymentService _service =
      ProviderPaymentService();

  Future<void> _openForm(
    ProviderPaymentProfile? profile,
  ) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _PaymentProfileForm(
          service: _service,
          profile: profile,
        ),
      ),
    );

    if (!mounted || saved != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Đã gửi thông tin ngân hàng. '
          'Vui lòng chờ admin xác minh.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tài khoản nhận tiền'),
      ),
      body: StreamBuilder<ProviderPaymentProfile?>(
        stream: _service.watchMyProfile(),
        builder: (context, snapshot) {
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

          final profile = snapshot.data;

          if (profile == null ||
              !profile.hasBankInformation) {
            return _EmptyProfile(
              onCreate: () => _openForm(profile),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              32,
            ),
            children: [
              _VerificationStatus(profile: profile),
              const SizedBox(height: 16),
              _BankAccountCard(profile: profile),
              if (profile.rejectionReason.isNotEmpty) ...[
                const SizedBox(height: 12),
                _RejectionNotice(
                  reason: profile.rejectionReason,
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _openForm(profile),
                icon: const Icon(Icons.edit_outlined),
                label: Text(
                  profile.isVerified
                      ? 'Thay đổi tài khoản'
                      : 'Chỉnh sửa thông tin',
                ),
              ),
              if (profile.isVerified) ...[
                const SizedBox(height: 10),
                Text(
                  'Khi thay đổi tài khoản, trạng thái xác minh '
                  'sẽ được đặt lại và admin phải duyệt lại.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PaymentProfileForm extends StatefulWidget {
  const _PaymentProfileForm({
    required this.service,
    this.profile,
  });

  final ProviderPaymentService service;
  final ProviderPaymentProfile? profile;

  @override
  State<_PaymentProfileForm> createState() =>
      _PaymentProfileFormState();
}

class _PaymentProfileFormState
    extends State<_PaymentProfileForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _accountController;
  late final TextEditingController _accountNameController;
  late final Future<List<VietQrBank>> _banksFuture;

  VietQrBank? _selectedBank;
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    _accountController = TextEditingController(
      text: widget.profile?.accountNumber ?? '',
    );

    _accountNameController = TextEditingController(
      text: widget.profile?.accountName ?? '',
    );

    _banksFuture = _loadBanks();
  }

  Future<List<VietQrBank>> _loadBanks() async {
    final banks = await widget.service.getBanks();

    final oldBankBin = widget.profile?.bankBin ?? '';

    if (oldBankBin.isNotEmpty) {
      for (final bank in banks) {
        if (bank.bin == oldBankBin) {
          _selectedBank = bank;
          break;
        }
      }
    }

    return banks;
  }

  Future<void> _save() async {
    if (_saving ||
        !_formKey.currentState!.validate()) {
      return;
    }

    final bank = _selectedBank;

    if (bank == null) {
      _message('Vui lòng chọn ngân hàng.');
      return;
    }

    setState(() => _saving = true);

    try {
      await widget.service.submitPaymentProfile(
        bank: bank,
        accountNumber: _accountController.text,
        accountName: _accountNameController.text,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateAccountNumber(String? value) {
    final normalized = value
        ?.replaceAll(RegExp(r'\s+'), '') ??
        '';

    if (normalized.isEmpty) {
      return 'Vui lòng nhập số tài khoản';
    }

    if (!RegExp(r'^[0-9]{6,19}$').hasMatch(normalized)) {
      return 'Số tài khoản phải gồm 6-19 chữ số';
    }

    return null;
  }

  String? _validateAccountName(String? value) {
    final name = value?.trim() ?? '';

    if (name.length < 2) {
      return 'Tên chủ tài khoản không hợp lệ';
    }

    return null;
  }

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(value)),
      );
  }

  @override
  void dispose() {
    _accountController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông tin ngân hàng'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            16,
            20,
            110,
          ),
          children: [
            Text(
              'Tài khoản nhận thanh toán',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Khách hàng sẽ chuyển tiền trực tiếp '
              'vào tài khoản này bằng VietQR.',
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<VietQrBank>>(
              future: _banksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _BankLoadError(
                    message: _cleanError(snapshot.error),
                  );
                }

                final banks = snapshot.data ?? [];

                if (banks.isEmpty) {
                  return const _BankLoadError(
                    message:
                        'Không tải được danh sách ngân hàng.',
                  );
                }

                final selectedBank =
                    banks.contains(_selectedBank)
                    ? _selectedBank
                    : null;

                return DropdownButtonFormField<VietQrBank>(
                  initialValue: selectedBank,
                  isExpanded: true,
                  validator: (value) {
                    return value == null
                        ? 'Vui lòng chọn ngân hàng'
                        : null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Ngân hàng',
                    prefixIcon: Icon(
                      Icons.account_balance_outlined,
                    ),
                  ),
                  items: banks.map((bank) {
                    return DropdownMenuItem<VietQrBank>(
                      value: bank,
                      child: Row(
                        children: [
                          if (bank.logo.isNotEmpty) ...[
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: Image.network(
                                bank.logo,
                                errorBuilder: (_, __, ___) {
                                  return const Icon(
                                    Icons.account_balance,
                                    size: 20,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 9),
                          ],
                          Expanded(
                            child: Text(
                              bank.displayName,
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedBank = value);
                  },
                );
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _accountController,
              validator: _validateAccountNumber,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Số tài khoản',
                prefixIcon: Icon(
                  Icons.numbers_rounded,
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _accountNameController,
              validator: _validateAccountName,
              textCapitalization:
                  TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Tên chủ tài khoản',
                hintText: 'NGUYEN VAN A',
                prefixIcon: Icon(
                  Icons.badge_outlined,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _SecurityNotice(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            12,
          ),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.verified_user_outlined),
            label: Text(
              _saving
                  ? 'Đang gửi...'
                  : 'Gửi thông tin xác minh',
            ),
          ),
        ),
      ),
    );
  }
}

class _VerificationStatus extends StatelessWidget {
  const _VerificationStatus({required this.profile});

  final ProviderPaymentProfile profile;

  @override
  Widget build(BuildContext context) {
    final color = switch (profile.verificationStatus) {
      PaymentProfileStatus.approved => Colors.green,
      PaymentProfileStatus.pending => Colors.orange,
      PaymentProfileStatus.rejected => Colors.red,
      _ => Colors.grey,
    };

    final icon = switch (profile.verificationStatus) {
      PaymentProfileStatus.approved =>
        Icons.verified_rounded,
      PaymentProfileStatus.pending =>
        Icons.hourglass_top_rounded,
      PaymentProfileStatus.rejected =>
        Icons.error_outline_rounded,
      _ => Icons.info_outline_rounded,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.30),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          profile.statusLabel,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          profile.canReceivePayments
              ? 'Tài khoản có thể nhận thanh toán VietQR.'
              : 'Tài khoản chưa thể nhận thanh toán.',
        ),
      ),
    );
  }
}

class _BankAccountCard extends StatelessWidget {
  const _BankAccountCard({required this.profile});

  final ProviderPaymentProfile profile;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(
              Icons.account_balance_rounded,
              size: 42,
            ),
            const SizedBox(height: 10),
            Text(
              profile.bankName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            _DetailRow(
              label: 'Số tài khoản',
              value: profile.maskedAccountNumber,
            ),
            _DetailRow(
              label: 'Chủ tài khoản',
              value: profile.accountName,
            ),
            _DetailRow(
              label: 'Mã ngân hàng',
              value: profile.bankCode,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyProfile extends StatelessWidget {
  const _EmptyProfile({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_outlined,
              size: 64,
            ),
            const SizedBox(height: 14),
            const Text(
              'Chưa có tài khoản nhận tiền',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Cập nhật tài khoản ngân hàng để có thể '
              'xác nhận booking và nhận tiền bằng VietQR.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm tài khoản'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RejectionNotice extends StatelessWidget {
  const _RejectionNotice({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          Icons.error_outline_rounded,
          color: color,
        ),
        title: const Text('Lý do từ chối'),
        subtitle: Text(reason),
      ),
    );
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          Icons.security_rounded,
          color: colors.onSecondaryContainer,
        ),
        title: const Text(
          'Bảo mật tài khoản',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: const Text(
          'Chỉ cung cấp thông tin nhận tiền. '
          'Không nhập mật khẩu, mã PIN hoặc OTP.',
        ),
      ),
    );
  }
}

class _BankLoadError extends StatelessWidget {
  const _BankLoadError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Bad state: ', '')
      .replaceFirst('Exception: ', '');
}