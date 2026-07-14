import 'package:flutter/material.dart';

import '../../../services/profile_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({
    super.key,
    this.service,
  });

  final ProfileService? service;

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  late final ProfileService _service;

  bool _bookingUpdates = true;
  bool _promotions = true;
  bool _travelSuggestions = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ProfileService();
  }

  Future<void> _save() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      await _service.updateNotificationSettings(
        bookingUpdates: _bookingUpdates,
        promotions: _promotions,
        travelSuggestions: _travelSuggestions,
      );

      if (!mounted) return;
      _message('Đã lưu cài đặt thông báo.');
    } catch (error) {
      if (!mounted) return;
      _message(_cleanError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF9),
      appBar: AppBar(
        title: const Text('Thông báo'),
        backgroundColor: const Color(0xFFF4FAF9),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          const _HeroCard(
            icon: Icons.notifications_rounded,
            title: 'Tùy chỉnh thông báo',
            subtitle:
                'Chọn những cập nhật bạn muốn nhận từ TravelHub.',
          ),
          const SizedBox(height: 18),
          DecoratedBox(
            decoration: _cardDecoration(),
            child: Column(
              children: [
                SwitchListTile(
                  value: _bookingUpdates,
                  onChanged: (value) {
                    setState(() => _bookingUpdates = value);
                  },
                  secondary: const Icon(Icons.event_note_outlined),
                  title: const Text('Cập nhật đơn đặt phòng'),
                  subtitle: const Text('Thông báo xác nhận, thanh toán và lịch nhận phòng.'),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _promotions,
                  onChanged: (value) {
                    setState(() => _promotions = value);
                  },
                  secondary: const Icon(Icons.confirmation_number_outlined),
                  title: const Text('Ưu đãi và voucher'),
                  subtitle: const Text('Nhận thông báo khi có khuyến mại mới.'),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _travelSuggestions,
                  onChanged: (value) {
                    setState(() => _travelSuggestions = value);
                  },
                  secondary: const Icon(Icons.explore_outlined),
                  title: const Text('Gợi ý du lịch'),
                  subtitle: const Text('Gợi ý địa điểm và hoạt động phù hợp.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Đang lưu...' : 'Lưu cài đặt'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF087F8C),
            Color(0xFF18B6C8),
            Color(0xFF42D8C8),
          ],
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF087F8C),
            child: Icon(icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 19,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: const Color(0xFFD7E5E7)),
  );
}

String _cleanError(Object? error) {
  return error
      .toString()
      .replaceFirst('Exception: ', '')
      .replaceFirst('Bad state: ', '');
}