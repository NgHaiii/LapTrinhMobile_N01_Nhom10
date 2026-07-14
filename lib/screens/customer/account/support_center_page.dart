import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportCenterPage extends StatelessWidget {
  const SupportCenterPage({super.key});

  Future<void> _launchUri(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!context.mounted) return;

    if (!opened) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Không thể mở liên kết hỗ trợ.')),
        );
    }
  }

  void _showGuide(BuildContext context, _HelpTopic topic) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: topic.color.withOpacity(0.12),
                      foregroundColor: topic.color,
                      child: Icon(topic.icon),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        topic.title,
                        style: const TextStyle(
                          color: Color(0xFF102326),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  topic.description,
                  style: const TextStyle(
                    color: Color(0xFF647A7D),
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                ...topic.steps.map(
                  (step) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF087F8C),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            step,
                            style: const TextStyle(
                              color: Color(0xFF102326),
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topics = _helpTopics;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF9),
      appBar: AppBar(
        title: const Text('Trung tâm hỗ trợ'),
        backgroundColor: const Color(0xFFF4FAF9),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
        children: [
          const _SupportHero(),
          const SizedBox(height: 18),
          const _SectionTitle(
            title: 'Bạn cần hỗ trợ gì?',
            subtitle: 'Chọn vấn đề thường gặp để xem hướng dẫn nhanh.',
          ),
          const SizedBox(height: 12),
          ...topics.map(
            (topic) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HelpTopicCard(
                topic: topic,
                onTap: () => _showGuide(context, topic),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const _SectionTitle(
            title: 'Liên hệ TravelHub',
            subtitle: 'Đội hỗ trợ sẽ phản hồi trong thời gian sớm nhất.',
          ),
          const SizedBox(height: 12),
          _ContactCard(
            icon: Icons.phone_outlined,
            title: 'Gọi hỗ trợ',
            subtitle: '1900 0000',
            color: const Color(0xFF087F8C),
            onTap: () => _launchUri(context, Uri.parse('tel:19000000')),
          ),
          const SizedBox(height: 12),
          _ContactCard(
            icon: Icons.mail_outline_rounded,
            title: 'Gửi email',
            subtitle: 'support@travelhub.vn',
            color: const Color(0xFFE76F51),
            onTap: () => _launchUri(
              context,
              Uri.parse('mailto:support@travelhub.vn'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportHero extends StatelessWidget {
  const _SupportHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF073B42),
            Color(0xFF087F8C),
            Color(0xFF42D8C8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF087F8C).withOpacity(0.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -26,
            child: Icon(
              Icons.support_agent_rounded,
              size: 132,
              color: Colors.white.withOpacity(0.12),
            ),
          ),
          const Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                foregroundColor: Color(0xFF087F8C),
                child: Icon(Icons.support_agent_rounded, size: 32),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TravelHub Support',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Hỗ trợ đặt phòng, thanh toán, tài khoản và dịch vụ du lịch.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HelpTopicCard extends StatelessWidget {
  const _HelpTopicCard({
    required this.topic,
    required this.onTap,
  });

  final _HelpTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD7E5E7)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: topic.color.withOpacity(0.12),
                foregroundColor: topic.color,
                child: Icon(topic.icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF102326),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        topic.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF647A7D),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFD7E5E7)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                foregroundColor: color,
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF102326),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF647A7D),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF102326),
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xFF647A7D),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HelpTopic {
  const _HelpTopic({
    required this.icon,
    required this.title,
    required this.description,
    required this.steps,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> steps;
  final Color color;
}

const _helpTopics = [
  _HelpTopic(
    icon: Icons.hotel_rounded,
    title: 'Vấn đề đặt phòng',
    description: 'Kiểm tra trạng thái, thời gian nhận phòng và thông tin đơn.',
    color: Color(0xFF087F8C),
    steps: [
      'Vào Tài khoản > Đơn đặt phòng để kiểm tra trạng thái.',
      'Mở chi tiết đơn để xem thông tin khách sạn và liên hệ.',
      'Nếu đơn chưa được xác nhận, vui lòng chờ nhà cung cấp xử lý.',
    ],
  ),
  _HelpTopic(
    icon: Icons.payments_outlined,
    title: 'Thanh toán',
    description: 'Hỗ trợ kiểm tra mã QR, số tiền và trạng thái thanh toán.',
    color: Color(0xFFE76F51),
    steps: [
      'Kiểm tra đúng số tiền và nội dung chuyển khoản.',
      'Sau khi thanh toán, chờ nhà cung cấp hoặc hệ thống xác nhận.',
      'Nếu quá thời gian vẫn chưa xác nhận, hãy liên hệ hỗ trợ.',
    ],
  ),
  _HelpTopic(
    icon: Icons.confirmation_number_outlined,
    title: 'Voucher và điểm thưởng',
    description: 'Hướng dẫn đổi điểm, dùng voucher và kiểm tra ưu đãi.',
    color: Color(0xFF7A5AF8),
    steps: [
      'Vào mục Ưu đãi để xem voucher còn hiệu lực.',
      'Đổi điểm lấy voucher nếu tài khoản đủ điểm.',
      'Voucher đã dùng sẽ được chuyển sang trạng thái đã sử dụng.',
    ],
  ),
];