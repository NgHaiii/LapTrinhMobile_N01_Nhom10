import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../model/provider_application.dart';
import '../../services/provider_application_service.dart';

class ProviderApplicationScreen extends StatefulWidget {
  const ProviderApplicationScreen({super.key});

  @override
  State<ProviderApplicationScreen> createState() =>
      _ProviderApplicationScreenState();
}

class _ProviderApplicationScreenState extends State<ProviderApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessController = TextEditingController();
  final _representativeController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _identityController = TextEditingController();

  final _service = ProviderApplicationService();
  final _picker = ImagePicker();

  XFile? _identityFront;
  XFile? _identityBack;
  XFile? _businessLicense;

  bool _isSubmitting = false;
  bool _editRejectedApplication = false;

  Future<void> _pickDocument(String type) async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );

    if (image == null || !mounted) return;

    setState(() {
      switch (type) {
        case 'front':
          _identityFront = image;
        case 'back':
          _identityBack = image;
        case 'license':
          _businessLicense = image;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_identityFront == null ||
        _identityBack == null ||
        _businessLicense == null) {
      _showMessage('Vui lòng cung cấp đầy đủ ba ảnh giấy tờ.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _service.submit(
        businessName: _businessController.text,
        representativeName: _representativeController.text,
        phoneNumber: _phoneController.text,
        address: _addressController.text,
        identityNumber: _identityController.text,
        identityFront: _identityFront!,
        identityBack: _identityBack!,
        businessLicense: _businessLicense!,
      );

      if (!mounted) return;
      _showMessage('Đã gửi hồ sơ. Vui lòng chờ quản trị viên xét duyệt.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _businessController.dispose();
    _representativeController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _identityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProviderApplication?>(
      stream: _service.watchMyApplication(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final application = snapshot.data;

        if (application != null &&
            application.status != ApplicationStatus.rejected) {
          return _StatusScreen(application: application);
        }

        if (application?.status == ApplicationStatus.rejected &&
            !_editRejectedApplication) {
          return _RejectedScreen(
            reason: application!.rejectionReason,
            onEdit: () => setState(() => _editRejectedApplication = true),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Đăng ký nhà cung cấp')),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(
                  'Thông tin kinh doanh',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Thông tin chính xác giúp hồ sơ được xét duyệt nhanh hơn.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                _field(
                  controller: _businessController,
                  label: 'Tên khách sạn hoặc doanh nghiệp',
                  icon: Icons.storefront_outlined,
                ),
                _field(
                  controller: _representativeController,
                  label: 'Người đại diện',
                  icon: Icons.person_outline,
                ),
                _field(
                  controller: _phoneController,
                  label: 'Số điện thoại',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                _field(
                  controller: _addressController,
                  label: 'Địa chỉ kinh doanh',
                  icon: Icons.location_on_outlined,
                  maxLines: 2,
                ),
                _field(
                  controller: _identityController,
                  label: 'CCCD/CMND người đại diện',
                  icon: Icons.badge_outlined,
                ),
                const SizedBox(height: 8),
                Text(
                  'Giấy tờ xác minh',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                _DocumentTile(
                  title: 'Mặt trước CCCD/CMND',
                  file: _identityFront,
                  onTap: () => _pickDocument('front'),
                ),
                _DocumentTile(
                  title: 'Mặt sau CCCD/CMND',
                  file: _identityBack,
                  onTap: () => _pickDocument('back'),
                ),
                _DocumentTile(
                  title: 'Giấy phép kinh doanh',
                  file: _businessLicense,
                  onTap: () => _pickDocument('license'),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting ? 'Đang gửi hồ sơ...' : 'Gửi xét duyệt',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        validator: (value) {
          if ((value?.trim().length ?? 0) < 2) {
            return 'Vui lòng nhập $label';
          }
          return null;
        },
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.title,
    required this.file,
    required this.onTap,
  });

  final String title;
  final XFile? file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = file != null;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? colors.primaryContainer : colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: ListTile(
          onTap: onTap,
          leading: Icon(
            selected ? Icons.check_circle_rounded : Icons.upload_file_rounded,
            color: selected ? colors.primary : colors.onSurfaceVariant,
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(file?.name ?? 'Chọn ảnh từ thiết bị'),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      ),
    );
  }
}

class _StatusScreen extends StatelessWidget {
  const _StatusScreen({required this.application});

  final ProviderApplication application;

  @override
  Widget build(BuildContext context) {
    final approved = application.status == ApplicationStatus.approved;

    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ nhà cung cấp')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                approved ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                size: 68,
                color: approved
                    ? Colors.green
                    : Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(height: 18),
              Text(
                approved ? 'Hồ sơ đã được duyệt' : 'Đang chờ xét duyệt',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                approved
                    ? 'Tài khoản của bạn đã trở thành nhà cung cấp.'
                    : 'Quản trị viên đang kiểm tra thông tin và giấy tờ.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RejectedScreen extends StatelessWidget {
  const _RejectedScreen({required this.reason, required this.onEdit});

  final String reason;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hồ sơ nhà cung cấp')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cancel_outlined,
                size: 68,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 18),
              Text(
                'Hồ sơ chưa được chấp thuận',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                reason.isEmpty ? 'Thông tin chưa hợp lệ.' : reason,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Chỉnh sửa và gửi lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
